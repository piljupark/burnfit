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

  WorkoutExerciseDraft({
    required this.name,
    required this.category,
    required this.sets,
    this.unit = WeightUnit.kg,
    this.restSeconds = 90,
  });

  factory WorkoutExerciseDraft.fromExercise({
    required Exercise exercise,
    required WorkoutCategory category,
  }) {
    return WorkoutExerciseDraft(
      name: exercise.name,
      category: category,
      unit: WeightUnit.kg,
      restSeconds: 90,
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
      sets: sets.isEmpty ? [WorkoutSetDraft()] : sets,
    );
  }

  double get totalVolume {
    return sets.fold(
      0,
      (sum, set) => sum + ((set.weight ?? 0) * (set.reps ?? 0)),
    );
  }

  double? get maxWeight {
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
    return '회';
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

      final weightInKg = weightTextToKg(
        set.weightController.text,
        lbs: unit == WeightUnit.lbs,
        memo: set.unitMemo,
      );

      validSets.add(ExerciseSet(weight: weightInKg, reps: reps));
    }

    if (name.trim().isEmpty || validSets.isEmpty) return null;

    return Exercise(name: name.trim(), sets: validSets);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'unit': unit.name,
      'restSeconds': restSeconds,
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

  const PreviousExerciseStats({
    required this.name,
    required this.date,
    required this.maxWeight,
    required this.totalVolume,
  });
}

enum ComparisonTone { up, down, same, muted }

enum WeightUnit { kg, lbs }

enum ExerciseMenuActionType { toggleUnit, restTimer, delete }

class ExerciseMenuAction {
  final ExerciseMenuActionType type;
  final int? restSeconds;

  const ExerciseMenuAction({required this.type, this.restSeconds});
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
