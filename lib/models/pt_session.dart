import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum PtSessionStatus { scheduled, completed, cancelled }

extension PtSessionStatusLabel on PtSessionStatus {
  String get label {
    switch (this) {
      case PtSessionStatus.scheduled:
        return '예약';
      case PtSessionStatus.completed:
        return '완료';
      case PtSessionStatus.cancelled:
        return '취소';
    }
  }
}

class PtSession {
  final String id;
  final String centerId;
  final String trainerId;
  final String trainerName;
  final String memberId;
  final String memberName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? note;
  final PtSessionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PtSession({
    required this.id,
    required this.centerId,
    required this.trainerId,
    required this.trainerName,
    required this.memberId,
    required this.memberName,
    required this.scheduledAt,
    required this.durationMinutes,
    this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'memberId': memberId,
      'memberName': memberName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'note': note,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PtSession.fromMap(Map<String, dynamic> map) {
    return PtSession(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      trainerId: _requiredString(map, 'trainerId'),
      trainerName: map['trainerName'] as String? ?? '',
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      scheduledAt: FirestoreDate.parse(map['scheduledAt'], 'scheduledAt'),
      durationMinutes: _requiredPositiveInt(map, 'durationMinutes'),
      note: map['note'] as String?,
      status: _parseStatus(map['status']),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static int _requiredPositiveInt(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is int && value > 0) return value;
    throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
  }

  static PtSessionStatus _parseStatus(Object? value) {
    if (value is String) {
      for (final status in PtSessionStatus.values) {
        if (status.name == value) return status;
      }
    }
    throw ArgumentError('PT 일정 상태가 올바르지 않습니다.');
  }
}
