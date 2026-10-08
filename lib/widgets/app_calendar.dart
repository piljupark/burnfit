import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'calendar_marks.dart';

/// 홈 보기 고르기 (시안 Main '오늘 · 캘린더 · 기록', TrainerMember '운동 · 식단 · 유산소 · 정보').
/// 고른 것 = ink 채움 + canvas 글자(Bold), 나머지 = canvasSoft + body 글자.
/// 기본 40 높이 · 좌우 18 · 15 글자, [compact]는 38 · 16 · 14.
class AppViewTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool compact;
  final EdgeInsetsGeometry padding;

  const AppViewTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.compact = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
  });

  @override
  Widget build(BuildContext context) {
    final base = compact ? AppTextStyles.bodySmall : AppTextStyles.bodyMd;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const Gap(AppSpacing.sm),
            // 터치 영역 44: pill 위아래로 비어 있는 누름 자리를 둔다
            GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 3 : 2),
                child: Semantics(
                  button: true,
                  selected: i == selectedIndex,
                  child: Material(
                    color: i == selectedIndex
                        ? AppColors.ink
                        : AppColors.canvasSoft,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      splashFactory: NoSplash.splashFactory,
                      child: Container(
                        height: compact ? 38 : 40,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 18,
                        ),
                        child: Text(
                          labels[i],
                          style: i == selectedIndex
                              ? base.bold.copyWith(color: AppColors.canvas)
                              : base.copyWith(color: AppColors.body),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 월 이동: 가운데 `2026년 10월`(17/500, 폭 130) + 양옆 44 버튼 안 16 화살표(mute).
class AppMonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const AppMonthNav({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppNavArrow(
              icon: AppIcons.chevronLeftBold,
              label: '이전 달',
              onTap: onPrev,
            ),
            SizedBox(
              width: 130,
              child: Semantics(
                header: true,
                child: Text(
                  DateFormat('yyyy년 M월', 'ko').format(month),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.section,
                ),
              ),
            ),
            AppNavArrow(
              icon: AppIcons.chevronRightBold,
              label: '다음 달',
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// 월·주 이동 화살표: 터치 영역 [width]×44, 안에 [size] Bold 화살표(mute).
class AppNavArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double width;
  final double size;

  const AppNavArrow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.width = AppSize.touchMin,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppSize.touchMin / 2,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          width: width,
          height: AppSize.touchMin,
          child: Icon(icon, size: size, color: AppColors.mute),
        ),
      ),
    );
  }
}

/// 한 달 달력 (월요일 시작). 좌우 14, 요일 12 mute, 날짜 칸 46 · 줄 사이 2.
/// 날짜 아래 표시는 [buildCalendarMarks]로 계산한 [marks]를 그대로 그린다.
class AppCalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, Set<CalendarMark>> marks;
  final ValueChanged<DateTime> onSelect;

  const AppCalendarGrid({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.marks,
    required this.onSelect,
  });

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final leading = firstDay.weekday - 1;
    final cells = leading + lastDay.day;
    final totalCells = (cells / 7).ceil() * 7;
    final now = DateTime.now();
    final todayBase = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (final label in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: AppTextStyles.captionSmall.natural,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(6),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 46,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > lastDay.day) {
                return const SizedBox.shrink();
              }

              final day = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNumber,
              );
              return _DayCell(
                day: day,
                isToday: DateUtils.isSameDay(day, todayBase),
                isSelected: DateUtils.isSameDay(day, selectedDay),
                isFuture: day.isAfter(todayBase),
                marks: marks[_key(day)] ?? const {},
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 날짜 칸 (46 높이): 32 원 + 15 숫자, 아래 4 띄우고 표시 줄(5).
/// 선택 = ink 채운 원 + canvas 500 숫자, 오늘 = ink 1px 외곽선 원, 미래 = body 색.
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final Set<CalendarMark> marks;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.marks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = [
      DateFormat('M월 d일', 'ko').format(day),
      if (isToday) '오늘',
      if (marks.isNotEmpty) calendarMarksSemantics(marks),
    ].join(', ');
    final numberColor = isSelected
        ? AppColors.canvas
        : isFuture
        ? AppColors.body
        : AppColors.ink;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semantic,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.ink : Colors.transparent,
                border: !isSelected && isToday
                    ? Border.all(color: AppColors.ink)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.bodyMd.copyWith(
                  color: numberColor,
                  height: 18 / 15,
                  // 시안 MemA-Home: 고른 날 숫자 500(Medium)
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const Gap(4),
            CalendarMarkRow(marks),
          ],
        ),
      ),
    );
  }
}

/// 주간 날짜 칸 (회원 홈 이번 주 · 트레이너 홈 이번 주 · 트레이너 일정 주간 줄):
/// 요일 12 → 6 → 32 원(고른 날 ink 채움 + canvas Bold, [outlined]면 ink 1px 외곽선) → 6 → [below].
class AppWeekDay extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool outlined;

  /// 날짜 아래 자리 (표시 점, 'N건' 등). 높이는 부르는 쪽이 정한다.
  final Widget below;
  final String semanticLabel;
  final VoidCallback onTap;

  /// 요일 글자 색 (기본 mute, 기준 시안 Main은 caption)
  final Color? labelColor;

  const AppWeekDay({
    super.key,
    required this.day,
    required this.selected,
    this.outlined = false,
    required this.below,
    required this.semanticLabel,
    required this.onTap,
    this.labelColor,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final number = AppTextStyles.bodyMd.natural;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdays[day.weekday - 1],
              style: AppTextStyles.captionSmall.natural.copyWith(
                color: labelColor,
              ),
            ),
            const Gap(6),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.ink : Colors.transparent,
                border: outlined && !selected
                    ? Border.all(color: AppColors.ink)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: selected
                    ? number.bold.copyWith(color: AppColors.canvas)
                    : number.copyWith(color: AppColors.ink),
              ),
            ),
            const Gap(6),
            below,
          ],
        ),
      ),
    );
  }
}

/// 섹션 머리말용 날짜: `10월 7일 (수)`.
String appDayLabel(DateTime day) => DateFormat('M월 d일 (E)', 'ko').format(day);
