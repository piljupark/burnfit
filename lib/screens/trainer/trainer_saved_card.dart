import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import 'trainer_workout_models.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(label: workout.category.label),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const Gap(14),
          ...workout.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedExerciseRow(exercise: exercise, isCardio: _isCardio),
            ),
          ),
          const Gap(6),
          Container(height: 1, color: AppColors.border),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _FooterMetric(
                  label: '총 볼륨',
                  value: '${workout.totalVolume.toStringAsFixed(0)}kg',
                ),
              ),
              Expanded(
                child: _FooterMetric(
                  label: '총 세트',
                  value: '${workout.totalSets}세트',
                ),
              ),
              Expanded(
                child: _FooterMetric(
                  label: '운동시간',
                  value: trainerFormatDuration(workout.durationSeconds),
                ),
              ),
            ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 9),
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isCardio
                ? _cardioSummary(exercise)
                : '${exercise.name} ${exercise.sets.length}세트',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  String _cardioSummary(Exercise exercise) {
    final metricLabel = trainerCardioPrimaryMetricLabel(exercise.name);
    final metricSuffix = trainerCardioPrimaryMetricSuffix(exercise.name);
    final primaryMax = exercise.sets.isEmpty
        ? 0.0
        : exercise.sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
    final minutes = exercise.sets.fold<int>(0, (sum, s) => sum + s.reps);
    return '${exercise.name} · $metricLabel ${trainerFormatMetricValue(primaryMax)}$metricSuffix · $minutes분';
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textOnAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FooterMetric extends StatelessWidget {
  final String label;
  final String value;

  const _FooterMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.brand,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
