import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/app_icon_button.dart';
import 'trainer_workout_models.dart';

/// 저장된 PT 기록 한 건 (시안 Tr-PtRecord-Saved): 좌우 20 안쪽 블록 + 아래 hairline(카드 없음).
/// 위 4 아래 12. 머리: '하체'(14 ink 500) · '총 볼륨 7,520kg · 8세트'(14 mute) + 수정·삭제(44, 아이콘 20 body)
/// → 운동 줄(15/500 이름 · 13 mute '4세트 · 최고 120kg', 위아래 6).
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
      if (!_isCardio)
        '총 볼륨 ${NumberFormat('#,##0').format(workout.totalVolume.round())}kg',
      '${workout.totalSets}세트',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: workout.category.label,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(text: ' · $summary'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.fieldLabel,
                  ),
                ),
                AppIconButton(
                  icon: AppIcons.edit,
                  label: '기록 수정',
                  onPressed: onEdit,
                  color: AppColors.body,
                ),
                // 시안 margin-right −12: 아이콘을 화면 오른쪽 20 선에 맞춘다
                Transform.translate(
                  offset: const Offset(AppSpacing.md, 0),
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _SavedExerciseRow(
                  exercise: exercise,
                  isCardio: _isCardio,
                ),
              ),
          ],
        ),
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
            style: AppTextStyles.bodyMd.medium.natural,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          isCardio ? _cardioSummary(exercise) : _strengthSummary(exercise),
          style: AppTextStyles.bodySm.natural,
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
