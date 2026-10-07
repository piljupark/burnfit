import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum WorkoutCategory { shoulder, chest, back, lower, arms, abs, cardio }

enum WorkoutType { personal, pt }

enum WorkoutCreatedByRole { member, trainer }

extension WorkoutCategoryLabel on WorkoutCategory {
  String get label {
    switch (this) {
      case WorkoutCategory.shoulder:
        return '어깨';
      case WorkoutCategory.chest:
        return '가슴';
      case WorkoutCategory.back:
        return '등';
      case WorkoutCategory.lower:
        return '하체';
      case WorkoutCategory.arms:
        return '팔';
      case WorkoutCategory.abs:
        return '복근';
      case WorkoutCategory.cardio:
        return '유산소';
    }
  }
}

class ExerciseSet {
  final double weight;
  final int reps;

  const ExerciseSet({required this.weight, required this.reps});

  Map<String, dynamic> toMap() => {'weight': weight, 'reps': reps};

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    final weight = _requiredNonNegativeDouble(map, 'weight');
    final reps = _requiredPositiveInt(map, 'reps');
    return ExerciseSet(weight: weight, reps: reps);
  }

  static double _requiredNonNegativeDouble(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    final value = map[fieldName];
    if (value is num && value >= 0) return value.toDouble();
    throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
  }

  static int _requiredPositiveInt(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is int && value > 0) return value;
    throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
  }
}

class Exercise {
  final String name;
  final List<ExerciseSet> sets;

  const Exercise({required this.name, required this.sets});

  double get totalVolume =>
      sets.fold(0, (total, s) => total + s.weight * s.reps);

  Map<String, dynamic> toMap() {
    return {'name': name, 'sets': sets.map((s) => s.toMap()).toList()};
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    final sets = (map['sets'] as List?)
        ?.map((s) => ExerciseSet.fromMap(s as Map<String, dynamic>))
        .toList();
    if (sets == null || sets.isEmpty) {
      throw ArgumentError('운동 세트가 비어 있습니다.');
    }

    return Exercise(name: _requiredString(map, 'name'), sets: sets);
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }
}

class Workout {
  final String id;
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final WorkoutType workoutType;
  final String createdById;
  final WorkoutCreatedByRole createdByRole;
  final String? ptSessionId;
  final String workoutDate;
  final WorkoutCategory category;
  final List<Exercise> exercises;
  final String? note;
  final bool hasFeedback;
  final String? feedbackId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int durationSeconds;

  const Workout({
    required this.id,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    this.workoutType = WorkoutType.personal,
    required this.createdById,
    required this.createdByRole,
    this.ptSessionId,
    required this.workoutDate,
    required this.category,
    required this.exercises,
    this.note,
    this.hasFeedback = false,
    this.feedbackId,
    required this.createdAt,
    required this.updatedAt,
    this.durationSeconds = 0,
  });

  int get totalSets => exercises.fold(0, (total, e) => total + e.sets.length);

  /// 근력 볼륨 (무게 × 횟수 합). 유산소 기록은 속도·시간을 같은 칸에 담으므로 볼륨에 넣지 않는다.
  double get totalVolume => category == WorkoutCategory.cardio
      ? 0
      : exercises.fold(0.0, (total, e) => total + e.totalVolume);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'trainerId': trainerId,
      'workoutType': workoutType.name,
      'createdById': createdById,
      'createdByRole': createdByRole.name,
      'ptSessionId': ptSessionId,
      'workoutDate': workoutDate,
      'category': category.name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'note': note,
      'hasFeedback': hasFeedback,
      'feedbackId': feedbackId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'durationSeconds': durationSeconds,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    final exercises = (map['exercises'] as List?)
        ?.map((e) => Exercise.fromMap(e as Map<String, dynamic>))
        .toList();
    if (exercises == null || exercises.isEmpty) {
      throw ArgumentError('운동 종목이 비어 있습니다.');
    }
    final createdByRole = _parseCreatedByRole(map['createdByRole']);

    return Workout(
      id: _requiredString(map, 'id'),
      centerId: _requiredString(map, 'centerId'),
      memberId: _requiredString(map, 'memberId'),
      memberName: map['memberName'] as String? ?? '',
      trainerId: map['trainerId'] as String?,
      workoutType: _parseWorkoutType(map['workoutType']),
      createdById: _parseCreatedById(map, createdByRole),
      createdByRole: createdByRole,
      ptSessionId: map['ptSessionId'] as String?,
      workoutDate: _requiredString(map, 'workoutDate'),
      category: _parseCategory(map['category']),
      exercises: exercises,
      note: map['note'] as String?,
      hasFeedback: map['hasFeedback'] as bool? ?? false,
      feedbackId: map['feedbackId'] as String?,
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
      durationSeconds: _optionalNonNegativeInt(map, 'durationSeconds'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static String _parseCreatedById(
    Map<String, dynamic> map,
    WorkoutCreatedByRole role,
  ) {
    final value = map['createdById'];
    if (value is String && value.trim().isNotEmpty) return value.trim();

    final trainerId = map['trainerId'];
    if (role == WorkoutCreatedByRole.trainer &&
        trainerId is String &&
        trainerId.trim().isNotEmpty) {
      return trainerId.trim();
    }

    return _requiredString(map, 'memberId');
  }

  static int _optionalNonNegativeInt(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    final value = map[fieldName];
    if (value == null) return 0;
    if (value is int && value >= 0) return value;
    throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
  }

  static WorkoutType _parseWorkoutType(Object? value) {
    if (value == null) return WorkoutType.personal;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return WorkoutType.personal;
      for (final type in WorkoutType.values) {
        if (type.name == normalized) return type;
      }
      if (normalized == 'member' || normalized == 'self') {
        return WorkoutType.personal;
      }
      if (normalized == 'trainer' || normalized == 'session') {
        return WorkoutType.pt;
      }
    }
    throw ArgumentError('운동 타입이 올바르지 않습니다.');
  }

  static WorkoutCreatedByRole _parseCreatedByRole(Object? value) {
    if (value == null) return WorkoutCreatedByRole.member;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return WorkoutCreatedByRole.member;
      for (final role in WorkoutCreatedByRole.values) {
        if (role.name == normalized) return role;
      }
    }
    throw ArgumentError('운동 작성자 역할이 올바르지 않습니다.');
  }

  static WorkoutCategory _parseCategory(Object? value) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      for (final category in WorkoutCategory.values) {
        if (category.name == normalized) return category;
      }
      switch (normalized) {
        case '어깨':
        case 'shoulders':
          return WorkoutCategory.shoulder;
        case '가슴':
          return WorkoutCategory.chest;
        case '등':
          return WorkoutCategory.back;
        case '하체':
        case '다리':
        case 'leg':
        case 'legs':
          return WorkoutCategory.lower;
        case '팔':
        case 'arm':
          return WorkoutCategory.arms;
        case '복근':
        case 'core':
          return WorkoutCategory.abs;
        case '유산소':
          return WorkoutCategory.cardio;
      }
    }
    throw ArgumentError('운동 카테고리가 올바르지 않습니다.');
  }
}
