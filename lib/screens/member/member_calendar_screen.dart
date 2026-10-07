import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../models/meal.dart';
import '../../models/pt_session.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/orb_loader.dart';

import 'member_routes.dart';

class MemberCalendarScreen extends StatefulWidget {
  final bool showGreeting;

  const MemberCalendarScreen({super.key, this.showGreeting = false});

  @override
  State<MemberCalendarScreen> createState() => MemberCalendarScreenState();
}

class MemberCalendarScreenState extends State<MemberCalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  List<Workout> _workouts = [];
  /// 예약 상태 세션 (선택한 날 목록의 'PT 예약' 줄).
  List<PtSession> _ptSessions = [];

  /// 취소를 뺀 모든 세션 (캘린더 표시: 완료 = PT 완료, 예약 = PT 예약).
  List<PtSession> _activePtSessions = [];
  List<Meal> _meals = [];
  List<fb.Feedback> _feedbacks = [];
  int _unreadFeedbackCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  int _monthLoadId = 0;

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void refresh() => _loadMonth();

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final loadId = ++_monthLoadId;
    setState(() => _isLoading = true);
    try {
      final focusedMonth = _focusedMonth;
      final start = DateTime(focusedMonth.year, focusedMonth.month);
      final end = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
      final startKey = _key(start);
      final endKey = _key(end);

      final results = await Future.wait([
        WorkoutService.getWorkoutsByDateRange(
          user.centerId,
          user.uid,
          startKey,
          endKey,
        ),
        MealService.getMealsByDateRange(
          user.centerId,
          user.uid,
          startKey,
          endKey,
        ),
        FirestoreService.getFeedbacksForMember(
          user.uid,
          centerId: user.centerId,
          limit: 100,
        ).catchError((_) => <fb.Feedback>[]),
        FirestoreService.getPtSessionsByMember(
          user.uid,
          centerId: user.centerId,
          from: start,
          to: DateTime(
            focusedMonth.year,
            focusedMonth.month + 1,
            0,
            23,
            59,
            59,
          ),
        ),
      ]).timeout(const Duration(seconds: 12));

      if (!mounted || loadId != _monthLoadId) return;
      final allFeedbacks = results[2] as List<fb.Feedback>;
      setState(() {
        _workouts = results[0] as List<Workout>;
        _meals = results[1] as List<Meal>;
        _unreadFeedbackCount = allFeedbacks.where((item) => !item.isRead).length;
        _feedbacks = allFeedbacks.where((item) {
          final targetDate = item.targetDate;
          return targetDate != null &&
              targetDate.compareTo(startKey) >= 0 &&
              targetDate.compareTo(endKey) <= 0;
        }).toList();
        final sessions = results[3] as List<PtSession>;
        _activePtSessions =
            sessions.where((item) => item.status != PtSessionStatus.cancelled).toList();
        _ptSessions =
            sessions.where((item) => item.status == PtSessionStatus.scheduled).toList();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || loadId != _monthLoadId) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted && loadId == _monthLoadId) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
    _loadMonth();
  }

  List<Workout> get _selectedWorkouts {
    final key = _key(_selectedDay);
    return _workouts.where((item) => item.workoutDate == key).toList();
  }

  List<PtSession> get _selectedPtReservations {
    return _ptSessions
        .where((item) => _sameDate(item.scheduledAt, _selectedDay))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Meal> get _selectedMeals {
    final key = _key(_selectedDay);
    return _meals.where((item) => item.mealDate == key).toList();
  }

  List<fb.Feedback> get _selectedFeedbacks {
    final key = _key(_selectedDay);
    return _feedbacks.where((item) => item.targetDate == key).toList();
  }

  // 하위 화면에서 기록을 바꾸거나 피드백을 읽을 수 있으므로 돌아오면 다시 불러온다.
  Future<void> _openMealLog({DateTime? date}) async {
    await MemberRoutes.openMealLog(context, date: date);
    if (mounted) _loadMonth();
  }

  Future<void> _openFeedback() async {
    await MemberRoutes.openFeedback(context);
    if (mounted) _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final records = _selectedWorkouts.length +
        _selectedPtReservations.length +
        _selectedMeals.length +
        _selectedFeedbacks.length;
    final userName = context.watch<UserProvider>().user?.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadMonth,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (widget.showGreeting)
                AppHero(
                  title: '$userName님',
                  actions: const [NotificationBellButton()],
                )
              else
                const AppHero(title: '캘린더'),
              _RecordShortcuts(
                unreadFeedbackCount: _unreadFeedbackCount,
                onMealTap: () => _openMealLog(),
                onFeedbackTap: _openFeedback,
              ),
              _MonthHeader(
                month: _focusedMonth,
                onPrev: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              _CalendarGrid(
                focusedMonth: _focusedMonth,
                selectedDay: _selectedDay,
                marks: buildCalendarMarks(sessions: _activePtSessions, workouts: _workouts),
                onSelect: (day) => setState(() => _selectedDay = day),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
                child: CalendarLegend(),
              ),
              AppMonthHeader(
                label: _dayLabel(_selectedDay),
                count: _isLoading || _errorMessage != null
                    ? null
                    : '$records건',
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                  child: Center(child: OrbLoader.screen()),
                )
              else if (_errorMessage != null)
                AppErrorCard(
                  message: _errorMessage!,
                  onRetry: _loadMonth,
                )
              else
                _DayRecords(
                  workouts: _selectedWorkouts,
                  ptReservations: _selectedPtReservations,
                  meals: _selectedMeals,
                  feedbacks: _selectedFeedbacks,
                  onMealTap: () => _openMealLog(date: _selectedDay),
                  onFeedbackTap: _openFeedback,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션 머리말용 날짜: `10월 7일 (수)`.
String _dayLabel(DateTime day) => DateFormat('M월 d일 (E)', 'ko').format(day);

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: DateFormat('yyyy년 M월', 'ko').format(month),
              excludeSemantics: true,
              child: Text(
                DateFormat('yyyy.MM').format(month),
                style: AppTextStyles.eyebrow.copyWith(color: AppColors.ink, fontSize: 13, height: 17 / 13),
              ),
            ),
          ),
          AppIconButton(icon: AppIcons.back, label: '이전 달', onPressed: onPrev),
          AppIconButton(icon: AppIcons.forward, label: '다음 달', onPressed: onNext),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, Set<CalendarMark>> marks;
  final ValueChanged<DateTime> onSelect;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.marks,
    required this.onSelect,
  });

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    // 월요일 시작 (트레이너 캘린더·일정·식단 주간 줄·통계와 같게)
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final leading = firstDay.weekday - 1;
    final cells = leading + lastDay.day;
    final totalCells = (cells / 7).ceil() * 7;
    final now = DateTime.now();
    final todayBase = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (final label in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(label, style: AppTextStyles.bodySm.copyWith(fontSize: 12, height: 16 / 12)),
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
              mainAxisExtent: AppSize.touchMin,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > lastDay.day) {
                return const SizedBox.shrink();
              }

              final day = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
              final key = _key(day);
              return _DayCell(
                day: day,
                isToday: _sameDate(day, todayBase),
                isSelected: _sameDate(day, selectedDay),
                isFuture: day.isAfter(todayBase),
                marks: marks[key] ?? const {},
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 날짜 칸 (44 높이): 선택 = 흰 원 + onPrimary 숫자, 오늘 = 외곽선 원, 미래 = body 색.
/// 아래 표시: CalendarMarkRow (PT 완료 ● · PT 예약 ○ · 개인운동 ▬).
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
        ? AppColors.onPrimary
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
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: !isSelected && isToday ? Border.all(color: AppColors.ink) : null,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.buttonLabel.copyWith(color: numberColor, height: 18 / 14),
              ),
            ),
            const Gap(3),
            CalendarMarkRow(marks),
          ],
        ),
      ),
    );
  }
}

