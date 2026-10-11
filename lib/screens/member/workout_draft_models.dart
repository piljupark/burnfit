import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../widgets/workout_parts.dart';

export '../../widgets/workout_parts.dart'
    show
        cardioPrimaryMetricLabel,
        cardioPrimaryMetricSuffix,
        formatMetricValue,
        formatWeight,
        kLbsPerKg;

const double workoutCellHeight = 64;
const double workoutCellRadius = 10;
const double workoutGap = 8;

String inferExerciseCategoryLabel(
  String exerciseName,
  WorkoutCategory fallback,
) {
  return (exerciseCategoryOf(exerciseName) ?? fallback).label;
}

class WorkoutExerciseDraft {
  final String name;
  final WorkoutCategory category;
  final List<WorkoutSetDraft> sets;
  WeightUnit unit;
  int restSeconds;

  /// 무게 칸을 보일지. 맨몸 운동은 처음부터 숨기고, 종목 메뉴에서 바꿀 수 있다. 유산소는 늘 보인다.
  bool _showWeight;

  /// 종목 메모 (빈 글자면 없음).
  String note;

  WorkoutExerciseDraft({
    required this.name,
    required this.category,
    required this.sets,
    this.unit = WeightUnit.kg,
    this.restSeconds = 90,
    bool? showWeight,
    this.note = '',
  }) : _showWeight = showWeight ?? !isBodyweightExercise(name);

  bool get showWeight => isCardio || _showWeight;
  set showWeight(bool value) => _showWeight = value;

  factory WorkoutExerciseDraft.fromExercise({
    required Exercise exercise,
    required WorkoutCategory category,
  }) {
    return WorkoutExerciseDraft(
      name: exercise.name,
      category: category,
      unit: WeightUnit.kg,
      restSeconds: 90,
      // 맨몸 운동이라도 무게를 적어 둔 기록이면 무게 칸을 보인다.
      showWeight:
          !isBodyweightExercise(exercise.name) ||
          exercise.sets.any((set) => set.weight > 0),
      note: exercise.note ?? '',
      sets: exercise.sets
          .map(
            (set) => WorkoutSetDraft(
              weight: formatWeight(set.weight),
              reps: set.reps.toString(),
              done: true,
            ),
          )
          .toList(),
    );
  }

