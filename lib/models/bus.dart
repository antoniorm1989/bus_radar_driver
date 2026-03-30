import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String id;
  final String routeId;
  final DocumentReference assignedDriverRef;
  final bool active;
  final String? model;
  final String? plate;
  final double? lat;
  final double? lng;

  Bus({
    required this.id,
    required this.routeId,
    required this.assignedDriverRef,
    required this.active,
    this.model,
    this.plate,
    this.lat,
    this.lng,
  });

  factory Bus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bus(
      id: doc.id,
      routeId: data['routeId'],
      assignedDriverRef: data['assignedDriverRef'] as DocumentReference,
      active: data['active'],
      model: data['model'],
      plate: data['plate'],
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
    );
  }
}
