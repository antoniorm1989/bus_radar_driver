import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'dart:async';
import 'package:logger/logger.dart';

class SimpleLatLng {
  final double latitude;
  final double longitude;

  SimpleLatLng(this.latitude, this.longitude);
}

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  final Logger _logger = Logger();

  double? _lastLat;
  double? _lastLng;

  Future<void> startLocationUpdates({
    required String busId,
    required String routeId,
    required String driverId,
    void Function(double speed)? onSpeedUpdate,
    bool simulate = false,
  }) async {
    if (_timer != null || _positionSubscription != null) {
      _logger.w('Servicio de ubicación ya activo, evitando duplicado');
      return;
    }

    _logger.i('Iniciando actualizaciones de ubicación para bus $busId, ruta $routeId, chofer $driverId');

    LocationPermission? permission;
    if (!simulate) {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse) {
        _logger.w('Permiso solo "while in use", solicitando "always"...');
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always) {
        _logger.e('Permiso de ubicación insuficiente: $permission. Se requiere "always" para rastreo en background.');
        return;
      }
    }

    // =========================
    // 🚍 SIMULACIÓN
    // =========================
    if (simulate) {
      int index = 0;
      final List<SimpleLatLng> fakeRoute = [
        SimpleLatLng(32.6248, -115.4523),
        SimpleLatLng(32.6255, -115.4510),
        SimpleLatLng(32.6265, -115.4495),
        SimpleLatLng(32.6275, -115.4480),
        SimpleLatLng(32.6285, -115.4465),
        SimpleLatLng(32.6295, -115.4450),
        SimpleLatLng(32.6305, -115.4435),
        SimpleLatLng(32.6315, -115.4420),
        SimpleLatLng(32.6325, -115.4405),
        SimpleLatLng(32.6335, -115.4390),
        SimpleLatLng(32.6345, -115.4375),
        SimpleLatLng(32.6355, -115.4360),
        SimpleLatLng(32.6365, -115.4345),
        SimpleLatLng(32.6375, -115.4330),
        SimpleLatLng(32.6368, -115.4315),
        SimpleLatLng(32.6355, -115.4300),
        SimpleLatLng(32.6340, -115.4290),
        SimpleLatLng(32.6325, -115.4280),
        SimpleLatLng(32.6310, -115.4275),
        SimpleLatLng(32.6295, -115.4270),
        SimpleLatLng(32.6280, -115.4275),
        SimpleLatLng(32.6265, -115.4285),
        SimpleLatLng(32.6250, -115.4300),
      ];
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final point = fakeRoute[index];
          double lat = point.latitude;
          double lng = point.longitude;
          double speed = 20 + (index % 4) * 8;
          index++;
          if (index >= fakeRoute.length) index = 0;
          _lastLat = lat;
          _lastLng = lng;
          onSpeedUpdate?.call(speed);
          await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .set({
            'lat': lat,
            'lng': lng,
            'speed': speed,
            'lastLocationAt': FieldValue.serverTimestamp(),
            'serverTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e, st) {
          _logger.e('Error simulación: $e\n$st');
        }
      });
      return;
    }

    // =========================
    // 📡 GPS REAL (STREAM)
    // =========================
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // metros
      ),
    ).listen((Position position) async {
      try {
        double lat = position.latitude;
        double lng = position.longitude;
        double speed = position.speed * 3.6;

        // 🔥 OPTIMIZACIÓN: evitar escrituras innecesarias
        if (_lastLat != null && _lastLng != null) {
          final latDiff = (lat - _lastLat!).abs();
          final lngDiff = (lng - _lastLng!).abs();
          if (latDiff < 0.000003 && lngDiff < 0.000003) {
            _logger.i('Ubicación sin cambio significativo, se omite escritura');
            return;
          }
        }
        _lastLat = lat;
        _lastLng = lng;
        if (onSpeedUpdate != null) {
          onSpeedUpdate(speed);
        }
        _logger.i('Ubicación obtenida: lat=$lat, lng=$lng');
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(busId)
            .set({
          'lat': lat,
          'lng': lng,
          'speed': speed,
          'lastLocationAt': FieldValue.serverTimestamp(),
          'serverTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _logger.i('Ubicación enviada a buses');
      } catch (e, st) {
        _logger.e('Error al actualizar ubicación en buses: $e\n$st');
      }
    });
  }

  Future<void> stopLocationUpdates(String busId) async {
    _logger.i('Deteniendo actualizaciones de ubicación para bus $busId');
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}