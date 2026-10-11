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

  /// 무게 칸을 보일지. 맨몸 운동은 처음부터 숨기고, 종목 메뉴에서 바꿀 수 있다. 유산소는 늘 보인다.
  bool _showWeight;

  /// 종목 메모 (빈 글자면 없음). 회원도 PT 기록에서 본다.
  String note;

  TrainerExerciseDraft({
    required this.name,
    required this.category,
    required this.sets,
    bool? showWeight,
    this.note = '',
  }) : _showWeight = showWeight ?? !isBodyweightExercise(name);

  bool get showWeight => isCardio || _showWeight;
  set showWeight(bool value) => _showWeight = value;

  factory TrainerExerciseDraft.fromExercise({
    required Exercise exercise,
    required WorkoutCategory category,
  }) {
    return TrainerExerciseDraft(
      name: exercise.name,
      category: category,
      // 맨몸 운동이라도 무게를 적어 둔 기록이면 무게 칸을 보인다.
      showWeight:
          !isBodyweightExercise(exercise.name) ||
          exercise.sets.any((s) => s.weight > 0),
      note: exercise.note ?? '',
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

  /// 입력 단위 그대로의 볼륨 (무게 × 횟수). 무게 칸을 숨겼으면 0.
  double get totalVolume => showWeight
      ? sets.fold(0, (sum, s) => sum + ((s.weight ?? 0) * (s.reps ?? 0)))
      : 0;

  int? get maxReps {
    final values = sets.map((s) => s.reps).whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

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
    if (!showWeight) return null;
    final values = sets.map((s) => s.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get isCardio => category == WorkoutCategory.cardio;

  String get primaryMetricLabel {
    if (isCardio) return cardioPrimaryMetricLabel(name);
    return unit.label;
  }

  String get secondaryMetricLabel => isCardio ? '시간' : strengthCountLabel(name);

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
      final weightInKg = showWeight
          ? weightTextToKg(
              set.weightController.text,
              lbs: unit == TrainerWeightUnit.lbs,
              memo: set.unitMemo,
            )
          : 0.0;
      validSets.add(ExerciseSet(weight: weightInKg, reps: set.reps!));
    }
    if (name.trim().isEmpty || validSets.isEmpty) return null;
    return Exercise(
      name: name.trim(),
      sets: validSets,
      note: note.trim().isEmpty ? null : note.trim(),
    );
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

  /// 가장 많이 한 횟수 (맨몸 운동 비교용, 버티는 운동은 초).
  final int maxReps;

  const TrainerPreviousStats({
    required this.date,
    required this.maxWeight,
    this.maxReps = 0,
  });
}

enum TrainerComparisonTone { up, down, same, muted }

enum TrainerWeightUnit { kg, lbs }

extension TrainerWeightUnitLabel on TrainerWeightUnit {
  String get label => this == TrainerWeightUnit.kg ? 'kg' : 'lbs';
}

class TrainerExerciseComparison {
  final String label;
  final TrainerComparisonTone tone;

  const TrainerExerciseComparison({required this.label, required this.tone});
}
