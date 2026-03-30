import 'package:cloud_firestore/cloud_firestore.dart';
import 'bus.dart';
import 'route.dart';

class Driver {
  final String id;
  final String name;
  final String email;
  final DocumentReference assignedBusRef;
  final bool active;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.assignedBusRef,
    required this.active,
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Driver(
      id: doc.id,
      name: data['name'],
      email: data['email'],
      assignedBusRef: data['assignedBusRef'] as DocumentReference,
      active: data['active'],
    );
  }
}
