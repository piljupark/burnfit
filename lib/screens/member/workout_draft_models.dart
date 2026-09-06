import 'package:flutter/material.dart';

import '../../core/exercise_data.dart';
import '../../models/workout.dart';

const double workoutCellHeight = 64;
const double workoutCellRadius = 10;
const double workoutGap = 8;

String cardioPrimaryMetricLabel(String name) {
  final n = name.replaceAll(' ', '');

  if (n.contains('러닝머신') || n.contains('인터벌') || n.contains('조깅')) {
    return '속도';
  }

  if (n.contains('인클라인')) {
    return '경사';
  }

  if (n.contains('사이클') || n.contains('싸이클')) {
    return '강도';
  }

  if (n.contains('스텝밀') || n.contains('천국의계단')) {
    return '레벨';
  }

  if (n.contains('일립티컬')) {
    return '강도';
  }

  if (n.contains('로잉')) {
    return '거리';
  }

  if (n.contains('줄넘기') || n.contains('버피')) {
    return '횟수';
  }

  return '강도';
}

String cardioPrimaryMetricSuffix(String name) {
  final label = cardioPrimaryMetricLabel(name);

  switch (label) {
    case '속도':
      return 'km/h';
    case '경사':
      return '%';
    case '거리':
      return 'm';
    case '횟수':
      return '회';
    default:
      return '';
  }
}

String formatMetricValue(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String formatWeight(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String inferExerciseCategoryLabel(
  String exerciseName,
  WorkoutCategory fallback,
) {
  for (final entry in ExerciseData.exercises.entries) {
    if (entry.value.contains(exerciseName)) {
      return entry.key.label;
    }
  }

  return fallback.label;
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

  Exercise? toExercise() {
    final validSets = <ExerciseSet>[];

    for (final set in sets) {
      final rawWeight = set.weight;
      final reps = set.reps;

      if (rawWeight == null || rawWeight <= 0 || reps == null || reps <= 0) {
        continue;
      }

      final weightInKg = unit == WeightUnit.kg
          ? rawWeight
          : rawWeight / 2.2046226218;

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
