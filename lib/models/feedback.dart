import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum FeedbackTargetType { meal, workout, cardio, general }

extension FeedbackTargetTypeLabel on FeedbackTargetType {
  String get label {
    switch (this) {
      case FeedbackTargetType.meal:
        return '식단';
      case FeedbackTargetType.workout:
        return '운동';
      case FeedbackTargetType.cardio:
        return '유산소';
      case FeedbackTargetType.general:
        return '일반';
    }
  }
}

class Feedback {
  final String id;
  final String centerId;
  final String trainerId;
  final String trainerName;
  final String memberId;
  final String memberName;
  final FeedbackTargetType targetType;
  final String? targetId;
  final String? targetDate;
  final String content;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Feedback({
    required this.id,
    required this.centerId,
    required this.trainerId,
    required this.trainerName,
    required this.memberId,
    required this.memberName,
    required this.targetType,
    this.targetId,
    this.targetDate,
    required this.content,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRead => readAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'memberId': memberId,
      'memberName': memberName,
      'targetType': targetType.name,
      'targetId': targetId,
      'targetDate': targetDate,
      'content': content,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Feedback.fromMap(Map<String, dynamic> map) {
    final targetType = _parseTargetType(map['targetType']);
    final targetId = map['targetId'] as String?;

    return Feedback(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      trainerId: _requiredString(map, 'trainerId'),
      trainerName: map['trainerName'] as String? ?? '',
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      targetType: targetType,
      targetId: targetId,
      targetDate: map['targetDate'] as String?,
      content: _requiredString(map, 'content'),
      readAt: FirestoreDate.parseNullable(map['readAt'], 'readAt'),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static FeedbackTargetType _parseTargetType(Object? value) {
    if (value == null) return FeedbackTargetType.general;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return FeedbackTargetType.general;
      for (final type in FeedbackTargetType.values) {
        if (type.name == normalized) return type;
      }
      if (normalized == 'diet' || normalized == '식단') {
        return FeedbackTargetType.meal;
      }
      if (normalized == 'exercise' || normalized == '운동') {
        return FeedbackTargetType.workout;
      }
      if (normalized == '유산소') return FeedbackTargetType.cardio;
      if (normalized == 'common' || normalized == '일반') {
        return FeedbackTargetType.general;
      }
    }
    throw ArgumentError('피드백 대상 타입이 올바르지 않습니다.');
  }

  Feedback copyWith({DateTime? readAt, DateTime? updatedAt}) {
    return Feedback(
      id: id,
      centerId: centerId,
      trainerId: trainerId,
      trainerName: trainerName,
      memberId: memberId,
      memberName: memberName,
      targetType: targetType,
      targetId: targetId,
      targetDate: targetDate,
      content: content,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
