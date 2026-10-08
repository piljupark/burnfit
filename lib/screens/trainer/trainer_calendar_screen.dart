import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/app_section.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/notification_bell_button.dart';
import '../common/notice_home_banner.dart';
import 'trainer_member_detail_screen.dart';
import 'trainer_pt_workout_screen.dart';

/// 홈에서 고르는 보기 (회원 홈과 같은 고르기).
enum _HomeView {
  today('오늘'),
  calendar('캘린더');

  final String label;

  const _HomeView(this.label);
}

/// 트레이너 홈.
/// - 오늘 (기준 시안 TrainerHome): 오늘 PT 주황 카드 → 이번 주 줄 → 오늘 PT 목록 → 혼자 운동한 회원
/// - 캘린더 (상세 시안 Tr-Home): 한 달 달력 + 고른 날 PT · 개인운동
class TrainerCalendarScreen extends StatefulWidget {
  const TrainerCalendarScreen({super.key});

  @override
  State<TrainerCalendarScreen> createState() => TrainerCalendarScreenState();
}

class TrainerCalendarScreenState extends State<TrainerCalendarScreen> {
  _HomeView _view = _HomeView.today;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  List<AppUser> _members = [];
  List<Workout> _workouts = [];
  List<PtSession> _ptSessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadId = 0;

  /// 오늘 보기: 이번 주(월~일) PT와 오늘 개인운동.
  List<PtSession> _weekSessions = [];
  List<Workout> _todayWorkouts = [];
  bool _todayLoading = false;
  bool _todayFailed = false;
  int _todayLoadId = 0;

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _weekStart(DateTime day) =>
      day.subtract(Duration(days: day.weekday - 1));

  void refresh() {
    _loadMonth();
    _loadToday();
  }

  Future<void> _refreshAll() => Future.wait([_loadMonth(), _loadToday()]);

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 담당 회원들의 [start]~[end] 운동 기록. 운동 공유를 끈 회원은 규칙이 조회를 막는다 →
  /// 그 회원만 빼고 나머지는 보여준다.
  static Future<List<Workout>> _memberWorkouts(
    String centerId,
    List<AppUser> members,
    String start,
    String end,
  ) async {
    final lists = await Future.wait(
      members.map(
        (m) => WorkoutService.getWorkoutsByDateRange(
          centerId,
          m.uid,
          start,
          end,
        ).catchError((_) => <Workout>[]),
      ),
    );
    return lists.expand((l) => l).toList();
  }

  Future<void> _loadMonth() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final loadId = ++_loadId;
    setState(() => _isLoading = true);

    try {
      final focusedMonth = _focusedMonth;
      final start = DateTime(focusedMonth.year, focusedMonth.month);
      final end = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);

      final members = await FirestoreService.getMembersByTrainer(
        user.centerId,
        user.uid,
      );

      if (!mounted || loadId != _loadId) return;

      final results = await Future.wait([
        _memberWorkouts(user.centerId, members, _key(start), _key(end)),
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: start,
          to: DateTime(end.year, end.month, end.day, 23, 59, 59),
        ),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted || loadId != _loadId) return;

