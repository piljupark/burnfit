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
import '../../models/pt_info.dart';
import '../../models/pt_session.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/brand_marks.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/rest_timer.dart';

import '../common/notice_home_banner.dart';
import 'member_profile_detail_screen.dart';
import 'member_pt_workout_screen.dart';
import 'member_routes.dart';
import 'member_workout_stats_screen.dart';
import 'nutrition_guide_screen.dart';

/// 홈에서 고르는 보기 (시안 Main: 오늘 · 캘린더 · 기록).
enum _HomeView {
  today('오늘'),
  calendar('캘린더'),
  records('기록');

  final String label;

  const _HomeView(this.label);
}

/// 회원 홈 (시안 Main.html).
/// - 오늘: PT 잔여 막대 → 바로가기 8칸 → 이번 주 운동 줄 → 오늘 일정
/// - 캘린더: 한 달 달력 + 고른 날 기록
/// - 기록: 이번 달 기록을 날짜별로
class MemberCalendarScreen extends StatefulWidget {
  /// 운동 탭으로 옮긴다 (바로가기 '운동 기록').
  final VoidCallback? onOpenWorkout;

  /// PT 탭으로 옮긴다 (PT 막대 '예약', 바로가기 'PT 일정', 오늘 일정 줄).
  final VoidCallback? onOpenPt;

  const MemberCalendarScreen({super.key, this.onOpenWorkout, this.onOpenPt});

  @override
  State<MemberCalendarScreen> createState() => MemberCalendarScreenState();
}

class MemberCalendarScreenState extends State<MemberCalendarScreen> {
  _HomeView _view = _HomeView.today;
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

  // ── 오늘 보기 (달과 관계없이 오늘 기준) ──
  PtInfo? _ptInfo;

  /// 연속 운동 일수 계산용: 오늘부터 40일 전까지의 운동.
  List<Workout> _recentWorkouts = [];

  /// 이번 주(월~일) 세션 (취소 제외).
  List<PtSession> _weekSessions = [];

  /// 오늘 보기의 운동·세션 조회가 실패했는지 (주간 줄 표시가 조용히 비지 않게 오류를 보인다).
  bool _todayFailed = false;

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void refresh() {
    _loadMonth();
    _loadToday();
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> _refreshAll() => Future.wait([_loadMonth(), _loadToday()]);

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

  /// 오늘 보기: PT 잔여, 연속 운동(40일), 이번 주 세션. 실패하면 해당 칸만 비운다.
  Future<void> _loadToday() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final today = _today();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    var failed = false;
    final results = await Future.wait<Object?>([
      FirestoreService.getPtInfo(
        user.uid,
        centerId: user.centerId,
      ).catchError((_) => null),
      WorkoutService.getWorkoutsByDateRange(
        user.centerId,
        user.uid,
        _key(today.subtract(const Duration(days: 40))),
        _key(weekEnd),
      ).catchError((_) {
        failed = true;
        return <Workout>[];
      }),
      FirestoreService.getPtSessionsByMember(
        user.uid,
        centerId: user.centerId,
        from: weekStart,
        to: DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
      ).catchError((_) {
        failed = true;
        return <PtSession>[];
      }),
    ]);
    if (!mounted) return;
    setState(() {
      _todayFailed = failed;
      _ptInfo = results[0] as PtInfo?;
      _recentWorkouts = results[1] as List<Workout>;
      _weekSessions = (results[2] as List<PtSession>)
          .where((item) => item.status != PtSessionStatus.cancelled)
          .toList();
    });
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
    _loadMonth();
  }

  /// 주간 줄에서 날짜를 누르면 캘린더 보기로 그날을 연다.
  void _openDay(DateTime day) {
    final month = DateTime(day.year, day.month);
    final monthChanged = month != _focusedMonth;
    setState(() {
      _view = _HomeView.calendar;
      _focusedMonth = month;
      _selectedDay = day;
    });
    if (monthChanged) _loadMonth();
  }

