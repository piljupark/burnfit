import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../widgets/workout_parts.dart';

// 지표 이름·단위·숫자 글자는 회원 운동과 같은 계산을 쓴다 (`widgets/workout_parts.dart`).

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────

class TrainerExerciseDraft {
  final String name;

  /// 이 종목의 부위 (기록에는 부위가 하나만 저장되므로, 불러올 때 종목 이름으로 다시 찾는다).
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
              weight: formatWeight(s.weight),
              reps: s.reps.toString(),
              done: true,
            ),
          )
          .toList(),
    );
  }

  /// 입력 단위 그대로의 볼륨 (무게 × 횟수).
  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + ((s.weight ?? 0) * (s.reps ?? 0)));

  /// kg으로 환산한 근력 볼륨. 유산소(속도 × 분)는 볼륨이 아니므로 0.
  double get volumeKg {
    if (isCardio) return 0;
    final volume = totalVolume;
    return unit == TrainerWeightUnit.kg ? volume : volume / kLbsPerKg;
  }

  /// 유산소 종목의 운동한 분 (세트의 '시간' 합). 근력은 0.
  int get cardioMinutes =>
      isCardio ? sets.fold(0, (sum, s) => sum + (s.reps ?? 0)) : 0;

  double? get maxWeight {
    final values = sets.map((s) => s.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get isCardio => category == WorkoutCategory.cardio;

  String get primaryMetricLabel {
    if (isCardio) return cardioPrimaryMetricLabel(name);
    return unit.label;
  }

  String get secondaryMetricLabel => isCardio ? '시간' : '회';

  String get primaryMetricSuffix {
    if (isCardio) return cardioPrimaryMetricSuffix(name);
    return unit.label;
  }

  /// 무언가 입력했지만 횟수(유산소는 시간)가 없거나 값이 잘못돼 저장에서 빠지는 세트 수.
  int get droppedSetCount => sets.where((s) => s.hasInput && !s.isValid).length;

  /// 저장할 운동. 횟수만 필수이고, 무게가 비거나 0이면 맨몸 운동으로 0kg을 남긴다
  /// (회원 운동 `WorkoutExerciseDraft.toExercise`와 같은 기준). 저장할 세트가 없으면 null.
  Exercise? toExercise() {
    final validSets = <ExerciseSet>[];
    for (final set in sets) {
      if (!set.isValid) continue;
      final weightInKg = weightTextToKg(
        set.weightController.text,
        lbs: unit == TrainerWeightUnit.lbs,
        memo: set.unitMemo,
      );
      validSets.add(ExerciseSet(weight: weightInKg, reps: set.reps!));
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

  /// 무게 단위를 바꿀 때 원래 값을 기억한다 (왕복 오차 방지).
  final WeightToggleMemo unitMemo = WeightToggleMemo();

  TrainerSetDraft({String weight = '', String reps = '', this.done = false})
    : weightController = TextEditingController(text: weight),
      repsController = TextEditingController(text: reps);

  double? get weight => double.tryParse(weightController.text.trim());
  int? get reps => int.tryParse(repsController.text.trim());

  bool get hasInput =>
      weightController.text.trim().isNotEmpty ||
      repsController.text.trim().isNotEmpty;

  /// 저장되는 세트: 횟수 1 이상, 무게는 비었거나 0 이상의 숫자.
  bool get isValid {
    final r = reps;
    if (r == null || r <= 0) return false;
    final weightText = weightController.text.trim();
    if (weightText.isEmpty) return true;
    final w = weight;
    return w != null && w >= 0;
  }

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