      setState(() {
        _members = members;
        _workouts = results[0] as List<Workout>;
        _ptSessions = (results[1] as List<PtSession>)
            .where((s) => s.status != PtSessionStatus.cancelled)
            .toList();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted && loadId == _loadId) setState(() => _isLoading = false);
    }
  }

  /// 오늘 보기 데이터: 이번 주 PT(주 칸 개수·오늘 목록)와 오늘 개인운동(혼자 운동한 회원).
  /// 달력이 다른 달을 보고 있어도 오늘 보기는 늘 이번 주를 보여 주므로 따로 불러온다.
  Future<void> _loadToday() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final loadId = ++_todayLoadId;
    setState(() => _todayLoading = true);

    try {
      final today = _today();
      final weekStart = _weekStart(today);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final members = await FirestoreService.getMembersByTrainer(
        user.centerId,
        user.uid,
      );
      if (!mounted || loadId != _todayLoadId) return;

      final results = await Future.wait([
        _memberWorkouts(user.centerId, members, _key(today), _key(today)),
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: weekStart,
          to: DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
        ),
      ]).timeout(const Duration(seconds: 15));
      if (!mounted || loadId != _todayLoadId) return;

      setState(() {
        _members = members;
        _todayWorkouts = (results[0] as List<Workout>)
            .where((w) => w.workoutType == WorkoutType.personal)
            .toList();
        _weekSessions = (results[1] as List<PtSession>)
            .where((s) => s.status != PtSessionStatus.cancelled)
            .toList();
        _todayFailed = false;
      });
    } catch (_) {
      if (!mounted || loadId != _todayLoadId) return;
      setState(() => _todayFailed = true);
    } finally {
      if (mounted && loadId == _todayLoadId) {
        setState(() => _todayLoading = false);
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

  /// 이번 주 줄에서 날을 누르면 캘린더 보기에서 그날을 연다.
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

  List<Workout> _personalWorkoutsOn(DateTime day) {
    final key = _key(day);
    return _workouts
        .where(
          (w) => w.workoutDate == key && w.workoutType == WorkoutType.personal,
        )
        .toList();
  }

  List<PtSession> _sessionsOn(List<PtSession> sessions, DateTime day) =>
      sessions.where((s) => DateUtils.isSameDay(s.scheduledAt, day)).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  Future<void> _openPt(PtSession session) async {
    final member = _members.where((m) => m.uid == session.memberId).firstOrNull;
    if (member == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrainerPtWorkoutScreen(session: session, member: member),
      ),
    );
    if (mounted) refresh();
  }

  void _openMember(String memberId) {
    final member = _members.where((m) => m.uid == memberId).firstOrNull;
    if (member == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerMemberDetailScreen(member: member),
      ),
    );
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
              AppViewTabs(
                labels: [for (final view in _HomeView.values) view.label],
                selectedIndex: _view.index,
                onSelect: (i) => setState(() => _view = _HomeView.values[i]),
              ),
              // 오늘 보기(시안 TrainerHome)에는 공지 줄이 없다. 중요 공지 시트는 어느 보기에서든 뜬다.
              NoticeHomeBanner(showBanner: _view != _HomeView.today),
              ...switch (_view) {
                _HomeView.today => _todayChildren(),
                _HomeView.calendar => _calendarChildren(),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _todayChildren() {
    final today = _today();
    final todaySessions = _sessionsOn(_weekSessions, today);
    final weekStart = _weekStart(today);
    final weekCounts = [
      for (var i = 0; i < 7; i++)
        _sessionsOn(_weekSessions, weekStart.add(Duration(days: i))).length,
    ];
    final now = DateTime.now();

    return [
      _TodayPtCard(
        today: today,
        done: todaySessions
            .where((s) => s.status == PtSessionStatus.completed)
            .length,
        total: todaySessions.length,
      ),
      _WeekCountCard(
        weekStart: weekStart,
        today: today,
        counts: weekCounts,
        onSelect: _openDay,
      ),
      if (_todayFailed)
        AppErrorCard(message: '오늘 일정을 불러오지 못했습니다', onRetry: () => _loadToday()),
      const _SectionTitle('오늘 PT', top: 22),
      if (_todayLoading && _weekSessions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: AppLoader.screen()),
        )
      else if (todaySessions.isEmpty)
        const AppEmptyLine('오늘 예정된 PT가 없습니다')
      else
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              for (final session in todaySessions)
                _PtRow(
                  session: session,
                  now: now,
                  strong: true,
                  onTap: () => _openPt(session),
                ),
            ],
          ),
        ),
      _SoloWorkoutSummary(workouts: _todayWorkouts, onOpenMember: _openMember),
    ];
  }

  List<Widget> _calendarChildren() {
    final sessions = _sessionsOn(_ptSessions, _selectedDay);
    final workouts = _personalWorkoutsOn(_selectedDay);
    final now = DateTime.now();

    return [
      AppMonthNav(
        month: _focusedMonth,
        onPrev: () => _moveMonth(-1),
        onNext: () => _moveMonth(1),
      ),
      // 조회 실패: 달력 표시가 조용히 비지 않게 달력 바로 위에 알린다.
      if (_errorMessage != null)
        AppErrorCard(message: _errorMessage!, onRetry: _loadMonth),
      AppCalendarGrid(
        focusedMonth: _focusedMonth,
        selectedDay: _selectedDay,
        marks: buildCalendarMarks(sessions: _ptSessions, workouts: _workouts),
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
      const AppCalendarBand(),
      AppDayHeader(
        label: appDayLabel(_selectedDay),
        count: _isLoading || _errorMessage != null
            ? null
            : 'PT ${sessions.length} · 개인 ${workouts.length}',
      ),
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
          child: Center(child: AppLoader.screen()),
        )
      else if (_errorMessage == null)
        if (sessions.isEmpty && workouts.isEmpty)
          const AppEmptyLine('이 날의 기록이 없습니다')
        else
          Column(
            // 날을 바꾸면 줄이 다시 밀려 들어오게 (시안 `row`)
            key: ValueKey(_key(_selectedDay)),
            children: [
              for (final (i, session) in sessions.indexed)
                AppEntrance(
                  delay: Duration(milliseconds: 60 * i),
                  child: _PtRow(
                    session: session,
                    now: now,
                    strong: false,
                    onTap: () => _openPt(session),
                  ),
                ),
              for (final (i, workout) in workouts.indexed)
                AppEntrance(
                  delay: Duration(milliseconds: 60 * (sessions.length + i)),
                  child: _WorkoutRow(
                    workout: workout,
                    onTap: () => _openMember(workout.memberId),
                  ),
                ),
            ],
          ),
    ];
  }
}