  List<Workout> _workoutsOn(String key) =>
      _workouts.where((item) => item.workoutDate == key).toList();

  List<PtSession> _reservationsOn(DateTime day) =>
      _ptSessions.where((item) => _sameDate(item.scheduledAt, day)).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<Meal> _mealsOn(String key) =>
      _meals.where((item) => item.mealDate == key).toList();

  List<fb.Feedback> _feedbacksOn(String key) =>
      _feedbacks.where((item) => item.targetDate == key).toList();

  int _recordCount(DateTime day) {
    final key = _key(day);
    return _workoutsOn(key).length +
        _reservationsOn(day).length +
        _mealsOn(key).length +
        _feedbacksOn(key).length;
  }

  /// 오늘(또는 오늘 아직 안 했으면 어제)부터 거꾸로 운동한 날이 이어진 일수.
  int get _streakDays {
    final days = _recentWorkouts.map((w) => w.workoutDate).toSet();
    var day = _today();
    if (!days.contains(_key(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(_key(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// 이번 주 날짜별 표시 하나 (PT 완료 > PT 예약 > 개인운동 순으로 하나만).
  /// 오늘에 PT가 있으면(예약·완료) 시안 Main처럼 주황 채운 점으로 보인다 (맥박은 [_WeekCard]).
  Map<String, CalendarMark> get _weekMarks {
    final all = buildCalendarMarks(
      sessions: _weekSessions,
      workouts: _recentWorkouts,
    );
    final marks = <String, CalendarMark>{
      for (final entry in all.entries)
        if (primaryCalendarMark(entry.value) case final mark?) entry.key: mark,
    };
    if (_todayHasPt) marks[_key(_today())] = CalendarMark.ptDone;
    return marks;
  }

  /// 오늘에 취소되지 않은 PT(세션 또는 PT 운동 기록)가 있는지.
  bool get _todayHasPt {
    final today = _today();
    final todayKey = _key(today);
    return _weekSessions.any((item) => _sameDate(item.scheduledAt, today)) ||
        _recentWorkouts.any(
          (w) => w.workoutDate == todayKey && w.workoutType == WorkoutType.pt,
        );
  }

  // 하위 화면에서 기록을 바꾸거나 피드백을 읽을 수 있으므로 돌아오면 다시 불러온다.
  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) refresh();
  }

  Future<void> _openMealLog({DateTime? date}) async {
    await MemberRoutes.openMealLog(context, date: date);
    if (mounted) refresh();
  }

  Future<void> _openFeedback() async {
    await MemberRoutes.openFeedback(context);
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSize.navClearance),
            children: [
              const AppHero(title: '홈', actions: [NotificationBellButton()]),
              _ViewTabs(
                selected: _view,
                onSelect: (view) => setState(() => _view = view),
              ),
              // 오늘 보기(시안 Main)에는 공지 줄이 없다. 중요 공지 시트는 어느 보기에서든 뜬다.
              // 같은 자리에 두어 보기를 바꿔도 공지를 다시 불러오지 않는다.
              NoticeHomeBanner(showBanner: _view != _HomeView.today),
              ...switch (_view) {
                _HomeView.today => _todayChildren(),
                _HomeView.calendar => _calendarChildren(),
                _HomeView.records => _recordsChildren(),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _todayChildren() {
    final today = _today();
    final todaySessions =
        _weekSessions
            .where((item) => _sameDate(item.scheduledAt, today))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final ptInfo = _ptInfo;
    return [
      if (ptInfo != null)
        _PtBar(
          remaining: ptInfo.remainingSessions,
          onReserve: widget.onOpenPt,
          onSchedule: () => setState(() => _view = _HomeView.calendar),
        ),
      _ShortcutGrid(
        items: [
          _Shortcut(
            const _LineGlyph(_Glyph.barbell),
            '운동 기록',
            widget.onOpenWorkout,
          ),
          _Shortcut(_icon(AppIcons.meal), '식단', () => _openMealLog()),
          _Shortcut(
            _icon(AppIcons.feedback),
            '피드백',
            _openFeedback,
            showDot: _unreadFeedbackCount > 0,
          ),
          _Shortcut(
            const _LineGlyph(_Glyph.nutrition),
            '영양 가이드',
            () => _push(const NutritionGuideScreen()),
          ),
          _Shortcut(_icon(AppIcons.calendarCheck), 'PT 일정', widget.onOpenPt),
          _Shortcut(
            const _LineGlyph(_Glyph.stats),
            '운동 통계',
            () => _push(const MemberWorkoutStatsScreen()),
          ),
          _Shortcut(
            const _LineGlyph(_Glyph.inbody),
            '인바디',
            () => _push(const MemberProfileDetailScreen()),
          ),
          _Shortcut(
            _icon(AppIcons.clock),
            '휴식 타이머',
            () => showRestTimerSheet(context),
          ),
        ],
      ),
      _WeekCard(
        today: today,
        streakDays: _streakDays,
        marks: _weekMarks,
        pulseToday: _todayHasPt,
        onSelect: _openDay,
      ),
      if (_todayFailed)
        AppErrorCard(
          message: '이번 주 기록을 불러오지 못했습니다',
          onRetry: () => _loadToday(),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          22,
          AppSpacing.screenH,
          0,
        ),
        child: Semantics(
          header: true,
          child: Text('오늘', style: AppTextStyles.section.bold.natural),
        ),
      ),
      if (todaySessions.isEmpty)
        const AppEmptyLine('오늘 예정된 일정이 없습니다')
      else
        for (final session in todaySessions)
          _TodaySessionRow(session: session, onTap: widget.onOpenPt),
    ];
  }

  List<Widget> _calendarChildren() {
    return [
      _MonthHeader(
        month: _focusedMonth,
        onPrev: () => _moveMonth(-1),
        onNext: () => _moveMonth(1),
      ),
      // 조회 실패: 달력 표시가 조용히 비지 않게 달력 바로 위에 알린다.
      if (_errorMessage != null)
        AppErrorCard(message: _errorMessage!, onRetry: _loadMonth),
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
        count: _isLoading || _errorMessage != null
            ? null
            : '${_recordCount(_selectedDay)}건',
      ),
      ..._dayBody(_selectedDay, showError: false),
    ];
  }

  /// 기록 보기: 고른 달에서 오늘까지, 기록이 있는 날을 최근 날부터 (앞으로의 예약은 빼고).
  List<Widget> _recordsChildren() {
    final header = _MonthHeader(
      month: _focusedMonth,
      onPrev: () => _moveMonth(-1),
      onNext: () => _moveMonth(1),
    );
    if (_isLoading || _errorMessage != null) {
      return [header, ..._dayBody(_selectedDay)];
    }
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final days = [
      for (var d = lastDay.day; d >= 1; d--)
        DateTime(_focusedMonth.year, _focusedMonth.month, d),
    ].where((day) => !day.isAfter(_today()) && _recordCount(day) > 0).toList();
    return [
      header,
      if (days.isEmpty)
        const AppEmptyLine('이 달의 기록이 없습니다')
      else
        for (final day in days) ...[
          _DayHeader(label: _dayLabel(day), count: '${_recordCount(day)}건'),
          ..._dayBody(day),
        ],
    ];
  }

  /// 하루 기록 목록 (불러오는 중·오류 포함). [showError]가 false면 오류는 다른 자리에서 보인다.
  List<Widget> _dayBody(DateTime day, {bool showError = true}) {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
          child: Center(child: AppLoader.screen()),
        ),
      ];
    }
    if (_errorMessage != null) {
      return [
        if (showError)
          AppErrorCard(message: _errorMessage!, onRetry: _loadMonth),
      ];
    }
    final key = _key(day);
    return [
      _DayRecords(
        // 날을 바꾸면 줄이 다시 밀려 들어오게 (시안 `slide`)
        key: ValueKey(key),
        workouts: _workoutsOn(key),
        ptReservations: _reservationsOn(day),
        meals: _mealsOn(key),
        feedbacks: _feedbacksOn(key),
        onMealTap: () => _openMealLog(date: day),
        onFeedbackTap: _openFeedback,
      ),
    ];
  }
}

/// 섹션 머리말용 날짜: `10월 7일 (수)`.
String _dayLabel(DateTime day) => DateFormat('M월 d일 (E)', 'ko').format(day);

/// 볼륨 표시: 11440 → `11,440`.
final _volumeFormat = NumberFormat('#,##0');

/// 바로가기 아이콘 (Phosphor Regular 30 — 선 1.875로 시안 선 1.5 × 30/24와 같다).
Widget _icon(IconData icon) => Icon(icon, size: 30, color: AppColors.ink);

/// 시안 Main 바로가기 중 Phosphor와 모양이 크게 다른 아이콘.
enum _Glyph { barbell, nutrition, stats, inbody }

/// 시안 SVG 경로(viewBox 24, 선 1.5, 둥근 끝)를 30 크기로 그린 선 아이콘.
class _LineGlyph extends StatelessWidget {
  final _Glyph glyph;

