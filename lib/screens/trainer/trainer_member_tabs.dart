import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/cardio.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_section.dart';
import '../../widgets/orb_loader.dart';

/// 회원이 공유를 꺼둔 항목: 아이콘 + 안내 글 (카드 없이 캔버스 위).
class TrainerShareBlockedMessage extends StatelessWidget {
  final String message;

  const TrainerShareBlockedMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.eyeSlash, color: AppColors.mute, size: 28),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySm),
          ],
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
      return const TrainerShareBlockedMessage(message: '회원이 식단 기록 공유를 꺼두었습니다.');
    }
    if (isLoading) return const AppLoadingView();

    return _RecordList(
      onRefresh: onRefresh,
      header: '식단',
      emptyIcon: AppIcons.meal,
      emptyMessage: '최근 30일 식단 기록이 없습니다.',
      itemCount: meals.length,
      itemBuilder: (i) {
        final meal = meals[i];
        final meta = [
          meal.mealType.label,
          if (meal.mealTime != null && meal.mealTime!.isNotEmpty) meal.mealTime!,
          if (meal.calories != null) '${meal.calories} kcal',
        ].join(' · ');
        return _DatedRecordRow(
          date: meal.mealDate,
          title: (meal.description?.isNotEmpty ?? false) ? meal.description! : meal.mealType.label,
          meta: meta,
          imageUrls: meal.imageUrls,
          hasFeedback: meal.hasFeedback,
          onFeedback: () => onFeedback(meal),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const TrainerShareBlockedMessage(message: '회원이 운동 기록 공유를 꺼두었습니다.');
    }
    if (isLoading) return const AppLoadingView();

    return _RecordList(
      onRefresh: onRefresh,
      header: '운동 기록',
      emptyIcon: AppIcons.workout,
      emptyMessage: '최근 30일 운동 기록이 없습니다.',
      itemCount: workouts.length,
      itemBuilder: (i) {
        final w = workouts[i];
        return _DatedRecordRow(
          date: w.workoutDate,
          title: w.exercises.map((e) => e.name).join(', '),
          meta: '${w.category.label} · ${w.exercises.length}종목 · ${w.totalSets}세트 · 볼륨 ${w.totalVolume.toStringAsFixed(0)}kg',
          hasFeedback: w.hasFeedback,
          onFeedback: () => onFeedback(w),
        );
      },
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
      return const TrainerShareBlockedMessage(message: '회원이 운동 기록 공유를 꺼두었습니다.');
    }
    if (isLoading) return const AppLoadingView();

    return _RecordList(
      onRefresh: onRefresh,
      header: '유산소',
      emptyIcon: AppIcons.cardio,
      emptyMessage: '최근 30일 유산소 기록이 없습니다.',
      itemCount: cardios.length,
      itemBuilder: (i) {
        final c = cardios[i];
        return _DatedRecordRow(
          date: c.cardioDate,
          title: c.summary,
          meta: [c.type.label, if (c.note != null && c.note!.isNotEmpty) c.note!].join(' · '),
          hasFeedback: c.hasFeedback,
          onFeedback: () => onFeedback(c),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 공용: 화면 폭 기록 목록 (월 머리말 + hairline 행)
// ─────────────────────────────────────────────────────────────────────────────

class _RecordList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String header;
  final IconData emptyIcon;
  final String emptyMessage;
  final int itemCount;
  final Widget Function(int) itemBuilder;

  const _RecordList({
    required this.onRefresh,
    required this.header,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.ink,
      backgroundColor: AppColors.canvasCard,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
        children: [
          if (itemCount == 0)
            AppEmptyState(icon: emptyIcon, message: emptyMessage)
          else ...[
            AppMonthHeader(label: header, count: '$itemCount건 · 최근 30일'),
            for (var i = 0; i < itemCount; i++) itemBuilder(i),
          ],
        ],
      ),
    );
  }
}

/// 모노 날짜 칸(MM.DD / YYYY) + 주 텍스트(17) + 메타(13) + 피드백 버튼. 아래 hairline.
class _DatedRecordRow extends StatelessWidget {
  final String date;
  final String title;
  final String meta;
  final List<String> imageUrls;
  final bool hasFeedback;
  final VoidCallback onFeedback;

  const _DatedRecordRow({
    required this.date,
    required this.title,
    required this.meta,
    required this.hasFeedback,
    required this.onFeedback,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TrainerDateBlock(date: date),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.bodyLg, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (meta.isNotEmpty)
                          Text(meta, style: AppTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: hasFeedback ? '피드백 수정' : '피드백 작성',
                    variant: hasFeedback ? AppButtonVariant.ghost : AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: onFeedback,
                  ),
                ],
              ),
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(left: 48 + AppSpacing.md),
                  child: SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xxs),
                      itemBuilder: (_, j) => Image.network(
                        imageUrls[j],
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: AppColors.canvasSoft),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const AppRowDivider(),
      ],
    );
  }
}

/// 48 폭 모노 날짜 칸: 'MM.DD' (ink) 위, 'YYYY' (mute) 아래.
/// 'yyyy-MM-dd' 형식이 아니면 원문을 그대로 쓴다.
class TrainerDateBlock extends StatelessWidget {
  final String date;

  const TrainerDateBlock({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final top = parsed == null
        ? date
        : '${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
    return SizedBox(
      width: 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top, style: AppTextStyles.counter.copyWith(fontSize: 13, height: 17 / 13, color: AppColors.ink)),
          if (parsed != null) Text('${parsed.year}', style: AppTextStyles.counter),
        ],
      ),
    );
  }
}