/// 묶음 제목 17/700 (시안 TrainerHome '오늘 PT'), 좌우 20.
class _SectionTitle extends StatelessWidget {
  final String label;
  final double top;
  final String? trailing;

  const _SectionTitle(this.label, {this.top = AppSpacing.lg, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        top,
        AppSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label, style: AppTextStyles.section.bold.natural),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: AppTextStyles.bodyMd.bold.natural),
        ],
      ),
    );
  }
}

/// 오늘 PT 카드 (주황, 반경 20, 안쪽 18 20): '오늘 PT' · 날짜(15) →
/// '2건 완료 / 4건'(28) → 8 높이 막대 = 완료 비율.
class _TodayPtCard extends StatelessWidget {
  final DateTime today;
  final int done;
  final int total;

  const _TodayPtCard({
    required this.today,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onPrimary;
    final label = AppTextStyles.bodyMd.bold.natural.copyWith(color: fg);
    final big = AppTextStyles.displayMd.bold.natural.copyWith(color: fg);
    return Semantics(
      label: total == 0 ? '오늘 예약된 PT 없음' : '오늘 PT $total건 중 $done건 완료',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.base,
          AppSpacing.screenH,
          0,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          18,
          AppSpacing.lg,
          18,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('오늘 PT', style: label)),
                Text(appDayLabel(today), style: label),
              ],
            ),
            const Gap(AppSpacing.xs),
            if (total == 0)
              Text('예약 없음', style: big)
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$done건 완료'),
                    TextSpan(
                      text: ' / $total건',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                style: big,
              ),
            const Gap(AppSpacing.md),
            AppProgressBar(
              value: total == 0 ? 0 : done / total,
              height: 8,
              color: fg,
              trackColor: fg.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이번 주 줄 (회색 카드, 반경 20, 안쪽 16 12): 요일 12 · 날짜 32 원(오늘 = ink 채움) · 'N건' 11.
class _WeekCountCard extends StatelessWidget {
  final DateTime weekStart;
  final DateTime today;
  final List<int> counts;
  final ValueChanged<DateTime> onSelect;

  const _WeekCountCard({
    required this.weekStart,
    required this.today,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final small = AppTextStyles.bodySm.natural;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _day(
                weekStart.add(Duration(days: i)),
                weekdays[i],
                counts[i],
                small,
              ),
            ),
        ],
      ),
    );
  }

  Widget _day(DateTime day, String weekday, int count, TextStyle small) {
    final isToday = DateUtils.isSameDay(day, today);
    return Semantics(
      button: true,
      label: [
        DateFormat('M월 d일', 'ko').format(day),
        if (isToday) '오늘',
        'PT $count건',
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelect(day),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              weekday,
              style: small.copyWith(fontSize: 12, letterSpacing: 12 * -0.019),
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
            SizedBox(
              height: 14,
              child: count == 0
                  ? null
                  : Text(
                      '$count건',
                      style: small.copyWith(
                        fontSize: 11,
                        letterSpacing: 11 * -0.019,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PT 한 줄 (64, 좌우 20 안쪽 hairline): 시각 · 회원 이름 16 + 'PT · 50분' 13 · 오른쪽 상태.
/// - 완료: 시각 faint, '완료'(캘린더 보기는 화살표 함께)
/// - 시작 시각이 지난 예약: 주황 pill '기록하기'(오늘 보기)·'기록'(캘린더 보기), 맥박
/// - 아직 오지 않은 예약: '예정'(오늘 보기) / 회색 pill '기록'(캘린더 보기)
/// [strong]은 기준 시안 TrainerHome(Bold), 아니면 상세 시안 Tr-Home(Medium).
class _PtRow extends StatelessWidget {
  final PtSession session;
  final DateTime now;
  final bool strong;
  final VoidCallback onTap;

  const _PtRow({
    required this.session,
    required this.now,
    required this.strong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = session.status == PtSessionStatus.completed;
    final due = !done && !session.scheduledAt.isAfter(now);
    TextStyle w(TextStyle s) => strong ? s.bold : s;

    final Widget trailing;
    if (done) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '완료',
            style: AppTextStyles.buttonLabel.copyWith(color: AppColors.mute),
          ),
          if (!strong) ...[
            const Gap(2),
            Icon(AppIcons.chevronRightBold, size: 16, color: AppColors.chevron),
          ],
        ],
      );
    } else if (due) {
      trailing = AppPulse(
        scale: 1.06,
        child: _RecordPill(
          label: strong ? '기록하기' : '기록',
          primary: true,
          strong: strong,
        ),
      );
    } else if (strong) {
      trailing = Text(
        '예정',
        style: AppTextStyles.buttonLabel.copyWith(color: AppColors.mute),
      );
    } else {
      trailing = _RecordPill(label: '기록', primary: false, strong: strong);
    }

    return InkWell(
      onTap: onTap,
      highlightColor: AppColors.canvasSoft,
      splashFactory: NoSplash.splashFactory,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: strong ? 44 : 48,
              child: Text(
                DateFormat('HH:mm').format(session.scheduledAt),
                style: w(AppTextStyles.bodyMd.natural).copyWith(
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                  color: done ? AppColors.faint : AppColors.ink,
                ),
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.memberName,
                    style: w(AppTextStyles.listTitle.natural),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    'PT · ${session.durationMinutes}분',
                    style: AppTextStyles.bodySm.natural,
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.sm),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 36 높이 pill: 주황(시작 시각이 지나 기록할 PT) 또는 회색(아직 오지 않은 PT).
class _RecordPill extends StatelessWidget {
  final String label;
  final bool primary;
  final bool strong;

  const _RecordPill({
    required this.label,
    required this.primary,
    required this.strong,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.buttonLabel.natural.copyWith(
      color: primary ? AppColors.onPrimary : AppColors.ink,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
    );
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: strong ? 14 : AppSpacing.base),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? AppColors.primary : AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: style),
    );
  }
}

/// 개인운동 한 줄 (68, 좌우 20 안쪽 hairline): 회원 이름 16 + '개인운동 · 하체 · 16세트 · 볼륨 4,320kg' + 화살표 20.
class _WorkoutRow extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _WorkoutRow({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final detail = [
      '개인운동',
      workout.category.label,
      '${workout.totalSets}세트',
      '볼륨 ${NumberFormat('#,##0').format(workout.totalVolume.round())}kg',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      highlightColor: AppColors.canvasSoft,
      splashFactory: NoSplash.splashFactory,
      child: Container(
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.memberName,
                    style: AppTextStyles.listTitle.natural,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(3),
                  Text(
                    detail,
                    style: AppTextStyles.bodySm.natural,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRightBold, size: 20, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// 혼자 운동한 회원 (시안 TrainerHome): 제목 17 + 오른쪽 'N명', 아래 14 mute 한 줄
/// '박지현 · 상체 4종목, 정민수 · 유산소 30분 외 1명'. 이름을 누르면 회원 상세.
class _SoloWorkoutSummary extends StatelessWidget {
  final List<Workout> workouts;
  final ValueChanged<String> onOpenMember;

  const _SoloWorkoutSummary({
    required this.workouts,
    required this.onOpenMember,
  });

  static const _shown = 2;

  String _summary(Workout w) {
    if (w.category == WorkoutCategory.cardio) {
      final minutes = (w.durationSeconds / 60).round();
      return '${w.memberName} · 유산소${minutes > 0 ? ' $minutes분' : ''}';
    }
    return '${w.memberName} · ${w.category.label} ${w.exercises.length}종목';
  }

  @override
  Widget build(BuildContext context) {
    // 회원마다 첫 기록 하나로 요약한다.
    final byMember = <String, Workout>{};
    for (final w in workouts) {
      byMember.putIfAbsent(w.memberId, () => w);
    }
    final items = byMember.values.toList();
    final caption = AppTextStyles.note.natural.copyWith(color: AppColors.mute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          '혼자 운동한 회원',
          trailing: items.isEmpty ? null : '${items.length}명',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            6,
            AppSpacing.screenH,
            0,
          ),
          child: items.isEmpty
              ? Text('오늘은 아직 없습니다', style: caption)
              : Wrap(
                  children: [
                    for (final (i, w) in items.take(_shown).indexed)
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => onOpenMember(w.memberId),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '${i > 0 ? ', ' : ''}${_summary(w)}',
                            style: caption,
                          ),
                        ),
                      ),
                    if (items.length > _shown)
                      Text(' 외 ${items.length - _shown}명', style: caption),
                  ],
                ),
        ),
      ],
    );
  }
}
