import 'dart:async';
import 'dart:math';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';

const Duration _kTrackingStatusThrottle = Duration(seconds: 15);
const Duration _kTrackingTickInterval = Duration(seconds: 7);
const Duration _kHeartbeatInterval = Duration(seconds: 60);
const double _kMinMovingDistanceMeters = 20;
const double _kSignificantSpeedDeltaKmh = 2.0;
const double _kStoppedSpeedThresholdKmh = 1.8;

const double _kMaxExpectedBusSpeedKmh = 120;
const double _kMaxAccelerationKmhPerSecond = 8;
const double _kPoorGpsAccuracyMeters = 45;
const double _kMinDeltaSecondsForDerivedSpeed = 2;
const double _kStationaryNoiseFloorMeters = 5;

@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

@pragma('vm:entry-point')
class LocationTaskHandler extends TaskHandler {
  bool _firebaseReady = false;
  final Logger _logger = Logger();
  final _SpeedEstimator _speedEstimator = _SpeedEstimator();

  double? _lastLat;
  double? _lastLng;
  DateTime? _lastFirestoreWriteAt;
  double? _lastPublishedSpeedKmh;

  String? _lastTrackingStatus;
  DateTime? _lastTrackingStatusWrite;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _ensureFirebase();
    _logger.i('[foreground] Service started');
  }

  Future<void> _ensureFirebase() async {
    if (_firebaseReady) return;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      _logger.i('[foreground] Firebase initialized');
    } catch (e) {
      // Firebase may already be initialized in this isolate.
      _firebaseReady = true;
      _logger.i('[foreground] Firebase init skipped: $e');
    }
  }

  Future<void> _writeTrackingStatus(
    String busId,
    String status,
    String message, {
    bool force = false,
    Map<String, dynamic>? extra,
  }) async {
    final now = DateTime.now();
    final shouldWrite = force ||
        _lastTrackingStatus != status ||
        _lastTrackingStatusWrite == null ||
        now.difference(_lastTrackingStatusWrite!) >= _kTrackingStatusThrottle;

    if (!shouldWrite) {
      return;
    }

    await FirebaseFirestore.instance.collection('buses').doc(busId).set({
      'trackingStatus': status,
      'trackingMessage': message,
      'trackingUpdatedAt': FieldValue.serverTimestamp(),
      ...?extra,
    }, SetOptions(merge: true));

    _lastTrackingStatus = status;
    _lastTrackingStatusWrite = now;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_handleTrackingTick());
  }

  Future<void> _handleTrackingTick() async {
    try {
      await _ensureFirebase();

      final busId = await FlutterForegroundTask.getData<String>(key: 'busId');
      if (busId == null || busId.isEmpty) {
        _logger.w('[foreground] busId not found');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _writeTrackingStatus(
          busId,
          'gps_off',
          'GPS apagado',
          force: true,
        );
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        await _writeTrackingStatus(
          busId,
          'permission_required',
          'Permiso de ubicacion en segundo plano requerido',
          force: true,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final now = DateTime.now();
      final lat = position.latitude;
      final lng = position.longitude;
      final estimatedSpeedKmh = _speedEstimator.estimate(
        position: position,
        sampledAt: now,
      );
      final speedKmh = double.parse(estimatedSpeedKmh.toStringAsFixed(1));

      final hasPreviousWrite = _lastLat != null && _lastLng != null;
      final movedDistanceMeters = hasPreviousWrite
          ? Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng)
          : 0;
      final movedEnough = !hasPreviousWrite || movedDistanceMeters >= _kMinMovingDistanceMeters;
      final heartbeatDue = _lastFirestoreWriteAt == null ||
          now.difference(_lastFirestoreWriteAt!) >= _kHeartbeatInterval;
      final intervalReady = _lastFirestoreWriteAt == null ||
          now.difference(_lastFirestoreWriteAt!) >= _kTrackingTickInterval;
      final speedChange = _lastPublishedSpeedKmh == null
          ? null
          : (speedKmh - _lastPublishedSpeedKmh!).abs();
      final speedStateChanged = _lastPublishedSpeedKmh == null
          ? true
          : (_lastPublishedSpeedKmh! <= _kStoppedSpeedThresholdKmh) !=
              (speedKmh <= _kStoppedSpeedThresholdKmh);
      final speedChangedEnough =
          speedStateChanged ||
          (speedChange != null && speedChange >= _kSignificantSpeedDeltaKmh);

      if (intervalReady && (movedEnough || heartbeatDue || speedChangedEnough)) {
        final trackingStatus = movedEnough ? 'sending' : 'idle';
        final trackingMessage = movedEnough ? 'Ubicacion enviada' : 'Heartbeat de rastreo';

        await FirebaseFirestore.instance.collection('buses').doc(busId).set({
          'lat': lat,
          'lng': lng,
          'speed': speedKmh,
          if (movedEnough) 'lastLocationAt': FieldValue.serverTimestamp(),
          'serverTime': FieldValue.serverTimestamp(),
          'lastTrackingAt': FieldValue.serverTimestamp(),
          'trackingStatus': trackingStatus,
          'trackingMessage': trackingMessage,
          'trackingUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _lastLat = lat;
        _lastLng = lng;
        _lastFirestoreWriteAt = now;
        _lastPublishedSpeedKmh = speedKmh;
        _lastTrackingStatus = trackingStatus;
        _lastTrackingStatusWrite = now;

        FlutterForegroundTask.sendDataToMain({
          'trackingStatus': trackingStatus,
          'speed': speedKmh,
          'at': now.toIso8601String(),
        });
        return;
      }

      FlutterForegroundTask.sendDataToMain({
        'trackingStatus': 'idle',
        'speed': speedKmh,
        'at': now.toIso8601String(),
      });
    } catch (e) {
      final busId = await FlutterForegroundTask.getData<String>(key: 'busId');
      if (busId != null && busId.isNotEmpty) {
        try {
          await _writeTrackingStatus(
            busId,
            'network_error',
            'No se pudo enviar la ubicacion',
            force: true,
          );
        } catch (_) {
          // Ignore nested write failures to avoid recursive errors.
        }
      }
      _logger.e('[foreground] Tracking tick error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    final busId = await FlutterForegroundTask.getData<String>(key: 'busId');
    if (busId != null && busId.isNotEmpty) {
      try {
        await _writeTrackingStatus(
          busId,
          'off',
          'Servicio detenido',
          force: true,
        );
      } catch (_) {
        // Ignore write errors during shutdown.
      }
    }
    _logger.i('[foreground] Service stopped');
  }
}

class _SpeedEstimator {
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastSampleAt;
  double _lastSmoothedKmh = 0;

  double estimate({
    required Position position,
    required DateTime sampledAt,
  }) {
    final rawSensorKmh = max<double>(0, position.speed * 3.6);
    final accuracyMeters = max<double>(0, position.accuracy);
    final deltaSample = _computeDeltaSample(
      lat: position.latitude,
      lng: position.longitude,
      sampledAt: sampledAt,
    );

    var fusedKmh = _fuseSpeeds(
      rawSensorKmh: rawSensorKmh,
      accuracyMeters: accuracyMeters,
      deltaSample: deltaSample,
    );
    fusedKmh = _limitByAcceleration(
      speedKmh: fusedKmh,
      deltaSeconds: deltaSample?.deltaSeconds,
    );

    final alpha = _emaAlpha(deltaSample?.deltaSeconds);
    var smoothedKmh = _lastSampleAt == null
        ? fusedKmh
        : (_lastSmoothedKmh * (1 - alpha)) + (fusedKmh * alpha);

    final likelyStopped =
        smoothedKmh <= _kStoppedSpeedThresholdKmh &&
        rawSensorKmh <= (_kStoppedSpeedThresholdKmh + 1) &&
        (deltaSample == null ||
            deltaSample.speedKmh <= (_kStoppedSpeedThresholdKmh + 1));
    if (likelyStopped) {
      smoothedKmh = 0;
    }

    final normalizedKmh = smoothedKmh
        .clamp(0, _kMaxExpectedBusSpeedKmh)
        .toDouble();

    _lastLat = position.latitude;
    _lastLng = position.longitude;
    _lastSampleAt = sampledAt;
    _lastSmoothedKmh = normalizedKmh;

    return normalizedKmh;
  }

  _DeltaSpeedSample? _computeDeltaSample({
    required double lat,
    required double lng,
    required DateTime sampledAt,
  }) {
    if (_lastLat == null || _lastLng == null || _lastSampleAt == null) {
      return null;
    }

    final elapsedMs = sampledAt.difference(_lastSampleAt!).inMilliseconds;
    if (elapsedMs <= 0) {
      return null;
    }

    final deltaSeconds = elapsedMs / 1000;
    if (deltaSeconds < _kMinDeltaSecondsForDerivedSpeed) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng);
    final deltaSpeedKmh = (distanceMeters / deltaSeconds) * 3.6;

    return _DeltaSpeedSample(
      distanceMeters: distanceMeters,
      deltaSeconds: deltaSeconds,
      speedKmh: deltaSpeedKmh,
    );
  }

  double _fuseSpeeds({
    required double rawSensorKmh,
    required double accuracyMeters,
    required _DeltaSpeedSample? deltaSample,
  }) {
    if (deltaSample == null) {
      return rawSensorKmh;
    }

    final deltaSpeedKmh = deltaSample.speedKmh
        .clamp(0, _kMaxExpectedBusSpeedKmh)
        .toDouble();
    final noiseFloorMeters = max(_kStationaryNoiseFloorMeters, accuracyMeters * 0.5);

    if (deltaSample.distanceMeters <= noiseFloorMeters && rawSensorKmh <= 6) {
      return 0;
    }

    if (accuracyMeters >= _kPoorGpsAccuracyMeters) {
      return deltaSpeedKmh;
    }

    final sensorWeight = _sensorWeightForAccuracy(accuracyMeters);
    final deltaWeight = 1 - sensorWeight;
    return (rawSensorKmh * sensorWeight) + (deltaSpeedKmh * deltaWeight);
  }

  double _sensorWeightForAccuracy(double accuracyMeters) {
    if (accuracyMeters <= 8) {
      return 0.65;
    }
    if (accuracyMeters <= 15) {
      return 0.60;
    }
    if (accuracyMeters <= 25) {
      return 0.55;
    }
    if (accuracyMeters <= 35) {
      return 0.50;
    }
    return 0.40;
  }

  double _limitByAcceleration({
    required double speedKmh,
    required double? deltaSeconds,
  }) {
    if (_lastSampleAt == null || deltaSeconds == null || deltaSeconds <= 0) {
      return speedKmh;
    }

    final maxChange = _kMaxAccelerationKmhPerSecond * deltaSeconds;
    final minAllowed = max(0, _lastSmoothedKmh - maxChange);
    final maxAllowed = min(_kMaxExpectedBusSpeedKmh, _lastSmoothedKmh + maxChange);
    return speedKmh.clamp(minAllowed, maxAllowed).toDouble();
  }

  double _emaAlpha(double? deltaSeconds) {
    if (_lastSampleAt == null || deltaSeconds == null) {
      return 1;
    }
    if (deltaSeconds <= 4) {
      return 0.35;
    }
    if (deltaSeconds <= 8) {
      return 0.45;
    }
    if (deltaSeconds <= 12) {
      return 0.55;
    }
    return 0.65;
  }
}

class _DeltaSpeedSample {
  final double distanceMeters;
  final double deltaSeconds;
  final double speedKmh;

  const _DeltaSpeedSample({
    required this.distanceMeters,
    required this.deltaSeconds,
    required this.speedKmh,
  });
}
