import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final String name;
  final bool active;

  RouteModel({
    required this.id,
    required this.name,
    required this.active,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final rawName = data['name'];
    final rawActive = data['active'];

    return RouteModel(
      id: doc.id,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : 'Ruta sin nombre',
      active: rawActive is bool ? rawActive : false,
    );
  }
}