class _DayRecords extends StatelessWidget {
  final List<Workout> workouts;
  final List<PtSession> ptReservations;
  final List<Meal> meals;
  final List<fb.Feedback> feedbacks;
  final VoidCallback onMealTap;
  final VoidCallback onFeedbackTap;

  const _DayRecords({
    required this.workouts,
    required this.ptReservations,
    required this.meals,
    required this.feedbacks,
    required this.onMealTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty &&
        ptReservations.isEmpty &&
        meals.isEmpty &&
        feedbacks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.xl),
        child: Text('이 날의 기록이 없습니다', style: AppTextStyles.bodySm),
      );
    }

    // 화면 폭 목록: 줄마다 아래 hairline
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final workout in workouts) _workoutRow(workout),
        for (final reservation in ptReservations) _reservationRow(reservation),
        for (final meal in meals) _mealRow(meal),
        for (final feedback in feedbacks) _feedbackRow(feedback),
      ],
    );
  }

  Widget _workoutRow(Workout workout) {
    final detail = [
      workout.category.label,
      '${workout.totalSets}세트',
      '${workout.totalVolume.toStringAsFixed(0)}kg',
    ].join(' · ');
    final isPt = workout.workoutType == WorkoutType.pt;
    return _RecordRow(
      icon: AppIcons.workout,
      title: isPt ? 'PT 운동' : '개인운동',
      detail: detail,
      tag: isPt ? const AppTag('PT', strong: true) : const AppTag('개인'),
    );
  }

  Widget _reservationRow(PtSession reservation) {
    return _RecordRow(
      icon: AppIcons.calendarCheck,
      title: 'PT 예약',
      detail:
          '${DateFormat('a h:mm', 'ko').format(reservation.scheduledAt)} · ${reservation.durationMinutes}분 · ${reservation.trainerName}',
      tag: const AppTag('예약'),
    );
  }

  Widget _mealRow(Meal meal) {
    final detail = [
      if ((meal.description ?? '').trim().isNotEmpty) meal.description!.trim(),
      if (meal.calories != null) '${meal.calories}kcal',
    ].join(' · ');
    return _RecordRow(
      icon: AppIcons.meal,
      title: meal.mealType.label,
      detail: detail.isNotEmpty ? detail : '메모 없음',
      onTap: onMealTap,
    );
  }

  Widget _feedbackRow(fb.Feedback feedback) {
    return _RecordRow(
      icon: AppIcons.feedback,
      title: feedback.trainerName,
      meta: DateFormat('a h:mm', 'ko').format(feedback.createdAt),
      detail: feedback.content,
      detailMaxLines: 3,
      onTap: onFeedbackTap,
    );
  }
}