  factory WorkoutExerciseDraft.fromMap(Map<String, dynamic> map) {
    final categoryName = map['category'] as String?;
    final unitName = map['unit'] as String?;
    final restSeconds = map['restSeconds'] as int? ?? 90;

    final rawSets = map['sets'];
    final sets = <WorkoutSetDraft>[];

    if (rawSets is List) {
      for (final item in rawSets) {
        if (item is Map<String, dynamic>) {
          sets.add(WorkoutSetDraft.fromMap(item));
        } else if (item is Map) {
          sets.add(WorkoutSetDraft.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return WorkoutExerciseDraft(
      name: map['name'] as String? ?? '',
      category: WorkoutCategory.values.firstWhere(
        (category) => category.name == categoryName,
        orElse: () => WorkoutCategory.chest,
      ),
      unit: WeightUnit.values.firstWhere(
        (unit) => unit.name == unitName,
        orElse: () => WeightUnit.kg,
      ),
      restSeconds: restSeconds,
      showWeight: map['showWeight'] as bool?,
      note: map['note'] as String? ?? '',
      sets: sets.isEmpty ? [WorkoutSetDraft()] : sets,
    );
  }

  /// 무게 칸을 숨겼으면 적어 둔 무게도 0으로 본다.
  double get totalVolume {
    if (!showWeight) return 0;
    return sets.fold(
      0,
      (sum, set) => sum + ((set.weight ?? 0) * (set.reps ?? 0)),
    );
  }

  int? get maxReps {
    final values = sets.map((set) => set.reps).whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double? get maxWeight {
    if (!showWeight) return null;
    final values = sets.map((set) => set.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get isCardio => category == WorkoutCategory.cardio;

  String get primaryMetricLabel {
    if (isCardio) return cardioPrimaryMetricLabel(name);
    return unit.label;
  }

  String get secondaryMetricLabel {
    if (isCardio) return '시간';
    return strengthCountLabel(name);
  }

  String get primaryMetricSuffix {
    if (isCardio) return cardioPrimaryMetricSuffix(name);
    return unit.label;
  }

  /// [doneOnly]면 완료 표시한 세트만 담는다 (앱을 닫아 자동 저장할 때).
  Exercise? toExercise({bool doneOnly = false}) {
    final validSets = <ExerciseSet>[];

    for (final set in sets) {
      if (doneOnly && !set.done) continue;
      final rawWeight = set.weight;
      final reps = set.reps;

      // 무게가 비었거나 0이면 맨몸 운동(푸시업·턱걸이 등)으로 보고 0kg으로 남긴다. 횟수는 필수.
      if (reps == null || reps <= 0) continue;
      if (rawWeight != null && rawWeight < 0) continue;

      final weightInKg = showWeight
          ? weightTextToKg(
              set.weightController.text,
              lbs: unit == WeightUnit.lbs,
              memo: set.unitMemo,
            )
          : 0.0;

      validSets.add(ExerciseSet(weight: weightInKg, reps: reps));
    }

    if (name.trim().isEmpty || validSets.isEmpty) return null;

    return Exercise(
      name: name.trim(),
      sets: validSets,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'unit': unit.name,
      'restSeconds': restSeconds,
      'showWeight': _showWeight,
      'note': note,
      'sets': sets.map((set) => set.toMap()).toList(),
    };
  }

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class WorkoutSetDraft {
  final TextEditingController weightController;
  final TextEditingController repsController;
  bool done;

  /// 무게 단위를 바꿀 때 원래 값을 기억한다 (왕복 오차 방지).
  final WeightToggleMemo unitMemo = WeightToggleMemo();

  WorkoutSetDraft({String weight = '', String reps = '', this.done = false})
    : weightController = TextEditingController(text: weight),
      repsController = TextEditingController(text: reps);

  factory WorkoutSetDraft.fromMap(Map<String, dynamic> map) {
    return WorkoutSetDraft(
      weight: map['weight']?.toString() ?? '',
      reps: map['reps']?.toString() ?? '',
      done: map['done'] as bool? ?? false,
    );
  }

  double? get weight => double.tryParse(weightController.text.trim());
  int? get reps => int.tryParse(repsController.text.trim());

  Map<String, dynamic> toMap() {
    return {
      'weight': weightController.text.trim(),
      'reps': repsController.text.trim(),
      'done': done,
    };
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class PickedExercise {
  final String name;
  final WorkoutCategory category;
  final bool custom;

  const PickedExercise({
    required this.name,
    required this.category,
    this.custom = false,
  });
}

class PreviousExerciseStats {
  final String name;
  final String date;
  final double maxWeight;
  final double totalVolume;

  /// 가장 많이 한 횟수 (맨몸 운동 비교용, 버티는 운동은 초).
  final int maxReps;

  const PreviousExerciseStats({
    required this.name,
    required this.date,
    required this.maxWeight,
    required this.totalVolume,
    this.maxReps = 0,
  });
}

enum ComparisonTone { up, down, same, muted }

enum WeightUnit { kg, lbs }

enum ExerciseMenuActionType {
  toggleUnit,
  toggleWeight,
  note,
  restTimer,
  delete,
}

class ExerciseMenuAction {
  final ExerciseMenuActionType type;
  final int? restSeconds;

  /// [ExerciseMenuActionType.note]: 고친 메모.
  final String? note;

  const ExerciseMenuAction({required this.type, this.restSeconds, this.note});
}

class ExerciseComparison {
  final String label;
  final ComparisonTone tone;

  const ExerciseComparison({required this.label, required this.tone});
}

extension WeightUnitLabel on WeightUnit {
  String get label {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lbs:
        return 'lbs';
    }
  }
}
