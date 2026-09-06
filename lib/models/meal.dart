import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeLabel on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return '아침';
      case MealType.lunch:
        return '점심';
      case MealType.dinner:
        return '저녁';
      case MealType.snack:
        return '간식';
    }
  }
}

class Meal {
  final String id;
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final MealType mealType;
  final String mealDate;
  final String? mealTime;
  final List<String> imageUrls;
  final String? description;
  final int? calories;
  final bool hasFeedback;
  final String? feedbackId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Meal({
    required this.id,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    required this.mealType,
    required this.mealDate,
    this.mealTime,
    required this.imageUrls,
    this.description,
    this.calories,
    this.hasFeedback = false,
    this.feedbackId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'trainerId': trainerId,
      'mealType': mealType.name,
      'mealDate': mealDate,
      'mealTime': mealTime,
      'imageUrls': imageUrls,
      'description': description,
      'calories': calories,
      'hasFeedback': hasFeedback,
      'feedbackId': feedbackId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      trainerId: map['trainerId'] as String?,
      mealType: _parseMealType(map['mealType']),
      mealDate: _requiredString(map, 'mealDate'),
      mealTime: map['mealTime'] as String?,
      imageUrls: _parseImageUrls(map['imageUrls']),
      description: map['description'] as String?,
      calories: _optionalNonNegativeInt(map, 'calories'),
      hasFeedback: map['hasFeedback'] as bool? ?? false,
      feedbackId: map['feedbackId'] as String?,
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  Meal copyWith({bool? hasFeedback, String? feedbackId, DateTime? updatedAt}) {
    return Meal(
      id: id,
      centerId: centerId,
      memberId: memberId,
      memberName: memberName,
      trainerId: trainerId,
      mealType: mealType,
      mealDate: mealDate,
      mealTime: mealTime,
      imageUrls: imageUrls,
      description: description,
      calories: calories,
      hasFeedback: hasFeedback ?? this.hasFeedback,
      feedbackId: feedbackId ?? this.feedbackId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static MealType _parseMealType(Object? value) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final type in MealType.values) {
        if (type.name == normalized) return type;
      }
      if (normalized == 'morning' || normalized == '아침') {
        return MealType.breakfast;
      }
      if (normalized == 'noon' || normalized == '점심') {
        return MealType.lunch;
      }
      if (normalized == 'evening' || normalized == '저녁') {
        return MealType.dinner;
      }
      if (normalized == '간식') return MealType.snack;
    }
    throw ArgumentError('식단 타입이 올바르지 않습니다.');
  }

  static List<String> _parseImageUrls(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw ArgumentError('식단 이미지 형식이 올바르지 않습니다.');
    }
    return value
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static int? _optionalNonNegativeInt(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    final value = map[fieldName];
    if (value == null) return null;
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0) return value.round();
    throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
  }
}
