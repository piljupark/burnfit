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
import '../../widgets/app_section.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/app_loader.dart';

import '../common/notice_home_banner.dart';
import 'member_pt_workout_screen.dart';
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
        _unreadFeedbackCount = allFeedbacks
            .where((item) => !item.isRead)
            .length;
        _feedbacks = allFeedbacks.where((item) {
          final targetDate = item.targetDate;
          return targetDate != null &&
              targetDate.compareTo(startKey) >= 0 &&
              targetDate.compareTo(endKey) <= 0;
        }).toList();
        final sessions = results[3] as List<PtSession>;
        _activePtSessions = sessions
            .where((item) => item.status != PtSessionStatus.cancelled)
            .toList();
        _ptSessions = sessions
            .where((item) => item.status == PtSessionStatus.scheduled)
            .toList();
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
    final records =
        _selectedWorkouts.length +
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
            padding: const EdgeInsets.only(bottom: AppSize.navClearance),
            children: [
              _HomeHeader(
                title: widget.showGreeting ? '$userName님' : '캘린더',
                showBell: widget.showGreeting,
              ),
              if (widget.showGreeting) const NoticeHomeBanner(),
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
                marks: buildCalendarMarks(
                  sessions: _activePtSessions,
                  workouts: _workouts,
                ),
                onSelect: (day) => setState(() => _selectedDay = day),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  10,
                  AppSpacing.screenH,
                  0,
                ),
                child: CalendarLegend(),
              ),
              // 달력과 그날 기록 사이: 회색 띠 (선 대신 면으로 나눈다)
              Container(
                height: AppSpacing.sm,
                margin: const EdgeInsets.only(top: AppSpacing.lg),
                color: AppColors.canvasCard,
              ),
              _DayHeader(
                label: _dayLabel(_selectedDay),
                count: _isLoading || _errorMessage != null ? null : '$records건',
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                  child: Center(child: AppLoader.screen()),
                )
              else if (_errorMessage != null)
                AppErrorCard(message: _errorMessage!, onRetry: _loadMonth)
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

/// 볼륨 표시: 11440 → `11,440`.
final _volumeFormat = NumberFormat('#,##0');

/// 홈 머리: 28 제목과 알림 종을 한 줄에 (시안 MemA-Home: 위 20, 왼쪽 20, 오른쪽 8).
class _HomeHeader extends StatelessWidget {
  final String title;
  final bool showBell;

  const _HomeHeader({required this.title, required this.showBell});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.sm,
        0,
      ),
      child: SizedBox(
        height: AppSize.touchMin,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTextStyles.displayMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (showBell) const NotificationBellButton(),
          ],
        ),
      ),
    );
  }
}

/// 월 이동: 가운데 `2026년 10월`(17/500, 폭 130) + 양옆 44 버튼 안 16 화살표(mute).
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
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MonthArrow(
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
            _MonthArrow(
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

class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MonthArrow({
    required this.icon,
    required this.label,
    required this.onTap,
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
        child: SizedBox.square(
          dimension: AppSize.touchMin,
          child: Icon(icon, size: 16, color: AppColors.mute),
        ),
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

    // 시안: 좌우 14, 위 6 / 요일 12 mute, 아래 6 / 날짜 칸 46, 줄 사이 2
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
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: 12,
                          height: 16 / 12,
                        ),
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

/// 날짜 칸 (46 높이): 32 원 + 15 숫자, 아래 4 띄우고 표시 줄(5).
/// 선택 = ink 채운 원 + canvas 500 숫자, 오늘 = ink 1px 외곽선 원, 미래 = body 색.
/// 아래 표시: CalendarMarkRow (PT 완료 ● · PT 예약 ○ · 개인운동 ●).
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

/// 선택한 날 머리말: 왼쪽 날짜(17/500), 오른쪽 끝 개수(15 mute). 위 20 · 아래 4.
class _DayHeader extends StatelessWidget {
  final String label;
  final String? count;

  const _DayHeader({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label, style: AppTextStyles.section),
            ),
          ),
          if (count != null) Text(count!, style: AppTextStyles.eyebrow),
        ],
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
      return const AppEmptyLine('이 날의 기록이 없습니다');
    }

    // 목록: 좌우 20 안쪽, 줄마다 아래 hairline
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final workout in workouts) _workoutRow(context, workout),
          for (final reservation in ptReservations)
            _reservationRow(reservation),
          for (final meal in meals) _mealRow(meal),
          for (final feedback in feedbacks) _feedbackRow(feedback),
        ],
      ),
    );
  }

  Widget _workoutRow(BuildContext context, Workout workout) {
    final detail = [
      workout.category.label,
      '${workout.totalSets}세트',
      '${_volumeFormat.format(workout.totalVolume.round())}kg',
    ].join(' · ');
    final isPt = workout.workoutType == WorkoutType.pt;
    return _RecordRow(
      icon: AppIcons.workout,
      // PT 운동 줄만 아이콘 상자를 연한 주황으로 (시안 MemA-Home-PtDay)
      highlighted: isPt,
      title: isPt ? 'PT 운동' : '개인운동',
      detail: detail,
      // PT 운동은 트레이너가 남긴 기록 화면으로 간다.
      onTap: isPt
          ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemberPtWorkoutScreen()),
            )
          : null,
    );
  }

  Widget _reservationRow(PtSession reservation) {
    return _RecordRow(
      icon: AppIcons.calendarCheck,
      title: 'PT 예약',
      detail:
          '${DateFormat('a h:mm', 'ko').format(reservation.scheduledAt)} · ${reservation.durationMinutes}분 · ${reservation.trainerName}',
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
      longText: true,
      onTap: onFeedbackTap,
    );
  }
}

