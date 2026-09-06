import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import 'workout_draft_models.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _WorkoutTypeBadges(workout: workout),
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
                child: _SavedWorkoutFooterMetric(
                  label: '총 볼륨',
                  value: '${workout.totalVolume.toStringAsFixed(0)}kg',
                ),
              ),
              Expanded(
                child: _SavedWorkoutFooterMetric(
                  label: '총 세트',
                  value: '${workout.totalSets}세트',
                ),
              ),
              Expanded(
                child: _SavedWorkoutFooterMetric(
                  label: '운동시간',
                  value: formatDuration(workout.durationSeconds),
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
    final setCount = exercise.sets.length;

    if (isCardio) {
      final metricLabel = cardioPrimaryMetricLabel(exercise.name);
      final metricSuffix = cardioPrimaryMetricSuffix(exercise.name);

      final primaryMax = exercise.sets.isEmpty
          ? 0.0
          : exercise.sets
                .map((set) => set.weight)
                .reduce((a, b) => a > b ? a : b);

      final minutes = exercise.sets.fold<int>(0, (sum, set) => sum + set.reps);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SavedBullet(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${exercise.name} · $metricLabel ${formatMetricValue(primaryMax)}$metricSuffix · $minutes분',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SavedBullet(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${exercise.name} $setCount세트',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedBullet extends StatelessWidget {
  const _SavedBullet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SavedWorkoutFooterMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SavedWorkoutFooterMetric({required this.label, required this.value});

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

class _WorkoutTypeBadges extends StatelessWidget {
  final Workout workout;

  const _WorkoutTypeBadges({required this.workout});

  @override
  Widget build(BuildContext context) {
    final labels = workout.exercises
        .map(
          (exercise) =>
              inferExerciseCategoryLabel(exercise.name, workout.category),
        )
        .toSet()
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) => _CategoryBadge(label: label)).toList(),
    );
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
        borderRadius: BorderRadius.circular(999),
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
