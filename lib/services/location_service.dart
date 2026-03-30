import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'dart:async';
import 'package:logger/logger.dart';

class LocationService {
  Timer? _timer;
  final Logger _logger = Logger();

  double? _lastLat;
  double? _lastLng;

  Future<void> startLocationUpdates({
    required String busId,
    required String routeId,
    required String driverId,
    void Function(double speed)? onSpeedUpdate,
    bool simulate = true,
  }) async {

    if (_timer != null) {
      _logger.w('Timer ya activo, evitando duplicado');
      return;
    }

    _logger.i('Iniciando actualizaciones de ubicación para bus $busId, ruta $routeId, chofer $driverId');

    double baseLat = 32.6202;
    double baseLng = -115.4632;

    LocationPermission? permission;
    if (!simulate) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _logger.w('Permiso de ubicación denegado');
        return;
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        double lat, lng, speed;

        if (simulate) {
          double step = 0.0002;
          baseLat += step;
          lat = baseLat;
          lng = baseLng;
          speed = 65;
        } else {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          lat = position.latitude;
          lng = position.longitude;
          speed = position.speed * 3.6;
        }

        // 🔥 OPTIMIZACIÓN: evitar escrituras innecesarias
        if (_lastLat != null && _lastLng != null) {
          final latDiff = (lat - _lastLat!).abs();
          final lngDiff = (lng - _lastLng!).abs();

          if (latDiff < 0.00001 && lngDiff < 0.00001) {
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

        // ⚠️ MISMA ESTRUCTURA - NO SE CAMBIA
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(busId)
            .set({
          'lat': lat,
          'lng': lng,
          'speed': speed,
          'lastLocationAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // IMPORTANTE

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
  }
}