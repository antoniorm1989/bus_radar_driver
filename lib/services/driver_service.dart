import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver.dart';
import '../models/bus.dart';
import '../models/route.dart';
import 'package:logger/logger.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // 🔥 Cache simple en memoria (evita lecturas repetidas)
  Driver? _cachedDriver;
  Bus? _cachedBus;
  RouteModel? _cachedRoute;

  bool _isTransientFirestoreError(FirebaseException e) {
    return e.code == 'unavailable' || e.code == 'deadline-exceeded';
  }

  Future<T> _runWithRetry<T>({
    required String operation,
    required Future<T> Function() action,
    int maxAttempts = 5,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (e) {
        final isTransient = _isTransientFirestoreError(e);

        if (!isTransient || attempt == maxAttempts) {
          rethrow;
        }

        final delayMs = 350 * attempt * attempt;
        _logger.w(
          '[$operation] intento $attempt/$maxAttempts fallo (${e.code}), reintentando en ${delayMs}ms',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw StateError('No se pudo completar $operation');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocWithCacheFallback({
    required String operation,
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    try {
      return await _runWithRetry(
        operation: operation,
        action: () => ref.get(),
      );
    } on FirebaseException catch (e) {
      if (!_isTransientFirestoreError(e)) {
        rethrow;
      }

      _logger.w(
        '[$operation] sin conexion con servidor, intentando leer cache local',
      );
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runQueryWithCacheFallback({
    required String operation,
    required Query<Map<String, dynamic>> query,
  }) async {
    try {
      return await _runWithRetry(
        operation: operation,
        action: () => query.get(),
      );
    } on FirebaseException catch (e) {
      if (!_isTransientFirestoreError(e)) {
        rethrow;
      }

      _logger.w(
        '[$operation] sin conexion con servidor, intentando consulta desde cache local',
      );
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  Future<Driver?> getDriverForSession({
    required String authUid,
    String? email,
  }) async {
    final driverByUid = await getDriver(authUid);
    if (driverByUid != null) {
      return driverByUid;
    }

    final rawEmail = email?.trim();
    if (rawEmail == null || rawEmail.isEmpty) {
      _logger.w('No se encontro driver por uid y no hay email para fallback');
      return null;
    }

    final cached = _cachedDriver;
    if (cached != null && cached.email.toLowerCase() == rawEmail.toLowerCase()) {
      _logger.i('Driver obtenido desde cache por email');
      return cached;
    }

    final lookupCandidates = <String>{rawEmail, rawEmail.toLowerCase()};

    for (final candidate in lookupCandidates) {
      _logger.i('Buscando driver por email: $candidate');

      final query = await _runQueryWithCacheFallback(
        operation: 'getDriverForSessionByEmail',
        query: _firestore
            .collection('drivers')
            .where('email', isEqualTo: candidate)
            .limit(1),
      );

      if (query.docs.isEmpty) {
        continue;
      }

      _cachedDriver = Driver.fromFirestore(query.docs.first);
      _logger.i('Driver cargado correctamente por email');
      return _cachedDriver;
    }

    _logger.w('Driver no existe por uid ni por email');
    return null;
  }

  Future<Driver?> getDriver(String driverId) async {
    if (_cachedDriver != null && _cachedDriver!.id == driverId) {
      _logger.i('Driver obtenido desde cache');
      return _cachedDriver;
    }

    _logger.i('Obteniendo driver: $driverId');

    try {
      final doc = await _getDocWithCacheFallback(
        operation: 'getDriver',
        ref: _firestore.collection('drivers').doc(driverId),
      );

      if (!doc.exists || doc.data() == null) {
        _logger.w('Driver no existe');
        return null;
      }

      _cachedDriver = Driver.fromFirestore(doc);

      _logger.i('Driver cargado correctamente');
      return _cachedDriver;
    } catch (e, st) {
      _logger.e('Error en getDriver: $e\n$st');
      rethrow;
    }
  }

  Future<Bus?> getAssignedBus(String busId) async {
    if (_cachedBus != null && _cachedBus!.id == busId) {
      _logger.i('Bus obtenido desde cache');
      return _cachedBus;
    }

    _logger.i('Obteniendo bus: $busId');

    try {
      final doc = await _getDocWithCacheFallback(
        operation: 'getAssignedBus',
        ref: _firestore.collection('buses').doc(busId),
      );

      if (!doc.exists || doc.data() == null) {
        _logger.w('Bus no existe');
        return null;
      }

      _cachedBus = Bus.fromFirestore(doc);

      _logger.i('Bus cargado correctamente');
      return _cachedBus;
    } catch (e, st) {
      _logger.e('Error en getAssignedBus: $e\n$st');
      rethrow;
    }
  }

  Future<RouteModel?> getRoute(String routeId) async {
    if (_cachedRoute != null && _cachedRoute!.id == routeId) {
      _logger.i('Ruta obtenida desde cache');
      return _cachedRoute;
    }

    _logger.i('Obteniendo ruta: $routeId');

    try {
      final doc = await _getDocWithCacheFallback(
        operation: 'getRoute',
        ref: _firestore.collection('routes').doc(routeId),
      );

      if (!doc.exists || doc.data() == null) {
        _logger.w('Ruta no existe');
        return null;
      }

      _cachedRoute = RouteModel.fromFirestore(doc);

      _logger.i('Ruta cargada correctamente');
      return _cachedRoute;
    } catch (e, st) {
      _logger.e('Error en getRoute: $e\n$st');
      rethrow;
    }
  }

  // 🔥 Útil si necesitas forzar refresh (ej: logout/login)
  void clearCache() {
    _logger.i('Limpiando cache de DriverService');
    _cachedDriver = null;
    _cachedBus = null;
    _cachedRoute = null;
  }
}