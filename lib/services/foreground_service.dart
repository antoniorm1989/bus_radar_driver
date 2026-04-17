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

@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

@pragma('vm:entry-point')
class LocationTaskHandler extends TaskHandler {
  bool _firebaseReady = false;
  final Logger _logger = Logger();

  double? _lastLat;
  double? _lastLng;
  DateTime? _lastFirestoreWriteAt;

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

      final lat = position.latitude;
      final lng = position.longitude;
      final speedKmh = max(0, position.speed * 3.6);

      final now = DateTime.now();
      final hasPreviousWrite = _lastLat != null && _lastLng != null;
      final movedDistanceMeters = hasPreviousWrite
          ? Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng)
          : 0;
      final movedEnough = !hasPreviousWrite || movedDistanceMeters >= _kMinMovingDistanceMeters;
      final heartbeatDue = _lastFirestoreWriteAt == null ||
          now.difference(_lastFirestoreWriteAt!) >= _kHeartbeatInterval;
      final intervalReady = _lastFirestoreWriteAt == null ||
          now.difference(_lastFirestoreWriteAt!) >= _kTrackingTickInterval;

      if (intervalReady && (movedEnough || heartbeatDue)) {
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