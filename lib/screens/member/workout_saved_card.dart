import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/app_icon_button.dart';
import 'workout_draft_models.dart';

/// 저장된 운동 한 건 (시안 MemA-Workout-Saved): 화면 폭 블록 + 아래 hairline (카드로 감싸지 않는다).
/// 여백 0 8 0 20. 위: 부위 글자(14 mute) + 수정·삭제 아이콘(20, body) /
/// 가운데: 종목 줄(15 · 13 mute, 위아래 4) / 아래: 요약 줄(15/500 숫자 + mute 단위, 위 10 아래 16).
class SavedWorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SavedWorkoutCard({
    super.key,
    required this.workout,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isCardio => workout.category == WorkoutCategory.cardio;

  @override
  Widget build(BuildContext context) {
    final labels = workout.exercises
        .map(
          (exercise) =>
              inferExerciseCategoryLabel(exercise.name, workout.category),
        )
        .toSet()
        .toList();
    final volume = NumberFormat('#,###').format(workout.totalVolume.round());
    final suffixStyle = TextStyle(
      fontWeight: FontWeight.w400,
      color: AppColors.mute,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.sm,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  labels.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fieldLabel,
                ),
              ),
              AppIconButton(
                icon: AppIcons.edit,
                label: '운동 기록 수정',
                onPressed: onEdit,
                color: AppColors.body,
              ),
              AppIconButton(
                icon: AppIcons.trash,
                label: '운동 기록 삭제',
                onPressed: onDelete,
                color: AppColors.body,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final exercise in workout.exercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: _SavedExerciseRow(
                      exercise: exercise,
                      isCardio: _isCardio,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 16),
                  child: Text.rich(
                    TextSpan(
                      children: _isCardio
                          ? [
                              TextSpan(text: '${workout.totalSets}'),
                              TextSpan(text: '세트', style: suffixStyle),
                            ]
                          : [
                              TextSpan(text: volume),
                              TextSpan(
                                text: 'kg · ${workout.totalSets}세트',
                                style: suffixStyle,
                              ),
                            ],
                    ),
                    style: AppTextStyles.bodyMd.medium.natural,
                  ),
                ),
              ],
            ),
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
    final setCount = exercise.sets.length;
    final String detail;

    if (isCardio) {
      final metricLabel = cardioPrimaryMetricLabel(exercise.name);
      final metricSuffix = cardioPrimaryMetricSuffix(exercise.name);
      final primaryMax = exercise.sets.isEmpty
          ? 0.0
          : exercise.sets
                .map((set) => set.weight)
                .reduce((a, b) => a > b ? a : b);
      final minutes = exercise.sets.fold<int>(0, (sum, set) => sum + set.reps);
      detail =
          '$metricLabel ${formatMetricValue(primaryMax)}$metricSuffix · $minutes분';
    } else {
      detail = '$setCount세트';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            exercise.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd.natural,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(detail, style: AppTextStyles.bodySm.natural),
      ],
    );
  }
}
