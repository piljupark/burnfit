import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/pt_session.dart';
import '../models/workout.dart';

/// 캘린더 날짜 아래 표시.
/// - PT 완료: 주황 채운 점 ●
/// - PT 예약: 주황 빈 원 ○
/// - 개인운동: 검정 짧은 막대 ▬
enum CalendarMark {
  ptDone('PT 완료'),
  ptScheduled('PT 예약'),
  personal('개인운동');

  final String label;

  const CalendarMark(this.label);
}

final _dateKey = DateFormat('yyyy-MM-dd');

/// 날짜(yyyy-MM-dd)별 표시 — 회원·트레이너 캘린더가 같은 규칙을 쓴다.
/// - PT 완료: PT 운동 기록이 있거나 완료 처리된 세션이 있는 날
/// - PT 예약: 예약 상태 세션이 있는 날 (같은 날 완료 세션이 있어도 따로 표시)
/// - 개인운동: 개인 운동 기록이 있는 날
/// 취소된 세션은 표시하지 않는다.
Map<String, Set<CalendarMark>> buildCalendarMarks({
  required Iterable<PtSession> sessions,
  required Iterable<Workout> workouts,
}) {
  final marks = <String, Set<CalendarMark>>{};
  void add(String key, CalendarMark mark) =>
      marks.putIfAbsent(key, () => {}).add(mark);

  for (final session in sessions) {
    final key = _dateKey.format(session.scheduledAt);
    switch (session.status) {
      case PtSessionStatus.completed:
        add(key, CalendarMark.ptDone);
      case PtSessionStatus.scheduled:
        add(key, CalendarMark.ptScheduled);
      case PtSessionStatus.cancelled:
        break;
    }
  }
  for (final workout in workouts) {
    add(
      workout.workoutDate,
      workout.workoutType == WorkoutType.pt
          ? CalendarMark.ptDone
          : CalendarMark.personal,
    );
  }
  return marks;
}

/// 표시 하나 (높이 5).
class CalendarMarkIcon extends StatelessWidget {
  final CalendarMark mark;

  const CalendarMarkIcon(this.mark, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (mark) {
      case CalendarMark.ptDone:
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        );
      case CalendarMark.ptScheduled:
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary),
          ),
        );
      case CalendarMark.personal:
        return Container(
          width: 8,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
    }
  }
}

/// 날짜 칸 아래 표시 줄 (정해진 순서: PT 완료 → PT 예약 → 개인운동).
class CalendarMarkRow extends StatelessWidget {
  final Set<CalendarMark> marks;

  const CalendarMarkRow(this.marks, {super.key});

  @override
  Widget build(BuildContext context) {
    final ordered = CalendarMark.values.where(marks.contains).toList();
    return SizedBox(
      height: 5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            CalendarMarkIcon(ordered[i]),
          ],
        ],
      ),
    );
  }
}

/// 스크린리더용 문구: "PT 완료, 개인운동".
String calendarMarksSemantics(Set<CalendarMark> marks) =>
    CalendarMark.values.where(marks.contains).map((m) => m.label).join(', ');

/// 범례: ● PT 완료 · ○ PT 예약 · ▬ 개인운동
class CalendarLegend extends StatelessWidget {
  final MainAxisAlignment alignment;

  const CalendarLegend({super.key, this.alignment = MainAxisAlignment.end});

  @override
  Widget build(BuildContext context) {
    final caption = AppTextStyles.bodySm.copyWith(
      fontSize: 12,
      height: 16 / 12,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          for (final mark in CalendarMark.values) ...[
            if (mark != CalendarMark.values.first)
              const SizedBox(width: AppSpacing.base),
            SizedBox(width: 8, child: Center(child: CalendarMarkIcon(mark))),
            const SizedBox(width: 6),
            Text(mark.label, style: caption),
          ],
        ],
      ),
    );
  }
}
