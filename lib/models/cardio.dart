import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum CardioType { treadmill, cycle, other }

extension CardioTypeLabel on CardioType {
  String get label {
    switch (this) {
      case CardioType.treadmill:
        return '러닝머신';
      case CardioType.cycle:
        return '싸이클';
      case CardioType.other:
        return '기타';
    }
  }
}

class Cardio {
  final String id;
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final String cardioDate;
  final CardioType type;
  final int durationMinutes;

  // treadmill
  final double? speed;

  // cycle
  final int? intensity;

  // other
  final String? name;

  final String? note;
  final bool hasFeedback;
  final String? feedbackId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cardio({
    required this.id,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    required this.cardioDate,
    required this.type,
    required this.durationMinutes,
    this.speed,
    this.intensity,
    this.name,
    this.note,
    this.hasFeedback = false,
    this.feedbackId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get summary {
    switch (type) {
      case CardioType.treadmill:
        return '${speed ?? '-'} km/h · $durationMinutes분';
      case CardioType.cycle:
        return '강도 ${intensity ?? '-'} · $durationMinutes분';
      case CardioType.other:
        return '${name ?? '기타 유산소'} · $durationMinutes분';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'trainerId': trainerId,
      'cardioDate': cardioDate,
      'type': type.name,
      'durationMinutes': durationMinutes,
      'speed': speed,
      'intensity': intensity,
      'name': name,
      'note': note,
      'hasFeedback': hasFeedback,
      'feedbackId': feedbackId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Cardio.fromMap(Map<String, dynamic> map) {
    final type = _parseType(map['type']);
    return Cardio(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      trainerId: map['trainerId'] as String?,
      cardioDate: _requiredString(map, 'cardioDate'),
      type: type,
      durationMinutes: _requiredPositiveInt(map, 'durationMinutes'),
      speed: _optionalPositiveDouble(map, 'speed'),
      intensity: _optionalPositiveInt(map, 'intensity'),
      name: _parseName(map, type),
      note: map['note'] as String?,
      hasFeedback: map['hasFeedback'] as bool? ?? false,
      feedbackId: map['feedbackId'] as String?,
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static CardioType _parseType(Object? value) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final type in CardioType.values) {
        if (type.name == normalized) return type;
      }
      if (normalized == 'running' ||
          normalized == 'run' ||
          normalized == '러닝머신') {
        return CardioType.treadmill;
      }
      if (normalized == 'bike' ||
          normalized == 'bicycle' ||
          normalized == '싸이클' ||
          normalized == '사이클') {
        return CardioType.cycle;
      }
      if (normalized == 'etc' || normalized == '기타') return CardioType.other;
    }
    throw ArgumentError('유산소 타입이 올바르지 않습니다.');
  }

  static int _requiredPositiveInt(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.round();
    throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
  }

  static int? _optionalPositiveInt(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value == null) return null;
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.round();
    throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
  }

  static double? _optionalPositiveDouble(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    final value = map[fieldName];
    if (value == null) return null;
    if (value is num && value > 0) return value.toDouble();
    throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
  }

  static String? _parseName(Map<String, dynamic> map, CardioType type) {
    final value = map['name'];
    if (value == null) {
      if (type == CardioType.other) {
        return '기타 유산소';
      }
      return null;
    }
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('유산소 이름이 비어 있습니다.');
  }
}
