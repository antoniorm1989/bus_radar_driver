import 'dart:async';
import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/bus.dart';
import '../models/route.dart';
import '../services/driver_service.dart';
import '../services/validation_service.dart';
import '../services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background/flutter_background.dart';

class SessionProvider extends ChangeNotifier {
  double? speed;
    Future<void> _disableBackground() async {
      if (_backgroundEnabled) {
        await FlutterBackground.disableBackgroundExecution();
        _backgroundEnabled = false;
      }
    }
  final DriverService _driverService = DriverService();
  final ValidationService _validationService = ValidationService();
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger();

  Driver? driver;
  Bus? bus;
  RouteModel? route;
  bool isActive = false;
  bool isLoading = false;
  String? error;
  bool gpsError = false;
  bool connectionError = false;
  bool _backgroundEnabled = false;
  Stream<List<ConnectivityResult>>? _connectivityStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  bool _initializing = false;
  bool _initialized = false;

  Future<void> initializeSession() async {
    if (_initialized || _initializing) {
      _logger.w('initializeSession ignorado (ya inicializado o en proceso)');
      return;
    }
    _initializing = true;

    if (driver != null && bus != null && route != null) {
      _logger.i('Sesión ya cargada, se omite inicialización');
      _initializing = false;
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();
    _logger.i('Inicializando sesión...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      _logger.i('Usuario actual: \\${user?.uid}');
      if (user == null) {
        error = 'No autenticado';
        isLoading = false;
        notifyListeners();
        _logger.w('No autenticado');
        return;
      }
      driver = await _driverService.getDriver(user.uid);
      _logger.i('Driver obtenido: $driver');
      if (driver == null || !(driver?.active ?? false)) {
        error = 'Chofer no válido o inactivo';
        isLoading = false;
        notifyListeners();
        _logger.w('Chofer no válido o inactivo');
        return;
      }
      bus = await _driverService.getAssignedBus(driver!.assignedBusRef.id);
      isActive = bus?.active ?? false;
      _logger.i('Bus obtenido: $bus');
      if (bus == null) {
        error = 'Camión no válido';
        isLoading = false;
        notifyListeners();
        _logger.w('Camión no válido');
        return;
      }
      if (bus!.assignedDriverRef.id != driver!.id) {
        error = 'No eres el chofer asignado a este camión';
        isLoading = false;
        notifyListeners();
        _logger.w('No eres el chofer asignado a este camión');
        return;
      }
      // Validación de "bus en uso" eliminada. El chofer siempre puede entrar y prender/apagar la ruta.
      route = await _driverService.getRoute(bus!.routeId);
      _logger.i('Ruta obtenida: ${route?.name}');
      _initConnectivityListener();
      isLoading = false;
      notifyListeners();
      _logger.i('Sesión inicializada correctamente');
      _initialized = true;
      _initializing = false;
    } catch (e, st) {
      error = 'Error de inicialización';
      _logger.e('Error en initializeSession: $e\n$st');
      isLoading = false;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> startService() async {

    if (isActive) {
      _logger.w('El servicio ya está activo, se ignora startService');
      return;
    }

    if (bus == null || driver == null) return;
      isLoading = true;
      error = null;
      notifyListeners();
      try {
        await FirebaseFirestore.instance.collection('buses').doc(bus!.id).update({'active': true, 'lastStartedAt': FieldValue.serverTimestamp()});
        await _enableBackground();
        await _locationService.startLocationUpdates(
          busId: bus!.id,
          routeId: route!.id,
          driverId: driver!.id,
          onSpeedUpdate: (double newSpeed) {
            speed = newSpeed;
            notifyListeners();
          },
        );
        isActive = true;
        isLoading = false;
        _retryCount = 0;
        notifyListeners();
      } catch (e, st) {
        error = 'No se pudo iniciar el servicio';
        _logger.e('Error en startService: $e\n$st');
        isLoading = false;
        notifyListeners();
        _retryStartService();
      }
  }

  Future<void> stopService({String? reason}) async {
    if (bus == null) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _locationService.stopLocationUpdates(bus!.id);
      await FirebaseFirestore.instance.collection('buses').doc(bus!.id).update({'active': false});
      await _disableBackground();
      isActive = false;
      isLoading = false;
      notifyListeners();
    } catch (e, st) {
      error = 'No se pudo detener el servicio';
      _logger.e('Error en stopService: $e\n$st');
      isLoading = false;
      notifyListeners();
      _retryStopService();
    }
  }

  void setGpsError(bool value) {
    gpsError = value;
    notifyListeners();
  }

  void setConnectionError(bool value) {
    connectionError = value;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> _enableBackground() async {
    if (!_backgroundEnabled) {
      final androidConfig = const FlutterBackgroundAndroidConfig(
        notificationTitle: 'Bus Radar Driver',
        notificationText: 'Enviando ubicación en segundo plano',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'background_icon', defType: 'drawable'),
      );
      final success = await FlutterBackground.initialize(androidConfig: androidConfig);
      if (success) {
        await FlutterBackground.enableBackgroundExecution();
        _backgroundEnabled = true;
      }
    }
  }

  void _initConnectivityListener() {
    _connectivityStream ??= Connectivity().onConnectivityChanged;
    _connectivitySubscription ??= _connectivityStream!.listen((results) {
      final connected = results.isNotEmpty && results.first != ConnectivityResult.none;
      setConnectionError(!connected);
      if (connected && isActive && error != null) {
        // Reintentar si hay error y vuelve la conexión
        _retryStartService();
      }
    });
  }

  void _retryStartService() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      Future.delayed(Duration(seconds: 5 * _retryCount), () async {
        await startService();
      });
    } else {
      error = 'No se pudo iniciar el servicio tras varios intentos.';
      notifyListeners();
    }
  }

  void _retryStopService() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      Future.delayed(Duration(seconds: 5 * _retryCount), () async {
        await stopService();
      });
    } else {
      error = 'No se pudo detener el servicio tras varios intentos.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