/// 기록 한 줄: 아이콘 상자 + 17 제목 + 보조 줄 + 오른쪽(태그·화살표). 아래 hairline.
/// AppActionRow와 같은 모양이지만 누를 수 없는 줄(운동·예약)도 그린다.
class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? meta;
  final Widget? tag;
  final int detailMaxLines;
  final VoidCallback? onTap;

  const _RecordRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.meta,
    this.tag,
    this.detailMaxLines = 2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconBox(icon: icon),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTextStyles.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (meta != null) ...[
                      const Gap(AppSpacing.sm),
                      Text(meta!, style: AppTextStyles.bodySm),
                    ],
                  ],
                ),
                const Gap(2),
                Text(
                  detail,
                  style: AppTextStyles.bodySm,
                  maxLines: detailMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tag != null) ...[const Gap(AppSpacing.md), tag!],
          if (onTap != null) ...[
            const Gap(AppSpacing.sm),
            const Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: row,
      ),
    );
  }
}

/// 홈에서 식단 기록·트레이너 피드백으로 바로 가는 두 칸 (화면 폭, hairline으로 나눔).
class _RecordShortcuts extends StatelessWidget {
  final int unreadFeedbackCount;
  final VoidCallback onMealTap;
  final VoidCallback onFeedbackTap;

  const _RecordShortcuts({
    required this.unreadFeedbackCount,
    required this.onMealTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ShortcutCell(
                icon: AppIcons.meal,
                label: '식단 기록',
                onTap: onMealTap,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
            Expanded(
              child: _ShortcutCell(
                icon: AppIcons.feedback,
                label: '트레이너 피드백',
                badgeCount: unreadFeedbackCount,
                onTap: onFeedbackTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _ShortcutCell({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = badgeCount > 0 ? '$label, 새 피드백 $badgeCount개' : label;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: AppSize.icon, color: AppColors.ink),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd,
                ),
              ),
              if (badgeCount > 0) ...[
                const Gap(AppSpacing.xs),
                AppTag(badgeCount > 99 ? '99+' : '$badgeCount', strong: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
