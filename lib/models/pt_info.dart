import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

class PtInfo {
  final String id;
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalSessions;
  final int remainingSessions;
  final DateTime? renewalDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PtInfo({
    required this.id,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    this.startDate,
    this.endDate,
    required this.totalSessions,
    required this.remainingSessions,
    this.renewalDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive {
    if (endDate == null) return false;
    return endDate!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'trainerId': trainerId,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'totalSessions': totalSessions,
      'remainingSessions': remainingSessions,
      'renewalDate': renewalDate != null
          ? Timestamp.fromDate(renewalDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PtInfo.fromMap(Map<String, dynamic> map) {
    final totalSessions = _requiredNonNegativeInt(map, 'totalSessions');
    final remainingSessions = _requiredNonNegativeInt(map, 'remainingSessions');
    if (remainingSessions > totalSessions) {
      throw ArgumentError('잔여 PT 횟수는 전체 PT 횟수보다 클 수 없습니다.');
    }

    return PtInfo(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      trainerId: map['trainerId'] as String?,
      startDate: FirestoreDate.parseNullable(map['startDate'], 'startDate'),
      endDate: FirestoreDate.parseNullable(map['endDate'], 'endDate'),
      totalSessions: totalSessions,
      remainingSessions: remainingSessions,
      renewalDate: FirestoreDate.parseNullable(
        map['renewalDate'],
        'renewalDate',
      ),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static int _requiredNonNegativeInt(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    final value = map[fieldName];
    if (value is int && value >= 0) return value;
    throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
  }
}
