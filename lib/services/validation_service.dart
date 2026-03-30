
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';


class ValidationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Future<bool> isBusActive(String busId) async {
    _logger.i('Verificando si bus $busId está activo');
    try {
      final doc = await _firestore.collection('buses').doc(busId).get();
      _logger.i('Bus doc: ${doc.data()}');
      if (!doc.exists) return false;
      return doc['active'] == true;
    } catch (e, st) {
      _logger.e('Error en isBusActive: $e\n$st');
      rethrow;
    }
  }

  Future<bool> isDriverActive(String driverId) async {
    _logger.i('Verificando si driver $driverId está activo');
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      _logger.i('Driver doc: ${doc.data()}');
      if (!doc.exists) return false;
      return doc['active'] == true;
    } catch (e, st) {
      _logger.e('Error en isDriverActive: $e\n$st');
      rethrow;
    }
  }
}