  const _LineGlyph(this.glyph);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(30),
      painter: _LineGlyphPainter(glyph, AppColors.ink),
    );
  }
}

class _LineGlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;

  const _LineGlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

    switch (glyph) {
      // M6.5 6.5v11 M17.5 6.5v11 M3 9.5v5 M21 9.5v5 M6.5 12h11
      case _Glyph.barbell:
        line(6.5, 6.5, 6.5, 17.5);
        line(17.5, 6.5, 17.5, 17.5);
        line(3, 9.5, 3, 14.5);
        line(21, 9.5, 21, 14.5);
        line(6.5, 12, 17.5, 12);
      // M12 3a4 4 0 0 0-4 4c0 3 4 5 4 5s4-2 4-5a4 4 0 0 0-4-4Z
      // M5 21c1-4 4-6 7-6s6 2 7 6
      case _Glyph.nutrition:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..arcToPoint(
              const Offset(8, 7),
              radius: const Radius.circular(4),
              clockwise: false,
            )
            ..cubicTo(8, 10, 12, 12, 12, 12)
            ..cubicTo(12, 12, 16, 10, 16, 7)
            ..arcToPoint(
              const Offset(12, 3),
              radius: const Radius.circular(4),
              clockwise: false,
            )
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 21)
            ..cubicTo(6, 17, 9, 15, 12, 15)
            ..cubicTo(15, 15, 18, 17, 19, 21),
          paint,
        );
      // M4 20V10 M10 20V4 M16 20v-7 M22 20H2
      case _Glyph.stats:
        line(4, 20, 4, 10);
        line(10, 20, 10, 4);
        line(16, 20, 16, 13);
        line(22, 20, 2, 20);
      // rect 5,3 14×18 rx3 · M9 8h6 M9 12h6 M9 16h3
      case _Glyph.inbody:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3, 14, 18),
            const Radius.circular(3),
          ),
          paint,
        );
        line(9, 8, 15, 8);
        line(9, 12, 15, 12);
        line(9, 16, 12, 16);
    }
  }

  @override
  bool shouldRepaint(_LineGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// 오늘 · 캘린더 · 기록 고르기: 40 높이 pill, 고른 것 = ink 채움 + 흰 15/700.
class _ViewTabs extends StatelessWidget {
  final _HomeView selected;
  final ValueChanged<_HomeView> onSelect;

  const _ViewTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 탭 제목(AppHero) 아래 16은 제목이 둔다
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          for (final view in _HomeView.values) ...[
            if (view != _HomeView.values.first) const Gap(AppSpacing.sm),
            Semantics(
              button: true,
              selected: view == selected,
              child: Material(
                color: view == selected ? AppColors.ink : AppColors.canvasSoft,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelect(view),
                  splashFactory: NoSplash.splashFactory,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      view.label,
                      style: view == selected
                          ? AppTextStyles.bodyMd.bold.copyWith(
                              color: AppColors.canvas,
                            )
                          : AppTextStyles.bodyMd.copyWith(
                              color: AppColors.body,
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

/// PT 잔여 막대: 64 높이 주황(반경 18), 왼쪽 'PT N회 남음', 오른쪽 '예약 | 일정'.
class _PtBar extends StatelessWidget {
  final int remaining;
  final VoidCallback? onReserve;
  final VoidCallback onSchedule;

  const _PtBar({
    required this.remaining,
    required this.onReserve,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onPrimary;
    final strong = AppTextStyles.section.bold.natural.copyWith(color: fg);
    final action = AppTextStyles.bodyMd.bold.natural.copyWith(color: fg);
    Widget link(String label, String semantic, VoidCallback? onTap) {
      return Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(label, style: action),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      height: 64,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, 13, 0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'PT $remaining회 남음',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('PT', style: strong),
                  const Gap(6),
                  Text('$remaining회 남음', style: strong),
                ],
              ),
            ),
          ),
          link('예약', 'PT 예약 보기', onReserve),
          Container(width: 1, height: 14, color: fg.withValues(alpha: 0.2)),
          link('일정', 'PT 일정 달력 보기', onSchedule),
        ],
      ),
    );
  }
}

class _Shortcut {
  /// 30 크기 아이콘 ([_icon] 또는 [_LineGlyph]).
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  /// 아이콘 오른쪽 위 새 소식 점 (피드백에 읽지 않은 글이 있을 때)
  final bool showDot;

  const _Shortcut(this.icon, this.label, this.onTap, {this.showDot = false});
}

/// 바로가기 8칸: 회색 카드(반경 20) 안 4열 × 2줄, 아이콘 30 + 13 글자.
/// 새 소식이 있는 칸([_Shortcut.showDot])은 아이콘 오른쪽 위에 newDot.
class _ShortcutGrid extends StatelessWidget {
  final List<_Shortcut> items;

  const _ShortcutGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    Widget cell(_Shortcut item) {
      final showDot = item.showDot;
      return Expanded(
        child: Semantics(
          button: true,
          label: showDot ? '${item.label}, 새 소식 있음' : item.label,
          excludeSemantics: true,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(AppRadius.field),
            highlightColor: AppColors.canvasSoft,
            splashFactory: NoSplash.splashFactory,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox.square(dimension: 30, child: item.icon),
                    if (showDot)
                      // 새 소식 점: 아이콘 오른쪽 위, 숨 쉬듯 커졌다 작아짐 (시안 MemA-Home `pulse`)
                      Positioned(
                        top: -2,
                        right: -3,
                        child: AppPulse(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.newDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Gap(AppSpacing.sm),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.natural.copyWith(
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 22, AppSpacing.sm, 14),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (var row = 0; row * 4 < items.length; row++) ...[
            if (row > 0) const Gap(18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items.skip(row * 4).take(4)) cell(item),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 이번 주 운동 카드: 불꽃 + 'N일째 운동 중' / 'M월 둘째 주', 아래 월~일 7칸.
/// 칸마다 요일 12 · 날짜 32 원(오늘 = ink 채움) · 표시 점 6 하나.
class _WeekCard extends StatelessWidget {
  final DateTime today;
  final int streakDays;
  final Map<String, CalendarMark> marks;

  /// 오늘에 PT가 있어 오늘 점이 숨 쉬듯 커졌다 작아진다 (시안 Main `dotpulse`).
  final bool pulseToday;
  final ValueChanged<DateTime> onSelect;

  const _WeekCard({
    required this.today,
    required this.streakDays,
    required this.marks,
    required this.pulseToday,
    required this.onSelect,
  });

  static const _ordinals = ['첫째', '둘째', '셋째', '넷째', '다섯째', '여섯째'];

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final firstOffset = DateTime(today.year, today.month).weekday - 1;
    final weekOfMonth = (today.day + firstOffset - 1) ~/ 7;
    // 시안 Main 캡션: 13 #767676, 줄 높이 normal
    final caption = AppTextStyles.bodySm.natural.copyWith(
      color: AppColors.caption,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const ExcludeSemantics(child: FlameIcon(height: 26)),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Text(
                  streakDays > 0 ? '$streakDays일째 운동 중' : '이번 주 운동',
                  style: AppTextStyles.listTitle.bold.natural,
                ),
              ),
              Text(
                '${today.month}월 ${_ordinals[weekOfMonth]} 주',
                style: caption,
              ),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _weekDay(
                    weekStart.add(Duration(days: i)),
                    weekdays[i],
                    caption,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekDay(DateTime day, String weekday, TextStyle caption) {
    final isToday = _sameDate(day, today);
    final mark = marks[DateFormat('yyyy-MM-dd').format(day)];
    return Semantics(
      button: true,
      label: [
        DateFormat('M월 d일', 'ko').format(day),
        if (isToday) '오늘',
        if (mark != null) mark.label,
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelect(day),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              weekday,
              style: caption.copyWith(fontSize: 12, letterSpacing: 12 * -0.019),
            ),
            const Gap(6),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? AppColors.ink : Colors.transparent,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.bodyMd.natural.copyWith(
                  color: isToday ? AppColors.canvas : AppColors.ink,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const Gap(6),
            SizedBox.square(
              dimension: 6,
              child: mark == null
                  ? null
                  : isToday && pulseToday
                  ? AppPulse(child: CalendarMarkIcon(mark, size: 6))
                  : CalendarMarkIcon(mark, size: 6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘 일정 한 줄: 왼쪽 44 폭 시각(15/700) + 'PT'(15/700) · 트레이너 · 분 + 화살표.
class _TodaySessionRow extends StatelessWidget {
  final PtSession session;
  final VoidCallback? onTap;

  const _TodaySessionRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 시안 Main: 15/500(Bold 글꼴), 보조 13 #767676, 줄 높이 normal
    final strong = AppTextStyles.bodyMd.bold.natural;
    final done = session.status == PtSessionStatus.completed;
    final detail = [
      session.trainerName,
      '${session.durationMinutes}분',
      if (done) '완료',
    ].join(' · ');
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: 14,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  DateFormat('HH:mm').format(session.scheduledAt),
                  style: strong,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PT', style: strong),
                    const Gap(2),
                    Text(
                      detail,
                      style: AppTextStyles.bodySm.natural.copyWith(
                        color: AppColors.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  AppIcons.chevronRightBold,
                  size: 18,
                  color: AppColors.chevron,
                ),
            ],
          ),
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
                        style: AppTextStyles.bodySm.natural.copyWith(
                          fontSize: 12,
                          letterSpacing: 12 * -0.019,
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
    super.key,
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

    final rows = [
      for (final workout in workouts) _workoutRow(context, workout),
      for (final reservation in ptReservations) _reservationRow(reservation),
      for (final meal in meals) _mealRow(meal),
      for (final feedback in feedbacks) _feedbackRow(feedback),
    ];
    // 목록: 좌우 20 안쪽, 줄마다 아래 hairline.
    // 줄은 왼쪽에서 차례로 밀려 들어온다 (시안 `slide` .4s, 줄마다 .06s 늦게).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            AppEntrance.slide(
              delay: Duration(milliseconds: 60 * i),
              child: rows[i],
            ),
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
          // 피드백 본문은 시안대로 줄 수를 자르지 않는다.
          maxLines: longText ? null : 2,
          overflow: longText ? null : TextOverflow.ellipsis,
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
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: chevron,
                  ),
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

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
