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

  Future<bool> _ensureTrackingPrerequisites() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      gpsError = true;
      trackingStatus = 'gps_off';
      trackingError = 'Activa el GPS para iniciar rastreo';
      trackingMessage = 'GPS apagado';
      return false;
    }

    gpsError = false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always) {
      trackingStatus = 'permission_required';
      trackingError = 'Se requiere permiso de ubicacion "Siempre"';
      trackingMessage = 'Permiso de ubicacion insuficiente';
      return false;
    }

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
      isSendingLocation = false;
      trackingError = null;
    } else if (hasFreshTracking) {
      isSendingLocation = false;
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
