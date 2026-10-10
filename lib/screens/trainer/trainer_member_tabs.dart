import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/workout_timing.dart';
import '../../core/app_text_styles.dart';
import '../../models/cardio.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_section.dart';

/// 기록이 없을 때 회색 카드 (시안 Tr-Member-Empty·Tr-Member-Profile-Empty).
/// 일정 탭 빈 상태(시안 Tr-Schedule-Empty)와 같은 모양: 공용 [AppEmptyState] 카드형,
/// 40 아이콘(faint) + 10 + 17/500 글자, 안쪽 36 28.
class TrainerEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? description;
  final EdgeInsetsGeometry? margin;

  /// 검정 행동 버튼 (시안 Tr-Member-Profile-Empty '첫 기록 입력')
  final String? actionLabel;
  final VoidCallback? onAction;

  const TrainerEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.margin,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      card: true,
      illustration: Icon(icon, size: 40, color: AppColors.faint),
      artGap: 10,
      cardPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      margin:
          margin ??
          const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            0,
          ),
      message: message,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      actionVariant: AppButtonVariant.dark,
    );
  }
}

class TrainerMealsTab extends StatelessWidget {
  final List<Meal> meals;
  final bool isLoading;
  final void Function(Meal) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerMealsTab({
    super.key,
    required this.meals,
    required this.isLoading,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 이미 보이는 목록이 있으면 당겨서 새로고침하는 동안 그대로 둔다.
    if (isLoading && meals.isEmpty) return const AppLoadingView();

    return _RecordList(
      onRefresh: onRefresh,
      emptyIcon: AppIcons.meal,
      emptyMessage: '최근 30일 식단 기록이 없습니다.',
      records: [
        for (final meal in meals)
          _Record(
            date: meal.mealDate,
            title: (meal.description?.isNotEmpty ?? false)
                ? meal.description!
                : meal.mealType.label,
            meta: [
              meal.mealType.label,
              if (meal.mealTime != null && meal.mealTime!.isNotEmpty)
                meal.mealTime!,
              if (meal.calories != null) '${_number(meal.calories!)} kcal',
            ].join(' · '),
            imageUrls: meal.imageUrls,
            hasFeedback: meal.hasFeedback,
            onTap: () => onFeedback(meal),
          ),
      ],
    );
  }
}

/// 운동 탭: PT·개인 운동 모두 (회원 기록은 늘 담당 트레이너에게 공유된다).
class TrainerWorkoutsTab extends StatelessWidget {
  final List<Workout> workouts;
  final bool isLoading;

  /// 읽기 실패 문구 (목록이 비어 있을 때만 오류 카드로 보인다)
  final String? errorMessage;
  final void Function(Workout) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerWorkoutsTab({
    super.key,
    required this.workouts,
    required this.isLoading,
    required this.onFeedback,
    required this.onRefresh,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && workouts.isEmpty) return const AppLoadingView();
    if (errorMessage != null && workouts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        children: [AppErrorCard(message: errorMessage!, onRetry: onRefresh)],
      );
    }
    return _RecordList(
      onRefresh: onRefresh,
      emptyIcon: AppIcons.workout,
      emptyMessage: '최근 30일 운동 기록이 없습니다.',
      records: [
        for (final w in workouts)
          _Record(
            date: w.workoutDate,
            // 시안 TrainerMember: 'PT · 전신' / '개인 · 상체'
            title:
                '${w.workoutType == WorkoutType.pt ? 'PT' : '개인'} · ${w.category.label}',
            meta: [
              '${w.exercises.length}종목',
              '${w.totalSets}세트',
              '${_number(w.totalVolume.round())}kg',
              // 회원 개인 운동 시간 (PT 기록은 재지 않는다)
              if (w.workoutType == WorkoutType.personal)
                ?formatWorkoutDuration(w.durationSeconds),
            ].join(' · '),
            hasFeedback: w.hasFeedback,
            onTap: () => onFeedback(w),
          ),
      ],
    );
  }
}

class TrainerCardiosTab extends StatelessWidget {
  final List<Cardio> cardios;
  final bool isLoading;
  final void Function(Cardio) onFeedback;
  final Future<void> Function() onRefresh;

  const TrainerCardiosTab({
    super.key,
    required this.cardios,
    required this.isLoading,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && cardios.isEmpty) return const AppLoadingView();

    return _RecordList(
      onRefresh: onRefresh,
      emptyIcon: AppIcons.cardio,
      emptyMessage: '최근 30일 유산소 기록이 없습니다.',
      records: [
        for (final c in cardios)
          _Record(
            date: c.cardioDate,
            title: c.summary,
            meta: [
              c.type.label,
              if (c.note != null && c.note!.isNotEmpty) c.note!,
            ].join(' · '),
            hasFeedback: c.hasFeedback,
            onTap: () => onFeedback(c),
          ),
      ],
    );
  }
}

String _number(num value) => NumberFormat('#,###').format(value);

