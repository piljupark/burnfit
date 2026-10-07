import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_tag.dart';
import 'trainer_workout_models.dart';

/// 저장된 PT 기록 한 덩어리 (카드 없이 화면 폭, 아래 hairline).
/// 머리: 부위 태그 + 요약 줄 + 수정/삭제 아이콘 버튼 → 운동 줄(이름 · 세트 요약).
class TrainerSavedWorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TrainerSavedWorkoutCard({
    super.key,
    required this.workout,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isCardio => workout.category == WorkoutCategory.cardio;

  @override
  Widget build(BuildContext context) {
    final summary = [
      if (!_isCardio) '총 볼륨 ${workout.totalVolume.toStringAsFixed(0)}kg',
      '${workout.totalSets}세트',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTag(workout.category.label),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm,
                ),
              ),
              AppIconButton(
                icon: AppIcons.edit,
                label: '기록 수정',
                onPressed: onEdit,
                color: AppColors.body,
              ),
              Transform.translate(
                offset: const Offset(12, 0),
                child: AppIconButton(
                  icon: AppIcons.trash,
                  label: '기록 삭제',
                  onPressed: onDelete,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
          for (final exercise in workout.exercises)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: _SavedExerciseRow(exercise: exercise, isCardio: _isCardio),
            ),
        ],
      ),
    );
  }
}

class _SavedExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final bool isCardio;

  const _SavedExerciseRow({required this.exercise, required this.isCardio});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            exercise.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          isCardio ? _cardioSummary(exercise) : _strengthSummary(exercise),
          style: AppTextStyles.bodySm,
        ),
      ],
    );
  }

  String _strengthSummary(Exercise exercise) {
    if (exercise.sets.isEmpty) return '0세트';
    final max = exercise.sets
        .map((s) => s.weight)
        .reduce((a, b) => a > b ? a : b);
    return '${exercise.sets.length}세트 · 최고 ${trainerFormatWeight(max)}kg';
  }

  String _cardioSummary(Exercise exercise) {
    final metricLabel = trainerCardioPrimaryMetricLabel(exercise.name);
    final metricSuffix = trainerCardioPrimaryMetricSuffix(exercise.name);
    final primaryMax = exercise.sets.isEmpty
        ? 0.0
        : exercise.sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
    final minutes = exercise.sets.fold<int>(0, (sum, s) => sum + s.reps);
    return '$metricLabel ${trainerFormatMetricValue(primaryMax)}$metricSuffix · $minutes분';
  }
}
