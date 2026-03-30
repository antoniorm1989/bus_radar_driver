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
    return RouteModel(
      id: doc.id,
      name: data['name'],
      active: data['active'],
    );
  }
}
