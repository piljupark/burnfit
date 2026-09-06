import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum JoinRequestStatus { pending, approved, rejected }

class JoinRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String centerId;
  final String centerName;
  final String role;
  final JoinRequestStatus status;
  final DateTime createdAt;

  const JoinRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.centerId,
    required this.centerName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'centerId': centerId,
      'centerName': centerName,
      'role': role,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userEmail: map['userEmail'] as String,
      centerId: map['centerId'] as String,
      centerName: map['centerName'] as String,
      role: map['role'] as String,
      status: JoinRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
    );
  }
}