/// 기록 한 줄 (시안 MemA-Home): 40 아이콘 상자 + 14 + 16/500 제목 · 13 mute 보조 줄
/// (+ 누를 수 있으면 18 화살표). 최소 68 높이, 아래 hairline. 오른쪽 태그는 두지 않는다.
/// [longText](피드백): 아이콘을 위로 붙이고 위아래 14, 본문 14 body 최대 3줄.
class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? meta;
  final bool highlighted;
  final bool longText;
  final VoidCallback? onTap;

  const _RecordRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.meta,
    this.highlighted = false,
    this.longText = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = AppIconBox(
      icon: icon,
      background: highlighted ? AppColors.noticeBg : null,
      iconColor: highlighted ? AppColors.noticeText : null,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.listTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (meta != null) ...[
              const Gap(AppSpacing.sm),
              Text(meta!, style: AppTextStyles.bodySm),
            ],
          ],
        ),
        Gap(longText ? AppSpacing.xs : 2),
        Text(
          detail,
          style: longText ? AppTextStyles.note : AppTextStyles.bodySm,
          maxLines: longText ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final chevron = Icon(
      AppIcons.chevronRightBold,
      size: 18,
      color: AppColors.chevron,
    );
    // 긴 글 줄(피드백): 아이콘은 위로 붙이고 화살표는 줄 가운데 (시안 align-self: flex-start).
    final content = longText
        ? Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(right: onTap != null ? 14 + 18 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const Gap(14),
                    Expanded(child: text),
                  ],
                ),
              ),
              if (onTap != null)
                Positioned.fill(
                  child: Align(alignment: Alignment.centerRight, child: chevron),
                ),
            ],
          )
        : Row(
            children: [
              iconBox,
              const Gap(14),
              Expanded(child: text),
              if (onTap != null) ...[const Gap(14), chevron],
            ],
          );
    final row = Container(
      constraints: BoxConstraints(minHeight: longText ? 0 : 68),
      padding: EdgeInsets.symmetric(vertical: longText ? 14 : 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: content,
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

/// 홈에서 식단 기록·트레이너 피드백으로 바로 가는 두 칸.
/// 회색 둥근 카드 하나에 담고, 가운데는 짧은 세로 구분선으로 나눈다.
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
    final radius = BorderRadius.circular(AppRadius.card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: Material(
        color: AppColors.canvasCard,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.line,
                ),
              ),
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
    final hasNew = badgeCount > 0;
    final semanticLabel = hasNew ? '$label, 새 피드백 $badgeCount개' : label;
    final countLabel = badgeCount > 99 ? '99+' : '$badgeCount';
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touchMin),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 26, color: AppColors.ink),
                    if (hasNew)
                      Positioned(
                        top: -2,
                        right: -3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.newDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasNew) ...[
                        const Gap(2),
                        Text(
                          '새 피드백 $countLabel개',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.noticeText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
