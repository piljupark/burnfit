import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

class Center {
  final String id;
  final String name;
  final String? address;
  final String adminId;
  final String status;
  final DateTime createdAt;

  const Center({
    required this.id,
    required this.name,
    this.address,
    required this.adminId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'adminId': adminId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Center.fromMap(Map<String, dynamic> map) {
    return Center(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      adminId: map['adminId'] as String,
      status: map['status'] as String? ?? 'active',
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
    );
  }
}
