import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/cardio.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../widgets/app_section.dart';
import '../../widgets/status_badge.dart';

class TrainerShareBlockedMessage extends StatelessWidget {
  final String message;

  const TrainerShareBlockedMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                color: AppColors.textTertiary,
                size: 28,
              ),
              const Gap(AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainerMealsTab extends StatelessWidget {
  final List<Meal> meals;
  final bool isLoading;
  final bool canView;
  final void Function(Meal) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerMealsTab({
    super.key,
    required this.meals,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const TrainerShareBlockedMessage(
        message: '회원이 식단 기록 공유를 꺼두었습니다.',
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: meals.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.restaurant_outlined,
                  message: '최근 30일 식단 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: meals.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final meal = meals[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            meal.mealType.label,
                            AppColors.info,
                          ),
                          const Spacer(),
                          Text(
                            meal.mealDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (meal.imageUrls.isNotEmpty) ...[
                        const Gap(10),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: meal.imageUrls.length,
                            separatorBuilder: (_, __) =>
                                const Gap(AppSpacing.xs),
                            itemBuilder: (_, j) => ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                              child: Image.network(
                                meal.imageUrls[j],
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (meal.description != null) ...[
                        const Gap(AppSpacing.xs),
                        Text(meal.description!, style: AppTextStyles.bodySmall),
                      ],
                      const Gap(AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (meal.calories != null)
                            Text(
                              '${meal.calories} kcal',
                              style: AppTextStyles.caption,
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => onFeedback(meal),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  meal.hasFeedback ? '피드백 수정' : '피드백 작성',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class TrainerWorkoutsTab extends StatelessWidget {
  final List<Workout> workouts;
  final bool isLoading;
  final bool canView;
  final void Function(Workout) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerWorkoutsTab({
    super.key,
    required this.workouts,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  Color _categoryColor(WorkoutCategory c) {
    switch (c) {
      case WorkoutCategory.shoulder:
        return AppColors.trainer;
      case WorkoutCategory.chest:
        return AppColors.categoryUpper;
      case WorkoutCategory.back:
        return AppColors.categoryLower;
      case WorkoutCategory.lower:
        return AppColors.categoryCore;
      case WorkoutCategory.arms:
        return AppColors.diet;
      case WorkoutCategory.abs:
        return AppColors.workout;
      case WorkoutCategory.cardio:
        return AppColors.categoryCardio;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const TrainerShareBlockedMessage(
        message: '회원이 운동 기록 공유를 꺼두었습니다.',
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: workouts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.fitness_center_outlined,
                  message: '최근 30일 운동 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final w = workouts[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            w.category.label,
                            _categoryColor(w.category),
                          ),
                          const Spacer(),
                          Text(
                            w.workoutDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        w.exercises.map((e) => e.name).join(', '),
                        style: AppTextStyles.body,
                      ),
                      const Gap(AppSpacing.xxs),
                      Text(
                        '${w.exercises.length}종목 · ${w.totalSets}세트 · 총 볼륨 ${w.totalVolume.toStringAsFixed(0)} kg',
                        style: AppTextStyles.caption,
                      ),
                      const Gap(AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => onFeedback(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              w.hasFeedback ? '피드백 수정' : '피드백 작성',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class TrainerCardiosTab extends StatelessWidget {
  final List<Cardio> cardios;
  final bool isLoading;
  final bool canView;
  final void Function(Cardio) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerCardiosTab({
    super.key,
    required this.cardios,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const TrainerShareBlockedMessage(
        message: '회원이 운동 기록 공유를 꺼두었습니다.',
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: cardios.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.directions_run_rounded,
                  message: '최근 30일 유산소 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: cardios.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = cardios[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            c.type.label,
                            AppColors.categoryCardio,
                          ),
                          const Spacer(),
                          Text(
                            c.cardioDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Text(c.summary, style: AppTextStyles.body),
                      if (c.note != null) ...[
                        const Gap(AppSpacing.xxs),
                        Text(c.note!, style: AppTextStyles.bodySmall),
                      ],
                      const Gap(AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => onFeedback(c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              c.hasFeedback ? '피드백 수정' : '피드백 작성',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