// ─────────────────────────────────────────────────────────────────────────────
// 공용: 기록 목록 (시안 TrainerMember — 좌우 20 안쪽, 68 줄 + hairline)
// ─────────────────────────────────────────────────────────────────────────────

class _Record {
  final String date;
  final String title;
  final String meta;
  final List<String> imageUrls;
  final bool hasFeedback;
  final VoidCallback onTap;

  const _Record({
    required this.date,
    required this.title,
    required this.meta,
    required this.hasFeedback,
    required this.onTap,
    this.imageUrls = const [],
  });
}

class _RecordList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyMessage;
  final List<_Record> records;

  const _RecordList({
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    // 날짜 칸은 '일 + 요일'만 보이므로, 이번 달이 아닌 기록이 하나라도 있으면
    // (모두 지난달인 경우 포함) 달마다 머리말을 둬서 어느 달인지 알 수 있게 한다.
    final thisMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final withHeaders = records.any(
      (r) => r.date.length < 7 || r.date.substring(0, 7) != thisMonth,
    );

    final children = <Widget>[];
    String? currentMonth;
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final month = record.date.length >= 7 ? record.date.substring(0, 7) : '';
      if (withHeaders && month != currentMonth) {
        currentMonth = month;
        final count = records.where((r) => r.date.startsWith(month)).length;
        final parsed = DateTime.tryParse('$month-01');
        children.add(
          AppMonthHeader(
            strong: true,
            label: parsed == null ? month : '${parsed.month}월',
            count: '$count건',
          ),
        );
      }
      children.add(
        AppEntrance.slide(
          delay: Duration(milliseconds: 80 * i.clamp(0, 6)),
          child: _RecordRow(record: record),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.ink,
      backgroundColor: AppColors.canvasCard,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: withHeaders ? 0 : 10,
          bottom: AppSpacing.xl2,
        ),
        children: records.isEmpty
            ? [
                ...children,
                TrainerEmptyState(icon: emptyIcon, message: emptyMessage),
              ]
            : children,
      ),
    );
  }
}

/// 기록 한 줄 (시안 TrainerMember): 최소 68, 왼쪽 52 폭 날짜(일 17 + 요일 12 mute),
/// 제목 15 · 보조 13 mute, 오른쪽 상태 13('피드백 전' noticeText / '보냄' mute). 누르면 피드백.
/// 사진이 있으면 아래 12 띄워 72 썸네일(반경 12, 사이 4)을 날짜 칸 오른쪽에 둔다 (시안 Tr-Member-Meals).
class _RecordRow extends StatelessWidget {
  final _Record record;

  const _RecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(record.date);
    final status = record.hasFeedback ? '보냄' : '피드백 전';
    final semantic = [
      if (parsed != null) DateFormat('M월 d일 (E)', 'ko').format(parsed),
      record.title,
      if (record.meta.isNotEmpty) record.meta,
      record.hasFeedback ? '피드백 보냄, 눌러서 수정' : '피드백 전, 눌러서 작성',
    ].join(', ');

    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: InkWell(
        onTap: record.onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed == null ? record.date : '${parsed.day}',
                          style: AppTextStyles.section.bold.natural,
                        ),
                        if (parsed != null)
                          Text(
                            DateFormat('E', 'ko').format(parsed),
                            style: AppTextStyles.captionSmall.natural,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: AppTextStyles.bodyMd.bold.natural,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (record.meta.isNotEmpty) ...[
                          const Gap(2),
                          Text(
                            record.meta,
                            style: AppTextStyles.bodySm.natural,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    status,
                    style: record.hasFeedback
                        ? AppTextStyles.bodySm.natural
                        : AppTextStyles.bodySm.bold.natural.copyWith(
                            color: AppColors.noticeText,
                          ),
                  ),
                ],
              ),
              if (record.imageUrls.isNotEmpty) ...[
                const Gap(AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: record.imageUrls.length,
                      separatorBuilder: (_, _) => const Gap(AppSpacing.xs),
                      itemBuilder: (_, j) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.iconBox),
                        child: Image.network(
                          record.imageUrls[j],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 72,
                            height: 72,
                            color: AppColors.canvasSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 인바디·정보 탭 날짜 칸 (시안 Tr-Member-Profile): [width] 폭, 'MM.DD' 15/500 위 + 'YYYY' 12 mute(위 1).
/// 'yyyy-MM-dd' 형식이 아니면 원문을 그대로 쓴다.
class TrainerDateBlock extends StatelessWidget {
  final String date;
  final double width;

  const TrainerDateBlock({super.key, required this.date, this.width = 60});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final top = parsed == null
        ? date
        : '${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top, style: AppTextStyles.bodyMd.medium.natural),
          if (parsed != null) ...[
            const Gap(1),
            Text('${parsed.year}', style: AppTextStyles.captionSmall.natural),
          ],
        ],
      ),
    );
  }
}
