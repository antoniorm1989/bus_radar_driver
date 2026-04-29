import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

import '../models/bus.dart';
import '../models/driver.dart';
import '../models/route.dart';
import 'driver_service.dart';
import 'foreground_service.dart';

const int _kMinRouteRunSeconds = 5 * 60;

class SessionProvider extends ChangeNotifier {
  SessionProvider() {
    FlutterForegroundTask.addTaskDataCallback(_onForegroundTaskData);
  }

  final Logger _logger = Logger();
  final DriverService _driverService = DriverService();

  Driver? driver;
  Bus? bus;
  RouteModel? route;

  bool isActive = false;
  bool isLoading = false;
  String? error;

  bool gpsError = false;
  bool connectionError = false;

  double? speed;

  bool isSendingLocation = false;
  String? trackingError;
  String trackingStatus = 'off';
  String? trackingMessage;
  DateTime? lastSentAt;
  DateTime? lastTrackingAt;
  DateTime? currentRouteStartedAt;
  List<RouteTimeEntry> routeTimesToday = const [];

  Timer? _trackingHealthTimer;
  StreamSubscription<DocumentSnapshot>? _busListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _initialized = false;
  bool _initializing = false;

  Future<void> initializeSession() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      _logger.i('[init] Iniciando sesion');
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        error = 'No autenticado';
        _logger.w('[init] No autenticado');
        return;
      }

      driver = await _driverService.getDriverForSession(
        authUid: user.uid,
        email: user.email,
      );
      if (driver == null || !(driver?.active ?? false)) {
        error = 'Chofer invalido';
        _logger.w('[init] Chofer invalido uid=${user.uid} email=${user.email}');
        return;
      }

      bus = await _driverService.getAssignedBus(driver!.assignedBusRef.id);
      if (bus == null) {
        error = 'Unidad no valida';
        _logger.w('[init] Unidad no valida');
        return;
      }

      route = await _driverService.getRoute(bus!.routeId);
      if (route == null) {
        error = 'Ruta no valida';
        _logger.w('[init] Ruta no valida');
        return;
      }

      _initConnectivityListener();
      _listenBusRealtime();
      await _refreshRouteTimesToday(notify: false);

      isActive = bus?.active ?? false;
      if (isActive) {
        trackingStatus = 'starting';
        trackingMessage = 'Reanudando rastreo';
        _startTrackingHealthTimer();
      } else {
        trackingStatus = 'off';
        trackingMessage = 'Servicio detenido';
      }

      _initialized = true;
      _logger.i('[init] Sesion inicializada');
    } on FirebaseException catch (e, st) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        error =
            'No se pudo conectar al servidor. Revisa internet e intenta nuevamente.';
      } else {
        error = 'Error inicializando';
      }
      _logger.e('[init] Error inicializando (${e.code}): ${e.message}\n$st');
    } catch (e, st) {
      error = 'Error inicializando';
      _logger.e('[init] Error inicializando: $e\n$st');
    } finally {
      isLoading = false;
      _initializing = false;
      checkTrackingHealth(notify: false);
      notifyListeners();
    }
  }

  Future<void> startService() async {
    if (isLoading || isActive) return;
    if (bus == null || driver == null || route == null) {
      error = 'No hay unidad o ruta disponible';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    trackingError = null;
    notifyListeners();

    try {
      final canStart = await _ensureTrackingPrerequisites();
      if (!canStart) {
        return;
      }

      await FirebaseFirestore.instance.collection('buses').doc(bus!.id).set({
        'active': true,
        'lastStartedAt': FieldValue.serverTimestamp(),
        'trackingStatus': 'starting',
        'trackingMessage': 'Iniciando rastreo',
        'trackingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FlutterForegroundTask.saveData(key: 'busId', value: bus!.id);

      ServiceRequestResult result;
      if (await FlutterForegroundTask.isRunningService) {
        result = await FlutterForegroundTask.restartService();
      } else {
        result = await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.location],
          notificationTitle: 'Bus Radar',
          notificationText: 'Rastreo activo de la unidad',
          callback: startLocationTaskCallback,
        );
      }

      if (result is ServiceRequestFailure) {
        throw result.error;
      }

      await _openRouteRun();
      await _refreshRouteTimesToday(notify: false);

      isActive = true;
      trackingStatus = 'starting';
      trackingMessage = 'Rastreo activo';
      _startTrackingHealthTimer();
      _logger.i('[startService] Servicio iniciado');
    } catch (e, st) {
      error = 'Error iniciando servicio';
      trackingError = 'No se pudo iniciar el rastreo';
      _logger.e('[startService] Error: $e\n$st');
    } finally {
      isLoading = false;
      checkTrackingHealth(notify: false);
      notifyListeners();
    }
  }

  Future<void> stopService() async {
    if (isLoading || bus == null) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (await FlutterForegroundTask.isRunningService) {
        final result = await FlutterForegroundTask.stopService();
        if (result is ServiceRequestFailure) {
          throw result.error;
        }
      }

      await FirebaseFirestore.instance.collection('buses').doc(bus!.id).set({
        'active': false,
        'speed': 0.0,
        'trackingStatus': 'off',
        'trackingMessage': 'Servicio detenido',
        'trackingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _closeRouteRun();
      await _refreshRouteTimesToday(notify: false);

      isActive = false;
      isSendingLocation = false;
      trackingStatus = 'off';
      trackingMessage = 'Servicio detenido';
      trackingError = null;
      lastSentAt = null;
      lastTrackingAt = null;
      speed = 0;

      _trackingHealthTimer?.cancel();
      _logger.i('[stopService] Servicio detenido');
    } catch (e, st) {
      error = 'Error deteniendo servicio';
      trackingError = 'No se pudo detener correctamente';
      _logger.e('[stopService] Error: $e\n$st');
    } finally {
      isLoading = false;
      checkTrackingHealth(notify: false);
      notifyListeners();
    }
  }

  void _listenBusRealtime() {
    if (bus == null) {
      return;
    }

    _busListener?.cancel();
    _busListener = FirebaseFirestore.instance
        .collection('buses')
        .doc(bus!.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) {
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      final activeRaw = data['active'];
      if (activeRaw is bool) {
        isActive = activeRaw;
      }

      final speedRaw = data['speed'];
      if (speedRaw is num) {
        speed = speedRaw.toDouble();
      }

      final rawLastLocationAt = data['lastLocationAt'];
      final parsedLastLocationAt = _parseTimestamp(rawLastLocationAt);
      if (parsedLastLocationAt != null) {
        lastSentAt = parsedLastLocationAt;
      }

      final rawLastTrackingAt = data['lastTrackingAt'] ?? data['trackingUpdatedAt'];
      final parsedLastTrackingAt = _parseTimestamp(rawLastTrackingAt);
      if (parsedLastTrackingAt != null) {
        lastTrackingAt = parsedLastTrackingAt;
      }

      final rawLastStartedAt = data['lastStartedAt'];
      final parsedLastStartedAt = _parseTimestamp(rawLastStartedAt);
      if (isActive && currentRouteStartedAt == null && parsedLastStartedAt != null) {
        currentRouteStartedAt = parsedLastStartedAt;
      }
      if (!isActive) {
        currentRouteStartedAt = null;
      }

      final statusRaw = data['trackingStatus'];
      if (statusRaw is String && statusRaw.isNotEmpty) {
        trackingStatus = statusRaw;
      }

      final messageRaw = data['trackingMessage'];
      if (messageRaw is String && messageRaw.isNotEmpty) {
        trackingMessage = messageRaw;
      }

      checkTrackingHealth(notify: false);
      notifyListeners();
    }, onError: (Object listenerError, StackTrace stack) {
      _logger.e('[listenBusRealtime] Error: $listenerError\n$stack');
    });
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>>? _routeTimesCollection() {
    final activeBus = bus;
    if (activeBus == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('buses')
        .doc(activeBus.id)
        .collection('tiemposRuta');
  }

  String _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _refreshRouteTimesToday({bool notify = true}) async {
    final collection = _routeTimesCollection();
    if (collection == null) {
      routeTimesToday = const [];
      currentRouteStartedAt = null;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    try {
      final snapshot = await collection
          .orderBy('startedAt', descending: false)
          .limit(120)
          .get();

      final todayKey = _dayKey(DateTime.now());
      final parsed = <RouteTimeEntry>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final startedAt = _parseTimestamp(data['startedAt']) ??
            _parseTimestamp(data['startedAtClient']);
        if (startedAt == null) {
          continue;
        }

        final endedAt = _parseTimestamp(data['endedAt']) ??
            _parseTimestamp(data['endedAtClient']);
        if (endedAt == null) {
          // In the current model we only keep closed runs in history.
          continue;
        }

        final storedDayKey = (data['dayKey'] as String? ?? '').trim();
        final belongsToToday =
            storedDayKey == todayKey || _dayKey(startedAt) == todayKey;

        if (!belongsToToday) {
          continue;
        }

        final durationRaw = data['durationSec'];
        final resolvedDurationSec = durationRaw is num
            ? durationRaw.toInt()
            : (endedAt == null
                  ? null
                  : endedAt
                        .difference(startedAt)
                        .inSeconds
                        .clamp(0, 60 * 60 * 24 * 7)
                        .toInt());

        if (endedAt != null && (resolvedDurationSec == null || resolvedDurationSec < _kMinRouteRunSeconds)) {
          continue;
        }

        parsed.add(
          RouteTimeEntry(
            id: doc.id,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSec: resolvedDurationSec,
          ),
        );
      }

      parsed.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      routeTimesToday = parsed;
    } catch (e, st) {
      _logger.w('[routeTimes] No se pudo cargar historial diario: $e\n$st');
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _openRouteRun() async {
    // Keep start time only in memory; persist run history on stop if duration >= threshold.
    currentRouteStartedAt = DateTime.now();
  }

  Future<void> _closeRouteRun() async {
    final collection = _routeTimesCollection();
    final activeDriver = driver;
    final activeRoute = route;
    final activeBus = bus;

    if (collection == null || activeDriver == null || activeRoute == null || activeBus == null) {
      currentRouteStartedAt = null;
      return;
    }

    final endedAtClient = DateTime.now();
    DateTime? startedAt = currentRouteStartedAt;

    if (startedAt == null && activeBus.id.isNotEmpty) {
      try {
        final busSnapshot = await FirebaseFirestore.instance
            .collection('buses')
            .doc(activeBus.id)
            .get();
        final busData = busSnapshot.data();
        if (busData != null) {
          startedAt = _parseTimestamp(busData['lastStartedAt']);
        }
      } catch (e, st) {
        _logger.w('[routeTimes] No se pudo recuperar inicio de ruta: $e\n$st');
      }
    }

    if (startedAt == null) {
      currentRouteStartedAt = null;
      return;
    }

    try {
      final computedSeconds = endedAtClient
          .difference(startedAt)
          .inSeconds
          .clamp(0, 60 * 60 * 24 * 7)
          .toInt();

      if (computedSeconds >= _kMinRouteRunSeconds) {
        await collection.add({
          'busId': activeBus.id,
          'driverId': activeDriver.id,
          'driverName': activeDriver.name,
          'routeId': activeRoute.id,
          'routeName': activeRoute.name,
          'dayKey': _dayKey(startedAt),
          'startedAt': Timestamp.fromDate(startedAt.toUtc()),
          'endedAt': FieldValue.serverTimestamp(),
          'endedAtClient': Timestamp.fromDate(endedAtClient.toUtc()),
          'durationSec': computedSeconds,
          'status': 'closed',
        });
      }
    } catch (e, st) {
      _logger.w('[routeTimes] No se pudo cerrar trayecto: $e\n$st');
    } finally {
      currentRouteStartedAt = null;
    }
  }

  Future<bool> _ensureTrackingPrerequisites() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      gpsError = false;
      trackingStatus = 'permission_required';
      trackingError =
          'Permiso de ubicacion bloqueado. Abre Ajustes y selecciona "Permitir siempre".';
      trackingMessage = 'Permiso de ubicacion bloqueado';
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      final upgradedPermission = await Geolocator.requestPermission();
      if (upgradedPermission == LocationPermission.always) {
        permission = upgradedPermission;
      }
    }

    if (permission != LocationPermission.always) {
      gpsError = false;
      trackingStatus = 'permission_required';
      trackingError =
          'Se requiere permiso de ubicacion "Siempre". Activalo desde Ajustes del sistema.';
      trackingMessage = 'Permiso de ubicacion insuficiente';
      return false;
    }

    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      gpsError = true;
      trackingStatus = 'gps_off';
      trackingError = 'Activa el GPS para iniciar rastreo';
      trackingMessage = 'GPS apagado';
      return false;
    }

    gpsError = false;

    if (Platform.isAndroid) {
      var notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        notificationPermission =
            await FlutterForegroundTask.requestNotificationPermission();
      }

      if (notificationPermission != NotificationPermission.granted) {
        trackingStatus = 'permission_required';
        trackingError = 'Permite notificaciones para mantener el servicio activo';
        trackingMessage = 'Permiso de notificaciones requerido';
        return false;
      }

      final ignoredBatteryOptimization =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ignoredBatteryOptimization) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    trackingError = null;
    return true;
  }

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final connected =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      connectionError = !connected;

      checkTrackingHealth(notify: false);
      notifyListeners();
    });
  }

  void _startTrackingHealthTimer() {
    _trackingHealthTimer?.cancel();
    _trackingHealthTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkTrackingHealth();
    });
  }

  void _onForegroundTaskData(Object data) {
    if (data is! Map) return;

    final payload = Map<String, dynamic>.from(data);

    final statusRaw = payload['trackingStatus'];
    if (statusRaw is String && statusRaw.isNotEmpty) {
      trackingStatus = statusRaw;
    }

    final speedRaw = payload['speed'];
    if (speedRaw is num) {
      speed = speedRaw.toDouble();
    }

    lastTrackingAt = DateTime.now();
    if (trackingStatus == 'sending') {
      lastSentAt = DateTime.now();
    }

    checkTrackingHealth(notify: false);
    notifyListeners();
  }

  void checkTrackingHealth({bool notify = true}) {
    if (!isActive) {
      isSendingLocation = false;

      if (trackingStatus == 'gps_off') {
        gpsError = true;
        trackingError ??= 'GPS apagado';
      } else if (trackingStatus == 'permission_required') {
        gpsError = false;
        trackingError ??= 'Permiso de ubicacion pendiente';
      } else if (trackingStatus == 'network_error') {
        gpsError = false;
        trackingError ??= 'Sin internet';
      } else {
        gpsError = false;
        trackingError = null;
        trackingStatus = 'off';
        trackingMessage ??= 'Servicio detenido';
      }

      if (notify) notifyListeners();
      return;
    }

    final now = DateTime.now();
    final sentAge =
        lastSentAt != null ? now.difference(lastSentAt!).inSeconds : null;
    final trackingAge = lastTrackingAt != null
        ? now.difference(lastTrackingAt!).inSeconds
        : null;
    final hasFreshTracking = trackingAge != null && trackingAge <= 60;
    final hasRecentSend = sentAge != null && sentAge <= 20;
    final isTemporarilyStopped = trackingAge != null && trackingAge > 60 && trackingAge <= 180;
    final isDisconnected = trackingAge != null && trackingAge > 180;

    gpsError = trackingStatus == 'gps_off';

    if (trackingStatus == 'permission_required') {
      isSendingLocation = false;
      trackingError = 'Permiso de ubicacion pendiente';
    } else if (gpsError) {
      isSendingLocation = false;
      trackingError = 'GPS apagado';
    } else if (connectionError || trackingStatus == 'network_error') {
      isSendingLocation = false;
      trackingError = 'Sin internet';
    } else if (isDisconnected) {
      isSendingLocation = false;
      trackingError = null;
    } else if (isTemporarilyStopped) {
      isSendingLocation = false;
      trackingError = null;
    } else if (trackingStatus == 'sending') {
      if (hasFreshTracking && sentAge != null && sentAge <= 60) {
        isSendingLocation = true;
        trackingError = null;
      } else {
        isSendingLocation = false;
        trackingError = null;
      }
    } else if (trackingStatus == 'idle') {
      // Keep sending state for a short grace period to avoid visual flapping
      // when one tick reports idle between sending updates.
      isSendingLocation = hasFreshTracking && hasRecentSend;
      trackingError = null;
    } else if (hasFreshTracking) {
      isSendingLocation = hasRecentSend;
      trackingError = null;
    } else {
      isSendingLocation = false;
      trackingError = 'Sin respuesta del rastreo';
    }

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundTaskData);
    _connectivitySubscription?.cancel();
    _trackingHealthTimer?.cancel();
    _busListener?.cancel();
    super.dispose();
  }
}

class RouteTimeEntry {
  const RouteTimeEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSec;
}
