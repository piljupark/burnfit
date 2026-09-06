import 'package:flutter/material.dart';

import '../../models/workout.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const double trainerCellHeight = 64;
const double trainerCellRadius = 10;
const double trainerCellGap = 8;

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

String trainerFormatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String trainerFormatWeight(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String trainerFormatMetricValue(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String trainerCardioPrimaryMetricLabel(String name) {
  final n = name.replaceAll(' ', '');
  if (n.contains('러닝머신') || n.contains('인터벌') || n.contains('조깅')) return '속도';
  if (n.contains('인클라인')) return '경사';
  if (n.contains('사이클') || n.contains('싸이클')) return '강도';
  if (n.contains('스텝밀') || n.contains('천국의계단')) return '레벨';
  if (n.contains('일립티컬')) return '강도';
  if (n.contains('로잉')) return '거리';
  if (n.contains('줄넘기') || n.contains('버피')) return '횟수';
  return '강도';
}

String trainerCardioPrimaryMetricSuffix(String name) {
  switch (trainerCardioPrimaryMetricLabel(name)) {
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

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────

class TrainerExerciseDraft {
  final String name;
  final WorkoutCategory category;
  final List<TrainerSetDraft> sets;
  TrainerWeightUnit unit = TrainerWeightUnit.kg;

  TrainerExerciseDraft({
    required this.name,
    required this.category,
    required this.sets,
  });

  factory TrainerExerciseDraft.fromExercise({
    required Exercise exercise,
    required WorkoutCategory category,
  }) {
    return TrainerExerciseDraft(
      name: exercise.name,
      category: category,
      sets: exercise.sets
          .map(
            (s) => TrainerSetDraft(
              weight: trainerFormatWeight(s.weight),
              reps: s.reps.toString(),
              done: true,
            ),
          )
          .toList(),
    );
  }

  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + ((s.weight ?? 0) * (s.reps ?? 0)));

  double? get maxWeight {
    final values = sets.map((s) => s.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get isCardio => category == WorkoutCategory.cardio;

  String get primaryMetricLabel {
    if (isCardio) return trainerCardioPrimaryMetricLabel(name);
    return unit.label;
  }

  String get secondaryMetricLabel => isCardio ? '시간' : '회';

  String get primaryMetricSuffix {
    if (isCardio) return trainerCardioPrimaryMetricSuffix(name);
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
      final weightInKg = unit == TrainerWeightUnit.kg
          ? rawWeight
          : rawWeight / 2.2046226218;
      validSets.add(ExerciseSet(weight: weightInKg, reps: reps));
    }
    if (name.trim().isEmpty || validSets.isEmpty) return null;
    return Exercise(name: name.trim(), sets: validSets);
  }

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }
}

class TrainerSetDraft {
  final TextEditingController weightController;
  final TextEditingController repsController;
  bool done;

  TrainerSetDraft({String weight = '', String reps = '', this.done = false})
    : weightController = TextEditingController(text: weight),
      repsController = TextEditingController(text: reps);

  double? get weight => double.tryParse(weightController.text.trim());
  int? get reps => int.tryParse(repsController.text.trim());

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class TrainerPickedExercise {
  final String name;
  final WorkoutCategory category;
  final bool custom;

  const TrainerPickedExercise({
    required this.name,
    required this.category,
    this.custom = false,
  });
}

class TrainerPreviousStats {
  final String date;
  final double maxWeight;

  const TrainerPreviousStats({required this.date, required this.maxWeight});
}

enum TrainerComparisonTone { up, down, same, muted }

enum TrainerWeightUnit { kg, lbs }

extension TrainerWeightUnitLabel on TrainerWeightUnit {
  String get label => this == TrainerWeightUnit.kg ? 'kg' : 'lbs';
}

enum TrainerMenuActionType { toggleUnit, delete }

class TrainerMenuAction {
  final TrainerMenuActionType type;
  const TrainerMenuAction({required this.type});
}

class TrainerExerciseComparison {
  final String label;
  final TrainerComparisonTone tone;

  const TrainerExerciseComparison({required this.label, required this.tone});
}
