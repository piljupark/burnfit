import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_section.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_loader.dart';
import 'trainer_pt_workout_screen.dart';

/// 트레이너 일정 탭 (기준 시안 TrainerSchedule, 상세 Tr-Schedule·Tr-Schedule-Empty).
/// '일정' 제목 + '‹ 10월 2주 ›' → 주간 7칸 → 시간 타임라인(현재 시각 선) → 회원 운동 기록,
/// 오른쪽 아래 검정 'PT 예약' 버튼.
class TrainerScheduleScreen extends StatefulWidget {
  /// true면 하단 탭 화면('일정' 제목 + 탭 바 위 버튼), false면 하위 화면(뒤로 + 제목).
  /// 시트·대화상자가 떠 있을 때 `Navigator.canPop()`이 바뀌어 모양이 흔들리지 않도록 명시한다.
  final bool asTab;

  const TrainerScheduleScreen({super.key, this.asTab = true});

  @override
  State<TrainerScheduleScreen> createState() => TrainerScheduleScreenState();
}

class TrainerScheduleScreenState extends State<TrainerScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<PtSession> _sessions = [];
  List<AppUser> _members = [];
  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _sessionsLoadId = 0;

  /// 담당 회원 목록을 한 번이라도 불러왔는지. 아직이면 예약 시트를 열지 않는다.
  bool _membersLoaded = false;

  /// 예약 취소 진행 중 (그동안 ⋯·취소를 다시 누르면 무시).
  bool _isCancelling = false;

  /// 현재 시각 선·진행 중 표시를 1분마다 다시 그린다.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// 알림 등으로 탭에 들어올 때 최신 일정을 다시 불러온다.
  void refresh() => _loadSessions();

  /// 불러올 범위: 그 달 1일이 있는 주의 월요일 ~ 말일이 있는 주의 일요일.
  /// 주 칸이 다른 달에 걸쳐도 표시 점이 빠지지 않게, 보이는 주(고른 날의 주)도 늘 포함한다.
  static ({DateTime from, DateTime to}) _loadRange(
    DateTime focusedDay,
    DateTime selectedDay,
  ) {
    final first = DateTime(focusedDay.year, focusedDay.month, 1);
    final last = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    var from = _mondayOf(first);
    var to = DateTime(last.year, last.month, last.day + (7 - last.weekday));
    final weekStart = _mondayOf(selectedDay);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    if (weekStart.isBefore(from)) from = weekStart;
    if (weekEnd.isAfter(to)) to = weekEnd;
    return (from: from, to: DateTime(to.year, to.month, to.day, 23, 59, 59));
  }

  /// [silent]면 로딩 화면 없이 뒤에서 다시 불러온다 (저장·취소 직후).
  Future<void> _loadSessions({bool silent = false}) async {
    if (!mounted) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final loadId = ++_sessionsLoadId;
    if (!silent) setState(() => _isLoading = true);
    try {
      final range = _loadRange(_focusedDay, _selectedDay);
      final from = range.from;
      final to = range.to;
      final initialResults = await Future.wait([
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: from,
          to: to,
        ),
        FirestoreService.getMembersByTrainer(user.centerId, user.uid),
      ]).timeout(const Duration(seconds: 12));
      final members = initialResults[1] as List<AppUser>;
      // 공유를 끈 회원은 트레이너 자신의 PT 기록만 돌아온다. 그 밖의 오류는 화면 오류로 보인다.
      final workoutResults = await Future.wait(
        members.map(
          (member) => WorkoutService.getMemberWorkoutsForTrainer(
            centerId: user.centerId,
            memberId: member.uid,
            trainerId: user.uid,
            startDate: DateFormat('yyyy-MM-dd').format(from),
            endDate: DateFormat('yyyy-MM-dd').format(to),
          ),
        ),
      ).timeout(const Duration(seconds: 12));
      if (!mounted || loadId != _sessionsLoadId) return;
      setState(() {
        _sessions = initialResults[0] as List<PtSession>;
        _members = members;
        _membersLoaded = true;
        _workouts = workoutResults.expand((result) => result.workouts).toList();
        _errorMessage = null;
      });
    } catch (e) {
      AppLogger.debug('[PT세션 로드 오류] $e');
      if (!mounted || loadId != _sessionsLoadId) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted && loadId == _sessionsLoadId) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PtSession> get _selectedSessions {
    return _sessions.where((s) {
      return isSameDay(s.scheduledAt, _selectedDay) &&
          s.status != PtSessionStatus.cancelled;
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Workout> get _selectedWorkouts {
    final selectedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);
    return _workouts.where((item) => item.workoutDate == selectedDate).toList()
      ..sort((a, b) => a.memberName.compareTo(b.memberName));
  }

  /// 취소되지 않은 세션 (예약 시트에서 겹치는 시각 표시용).
  List<PtSession> get _activeSessions =>
      _sessions.where((s) => s.status != PtSessionStatus.cancelled).toList();

  /// 날짜를 고른다. 불러온 달을 벗어나면 그 달을 다시 불러온다.
  void _selectDay(DateTime day) {
    final monthChanged =
        day.year != _focusedDay.year || day.month != _focusedDay.month;
    setState(() {
      _selectedDay = day;
      if (monthChanged) _focusedDay = day;
    });
    if (monthChanged) _loadSessions();
  }

  void _moveWeek(int delta) => _selectDay(
    DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + 7 * delta,
    ),
  );

  /// 예약 세션의 수정·취소 시트 (시안 Tr-Session-Actions).
  Future<void> _showSessionActions(PtSession session) async {
    if (_isCancelling) return;
    await showAppBottomSheet<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(
              title: session.memberName,
              subtitle:
                  '${DateFormat('M월 d일 (E) HH:mm', 'ko').format(session.scheduledAt)} · ${session.durationMinutes}분',
              mutedSubtitle: true,
              gap: AppSpacing.md,
            ),
            AppSheetAction(
              icon: AppIcons.edit,
              label: '예약 수정',
              chevron: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editSession(session);
              },
            ),
            const AppRowDivider(),
            AppSheetAction(
              icon: AppIcons.close,
              label: '예약 취소',
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _cancelSession(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSession() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;
    // 담당 회원 목록을 아직 못 불러왔으면 '담당 회원이 없습니다'로 오해하지 않게 시트를 열지 않는다.
    if (!_membersLoaded) {
      AppFeedback.showWarning(
        context,
        _isLoading
            ? '회원 목록을 불러오는 중입니다. 잠시 후 다시 눌러 주세요.'
            : '회원 목록을 다시 불러옵니다. 잠시 후 다시 눌러 주세요.',
      );
      if (!_isLoading) _loadSessions();
      return;
    }

    final result = await showAppBottomSheet<PtSession>(
      context: context,
      child: _SessionSheet(
        trainerId: trainer.uid,
        trainerName: trainer.name,
        centerId: trainer.centerId,
        members: _members,
        initialDate: _selectedDay,
        bookedSessions: _activeSessions,
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _sessions.add(result));
    // 저장 전에 시작된 불러오기가 이 예약을 덮어쓰지 않도록 무효화하고 다시 불러온다.
    _loadSessions(silent: true);
  }

  Future<void> _editSession(PtSession session) async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    final result = await showAppBottomSheet<PtSession>(
      context: context,
      child: _SessionSheet(
        trainerId: trainer.uid,
        trainerName: trainer.name,
        centerId: trainer.centerId,
        members: _members,
        initialDate: session.scheduledAt,
        existing: session,
        bookedSessions: _activeSessions,
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    setState(() {
      final idx = _sessions.indexWhere((s) => s.id == result.id);
      if (idx == -1) {
        _sessions.add(result);
      } else {
        _sessions[idx] = result;
      }
    });
    _loadSessions(silent: true);
  }

  Future<void> _openPtWorkout(PtSession session) async {
    final member = _members.where((m) => m.uid == session.memberId).firstOrNull;
    if (member == null) {
      AppFeedback.showErrorSnackBar(
        context,
        ArgumentError('회원 정보를 찾을 수 없습니다.'),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrainerPtWorkoutScreen(session: session, member: member),
      ),
    );
    if (!mounted) return;
    await _loadSessions();
  }

  /// 예약 취소 확인 (시안 Tr-Session-CancelConfirm: 닫기 · 검정 '예약 취소').
  Future<void> _cancelSession(PtSession session) async {
    if (_isCancelling) return;
    final confirm = await showAppConfirmDialog(
      context,
      title: '예약 취소',
      message:
          '${session.memberName}님의 ${DateFormat('M월 d일 HH:mm', 'ko').format(session.scheduledAt)} 예약을 취소합니다.',
      confirmLabel: '예약 취소',
      cancelLabel: '닫기',
    );
    if (confirm != true || !mounted || _isCancelling) return;

    _isCancelling = true;
    try {
      await FirestoreService.updatePtSessionStatus(
        session.id,
        PtSessionStatus.cancelled,
      );
      if (!mounted) return;
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) {
          _sessions[idx] = PtSession(
            id: session.id,
            centerId: session.centerId,
            trainerId: session.trainerId,
            trainerName: session.trainerName,
            memberId: session.memberId,
            memberName: session.memberName,
            scheduledAt: session.scheduledAt,
            durationMinutes: session.durationMinutes,
            note: session.note,
            status: PtSessionStatus.cancelled,
            createdAt: session.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });
      _loadSessions(silent: true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      _isCancelling = false;
    }
  }

  /// 제목 오른쪽 주 이동: '‹ 10월 2주 ›' (화살표 44 터치 영역 안 18, 글자 16/700).
  Widget _weekNav() {
    final label = _weekLabel(_selectedDay);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavArrow(
          icon: AppIcons.chevronLeftBold,
          label: '이전 주',
          onTap: () => _moveWeek(-1),
          size: 18,
        ),
        Semantics(
          liveRegion: true,
          child: Text(label, style: AppTextStyles.input.bold.natural),
        ),
        AppNavArrow(
          icon: AppIcons.chevronRightBold,
          label: '다음 주',
          onTap: () => _moveWeek(1),
          size: 18,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _selectedSessions;
    final workouts = _selectedWorkouts;
    // 시트·대화상자가 떠 있어도 바뀌지 않도록 생성자 표시로 판정한다.
    final canPop = !widget.asTab;
    final now = DateTime.now();

    final List<Widget> content;
    if (_isLoading) {
      content = const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
          child: Center(child: AppLoader.screen()),
        ),
      ];
    } else if (_errorMessage != null) {
      content = [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: AppErrorCard(message: _errorMessage!, onRetry: _loadSessions),
        ),
      ];
    } else if (sessions.isEmpty && workouts.isEmpty) {
      // 시안 Tr-Schedule-Empty: 회색 카드 + 달력 40(faint) + 16/500 한 줄
      content = [
        AppEmptyState(
          icon: AppIcons.calendar,
          card: true,
          illustration: Icon(
            AppIcons.calendar,
            size: 40,
            color: AppColors.faint,
          ),
          artGap: 10,
          cardPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            0,
          ),
          message: isSameDay(_selectedDay, now)
              ? '오늘 예약이 없습니다.'
              : '이 날 예약이 없습니다.',
        ),
      ];
    } else {
      content = [
        if (sessions.isNotEmpty)
          _SessionTimeline(
            sessions: sessions,
            now: now,
            showNow: isSameDay(_selectedDay, now),
            onRecord: _openPtWorkout,
            onManage: _showSessionActions,
          ),
        if (workouts.isNotEmpty) ...[
          if (sessions.isNotEmpty) const AppSectionBand(top: AppSpacing.lg),
          AppMonthHeader(
            label: '운동 기록',
            count: '${workouts.length}',
            strong: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              18,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
          ),
          for (final workout in workouts) _WorkoutRow(workout: workout),
        ],
      ];
    }

    // 떠 있는 'PT 예약' 버튼 위치: 탭 화면이면 하단 탭(56 + 기기 아래 여백) 위, 단독 화면이면 기기 아래 여백 위.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final fabBottom =
        (canPop ? 0.0 : _navBarHeight) + bottomInset + AppSpacing.screenH;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              // 아래로 스크롤하면 떠 있는 버튼을 원으로 접고, 위로 올리거나 맨 위면 다시 편다.
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: RefreshIndicator(
                  onRefresh: _loadSessions,
                  color: AppColors.ink,
                  backgroundColor: AppColors.canvasCard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 하단 탭 + 떠 있는 버튼(56)에 마지막 블록이 가리지 않게.
                    padding: const EdgeInsets.only(
                      bottom:
                          AppSize.navClearance + _fabHeight + AppSpacing.base,
                    ),
                    children: [
                      // 탭이면 '일정' 제목 + 주 이동 한 줄, 하위 화면으로 열렸으면 뒤로 + 제목 + 주 이동
                      if (canPop)
                        AppScreenHeader(
                          title: '일정',
                          onBack: () => Navigator.of(context).pop(),
                          trailing: _weekNav(),
                        )
                      else
                        AppHero(
                          title: '일정',
                          bottomGap: 0,
                          actions: [_weekNav()],
                        ),
                      _WeekStrip(
                        selectedDay: _selectedDay,
                        marks: buildCalendarMarks(
                          sessions: _sessions,
                          workouts: _workouts,
                        ),
                        onSelect: _selectDay,
                        onPrevWeek: () => _moveWeek(-1),
                        onNextWeek: () => _moveWeek(1),
                      ),
                      ...content,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.screenH,
            bottom: fabBottom,
            child: AppFloatingAction(
              label: 'PT 예약',
              icon: AppIcons.add,
              onPressed: _createSession,
              extended: _fabExtended,
            ),
          ),
        ],
      ),
    );
  }

  bool _fabExtended = true;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    bool? next;
    if (n.metrics.pixels <= 8) {
      next = true;
    } else if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) next = false;
      if (n.direction == ScrollDirection.forward) next = true;
    }
    if (next != null && next != _fabExtended) {
      setState(() => _fabExtended = next!);
    }
    return false;
  }

  /// 하단 탭 높이 (AppNavBar, 기기 아래 여백 제외).
  static const double _navBarHeight = 56;

  /// AppFloatingAction 높이.
  static const double _fabHeight = 56;
}

/// 그 날이 있는 주의 월요일 (일광 절약 시간에도 어긋나지 않게 날짜 계산).
DateTime _mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// '10월 2주': 그 주(월~일)의 목요일이 속한 달과 그 달의 몇째 주.
String _weekLabel(DateTime day) {
  final monday = _mondayOf(day);
  final thursday = DateTime(monday.year, monday.month, monday.day + 3);
  return '${thursday.month}월 ${(thursday.day - 1) ~/ 7 + 1}주';
}

// ─────────────────────────────────────────────────────────────────────────────
// 주간 7칸 (시안 TrainerSchedule): 요일 12 mute · 32 원 · 아래 표시 줄, 아래 hairline.
// 선택일 = ink 채운 원 + canvas 700 숫자, 오늘 = ink 1px 외곽선 원. 좌우로 밀면 주 이동.
// ─────────────────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final DateTime selectedDay;
  final Map<String, Set<CalendarMark>> marks;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  const _WeekStrip({
    required this.selectedDay,
    required this.marks,
    required this.onSelect,
    required this.onPrevWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final monday = _mondayOf(selectedDay);
    final now = DateTime.now();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 200) onPrevWeek();
        if (v < -200) onNextWeek();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = DateTime(
                      monday.year,
                      monday.month,
                      monday.day + i,
                    );
                    final isToday = isSameDay(day, now);
                    final dayMarks =
                        marks[DateFormat('yyyy-MM-dd').format(day)] ??
                        const <CalendarMark>{};
                    return AppWeekDay(
                      day: day,
                      selected: isSameDay(day, selectedDay),
                      outlined: isToday,
                      semanticLabel: [
                        '${day.month}월 ${day.day}일 ${weekdayLabels[i]}요일',
                        if (isToday) '오늘',
                        if (dayMarks.isNotEmpty)
                          calendarMarksSemantics(dayMarks),
                      ].join(', '),
                      onTap: () => onSelect(day),
                      below: SizedBox(
                        height: 6,
                        child: Center(child: CalendarMarkRow(dayMarks)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시간 타임라인 (시안 TrainerSchedule): 왼쪽 40 시각(13 mute) + 12 + hairline 위 블록.
// 완료 = 회색 면 + mute 글자, 진행 중 = 주황 채움, 예정 = 흰 면 + 1.5 주황 테두리 (반경 14).
// 오늘이면 현재 시각에 주황 선 + 깜빡이는 점.
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTimeline extends StatelessWidget {
  final List<PtSession> sessions;
  final DateTime now;
  final bool showNow;
  final ValueChanged<PtSession> onRecord;
  final ValueChanged<PtSession> onManage;

  const _SessionTimeline({
    required this.sessions,
    required this.now,
    required this.showNow,
    required this.onRecord,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    // sessions는 시간순으로 정렬돼 있다. 첫 세션 시각부터 마지막 세션 시각까지 빈 시간도 줄로 보여 준다.
    // 마지막 줄은 가장 늦게 끝나는 세션의 종료 시각, 오늘이면 지금 시각까지 넓혀 진행 중 세션에도 현재 선이 보이게 한다.
    final firstHour = sessions.first.scheduledAt.hour;
    var lastHour = sessions.last.scheduledAt.hour;
    for (final s in sessions) {
      final start = s.scheduledAt;
      // 정각에 끝나면 그 시각 줄은 필요 없다 (11:00 종료 → 10시 줄까지).
      final endMark = start.add(
        Duration(minutes: s.durationMinutes > 0 ? s.durationMinutes - 1 : 0),
      );
      final endHour = isSameDay(endMark, start) ? endMark.hour : 23;
      if (endHour > lastHour) lastHour = endHour;
    }
    if (showNow && now.hour > lastHour) lastHour = now.hour;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      child: Column(
        children: [
          for (var hour = firstHour; hour <= lastHour; hour++)
            _HourRow(
              hour: hour,
              nowFraction: showNow && now.hour == hour
                  ? (now.minute * 60 + now.second) / 3600
                  : null,
              children: [
                for (final s in sessions.where(
                  (s) => s.scheduledAt.hour == hour,
                ))
                  _SessionBlock(
                    session: s,
                    now: now,
                    onRecord: s.status == PtSessionStatus.cancelled
                        ? null
                        : () => onRecord(s),
                    onManage: s.status == PtSessionStatus.scheduled
                        ? () => onManage(s)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final int hour;
  final List<Widget> children;

  /// 이 시간 줄 안 현재 시각 위치 (0~1). 없으면 선을 그리지 않는다.
  final double? nowFraction;

  const _HourRow({
    required this.hour,
    required this.children,
    this.nowFraction,
  });

  static const double _timeWidth = 40;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _timeWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: AppTextStyles.counter.natural,
            ),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
    final fraction = nowFraction;
    if (fraction == null) return row;

    // 현재 시각 선: 점(9) 가운데가 hairline 시작보다 조금 왼쪽에 오도록 (시안 left 66).
    return Stack(
      children: [
        row,
        Positioned.fill(
          left: _timeWidth + _gap - 10,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Align(
                alignment: Alignment(-1, -1 + 2 * fraction.clamp(0.0, 1.0)),
                child: const _NowLine(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 현재 시각 주황 선(2) + 깜빡이는 점(9).
class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 9,
      child: Row(
        children: [
          AppBlink(
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: AppColors.primary)),
        ],
      ),
    );
  }
}

enum _BlockState { done, live, upcoming }

class _SessionBlock extends StatelessWidget {
  final PtSession session;
  final DateTime now;

  /// 취소된 세션은 null.
  final VoidCallback? onRecord;

  /// 예약 상태에서만 (완료 세션은 null).
  final VoidCallback? onManage;

  const _SessionBlock({
    required this.session,
    required this.now,
    this.onRecord,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final start = session.scheduledAt;
    final end = start.add(Duration(minutes: session.durationMinutes));
    final state = session.status == PtSessionStatus.completed
        ? _BlockState.done
        : session.status == PtSessionStatus.scheduled &&
              !now.isBefore(start) &&
              now.isBefore(end)
        ? _BlockState.live
        : _BlockState.upcoming;
    final f = DateFormat('HH:mm');
    final range = '${f.format(start)} ~ ${f.format(end)}';
    // 색만으로 상태를 나누지 않도록 보조 줄에 '완료'·'진행 중'을 적는다.
    final meta = switch (state) {
      _BlockState.done => '$range · 완료',
      _BlockState.live => '$range · 진행 중',
      _BlockState.upcoming => range,
    };
    final note = session.note;

    final Color background;
    final Color nameColor;
    final Color metaColor;
    final Color noteColor;
    switch (state) {
      case _BlockState.done:
        background = AppColors.canvasCard;
        nameColor = AppColors.mute;
        metaColor = AppColors.mute;
        noteColor = AppColors.mute;
      case _BlockState.live:
        background = AppColors.primary;
        nameColor = AppColors.onPrimary;
        metaColor = AppColors.onPrimary.withValues(alpha: 0.7);
        noteColor = AppColors.onPrimary.withValues(alpha: 0.7);
      case _BlockState.upcoming:
        background = AppColors.canvas;
        nameColor = AppColors.ink;
        metaColor = AppColors.mute;
        noteColor = AppColors.body;
    }

    final hasButton = onRecord != null || onManage != null;
    return Container(
      // 버튼이 있으면 44 터치 영역이 위아래 6 안에 들어가 블록 높이(56)가 시안과 같다.
      padding: EdgeInsets.fromLTRB(
        14,
        hasButton ? 6 : 10,
        onManage != null ? 2 : (hasButton ? 10 : 14),
        hasButton ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: state == _BlockState.upcoming
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: hasButton ? 4 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.memberName,
                    style: AppTextStyles.bodyMd.bold.natural.copyWith(
                      color: nameColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta,
                    style: AppTextStyles.bodySm.natural.copyWith(
                      color: metaColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '메모: $note',
                      style: AppTextStyles.bodySm.natural.copyWith(
                        color: noteColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onRecord != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _BlockButton(
              label: state == _BlockState.done ? '기록 보기' : '기록 시작',
              filled: state != _BlockState.done,
              onTap: onRecord!,
            ),
          ],
          if (onManage != null)
            AppIconButton(
              icon: AppIcons.more,
              label: '${session.memberName} 예약 수정·취소',
              onPressed: onManage,
              color: state == _BlockState.live
                  ? AppColors.onPrimary
                  : AppColors.mute,
            ),
        ],
      ),
    );
  }
}

/// 블록 안 36 알약 버튼 (시안 Tr-Schedule): '기록 시작' = 검정 채움 + 흰 글자, '기록 보기' = 흰 면.
/// 터치 영역은 44.
class _BlockButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _BlockButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.canvas : AppColors.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSize.touchMin,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: filled ? AppColors.ink : AppColors.canvas,
                shape: const StadiumBorder(),
              ),
              child: Text(
                label,
                style: AppTextStyles.buttonLabel.medium.natural.copyWith(
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 회원 운동 기록 줄 (보기 전용, 시안 Tr-Schedule): 64 높이, 이름 16/500 + 13 mute 보조 줄.
// PT 운동은 'PT 운동'만 ink 500으로 강조한다.
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutRow extends StatelessWidget {
  final Workout workout;

  const _WorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isPtWorkout = workout.workoutType == WorkoutType.pt;
    final meta = AppTextStyles.bodySm.natural;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.memberName,
            style: AppTextStyles.listTitle.natural,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: isPtWorkout ? 'PT 운동' : '개인 운동',
                  style: isPtWorkout
                      ? meta.medium.copyWith(color: AppColors.ink)
                      : null,
                ),
                TextSpan(
                  text:
                      ' · ${workout.category.label} 운동 · ${workout.totalSets}세트',
                ),
              ],
            ),
            style: meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PT 예약 시트 (기준 시안 TrainerReserve, 상세 Tr-Reserve-*):
// 회색 묶음 카드(회원 · 날짜 56 줄, 시작 · 진행 2칸) → 시간 휠 → 겹침 경고 → 메모 → '예약하기'.
// ─────────────────────────────────────────────────────────────────────────────

enum _Picker { none, member, date, time, duration }

class _SessionSheet extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String centerId;
  final List<AppUser> members;
  final DateTime initialDate;
  final PtSession? existing;

  /// 취소되지 않은 기존 세션. 고른 시간대와 겹치면 경고하고 저장을 막는다.
  final List<PtSession> bookedSessions;

  const _SessionSheet({
    required this.trainerId,
    required this.trainerName,
    required this.centerId,
    required this.members,
    required this.initialDate,
    this.existing,
    this.bookedSessions = const [],
  });

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  /// 진행 시간 선택지: 10분 단위 10~180분 (기존 예약 값이 단위에 안 맞으면 그 값도 포함).
  static const int _durationStep = 10;
  static const int _durationMax = 180;

  /// 시작 시간 휠의 분 단위.
  static const int _minuteStep = 5;

  AppUser? _selectedMember;
  late DateTime _scheduledAt;
  int _durationMinutes = 60;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  /// 지금 펼친 고르기. 새 예약은 시안처럼 시작 시간 휠을 펼친 채 연다.
  late _Picker _open = widget.existing == null ? _Picker.time : _Picker.none;

  /// 회원을 고르지 않고 저장하려 할 때 회원 줄을 주황 테두리로 흔든다 (시안 Tr-Reserve-NoMember).
  bool _memberError = false;
  int _memberShake = 0;

  bool get _isEditing => widget.existing != null;

  /// 진행 시간·시작 분 선택지. 시트를 열 때 한 번 만들어 고정한다 —
  /// 휠을 돌리는 동안 목록이 바뀌면 휠 위치와 저장 값이 어긋난다.
  late final List<int> _durationValues;
  late final List<int> _minuteValues;

  /// 저장 직전 서버에서 다시 조회한 그날 예약 (불러온 범위 밖 날짜의 겹침 안내용).
  List<PtSession> _fetchedSessions = const [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _scheduledAt = existing.scheduledAt;
      _durationMinutes = existing.durationMinutes;
      _noteController.text = existing.note ?? '';
      for (final member in widget.members) {
        if (member.uid == existing.memberId) {
          _selectedMember = member;
          break;
        }
      }
    } else {
      _scheduledAt = _defaultStart(widget.initialDate);
    }
    _durationValues = _withValue([
      for (var m = _durationStep; m <= _durationMax; m += _durationStep) m,
    ], _durationMinutes);
    _minuteValues = _withValue([
      for (var m = 0; m < 60; m += _minuteStep) m,
    ], _scheduledAt.minute);
  }

  /// 선택지에 [value]가 없으면 넣고 정렬한다.
  static List<int> _withValue(List<int> values, int value) {
    if (!values.contains(value)) {
      values
        ..add(value)
        ..sort();
    }
    return List.unmodifiable(values);
  }

  /// 새 예약 기본 시작: 10:00. 고른 날이 오늘이고 10:00이 이미 지났으면 지금 이후 가장 가까운 5분 단위.
  /// 그 시각이 자정을 넘으면 10:00 그대로 둔다 (저장할 때 지난 시각 확인 창으로 묻는다).
  static DateTime _defaultStart(DateTime day) {
    final base = DateTime(day.year, day.month, day.day, 10, 0);
    final now = DateTime.now();
    if (!isSameDay(day, now) || base.isAfter(now)) return base;
    final next =
        (now.hour * 60 + now.minute) ~/ _minuteStep * _minuteStep + _minuteStep;
    if (next >= 24 * 60) return base;
    return DateTime(day.year, day.month, day.day, next ~/ 60, next % 60);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_isEditing && _selectedMember == null) {
      setState(() {
        _memberError = true;
        _memberShake++;
      });
      AppFeedback.showWarning(context, '회원을 선택해주세요.');
      return;
    }
    final conflict = _conflict;
    if (conflict != null) {
      AppFeedback.showWarning(context, _conflictMessage(conflict));
      return;
    }
    // 이미 지난 시각으로 새로 잡거나 옮기려 하면 한 번 묻는다.
    final timeChanged = widget.existing?.scheduledAt != _scheduledAt;
    if (timeChanged && _scheduledAt.isBefore(DateTime.now())) {
      final ok = await showAppConfirmDialog(
        context,
        title: '지난 시각 예약',
        message:
            '${DateFormat('M월 d일 HH:mm', 'ko').format(_scheduledAt)}은 이미 지난 시각입니다. 이대로 ${_isEditing ? '수정' : '예약'}할까요?',
        confirmLabel: _isEditing ? '예약 수정' : '예약하기',
        destructive: false,
      );
      if (!ok || !mounted || _isSaving) return;
    }
    setState(() => _isSaving = true);
    try {
      // 불러온 범위 밖 날짜도 겹침을 막도록 저장 직전에 그날 예약을 다시 조회한다.
      // 전날 밤 시작해 자정을 넘기는 예약도 겹칠 수 있으므로 전날부터 본다.
      final day = _scheduledAt;
      final daySessions = await FirestoreService.getPtSessionsByTrainer(
        widget.centerId,
        widget.trainerId,
        from: DateTime(day.year, day.month, day.day - 1),
        to: DateTime(day.year, day.month, day.day, 23, 59, 59),
      );
      if (!mounted) return;
      final serverConflict = _findConflict(daySessions);
      if (serverConflict != null) {
        setState(() => _fetchedSessions = daySessions);
        AppFeedback.showWarning(context, _conflictMessage(serverConflict));
        return;
      }
      final now = DateTime.now();
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      final existing = widget.existing;
      if (existing != null) {
        final updated = PtSession(
          id: existing.id,
          centerId: existing.centerId,
          trainerId: existing.trainerId,
          trainerName: existing.trainerName,
          memberId: existing.memberId,
          memberName: existing.memberName,
          scheduledAt: _scheduledAt,
          durationMinutes: _durationMinutes,
          note: note,
          status: existing.status,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        await FirestoreService.updatePtSessionSchedule(
          sessionId: updated.id,
          centerId: updated.centerId,
          memberId: updated.memberId,
          scheduledAt: updated.scheduledAt,
          durationMinutes: updated.durationMinutes,
          note: updated.note,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
        return;
      }

      const uuid = Uuid();
      final session = PtSession(
        id: uuid.v4(),
        centerId: widget.centerId,
        trainerId: widget.trainerId,
        trainerName: widget.trainerName,
        memberId: _selectedMember!.uid,
        memberName: _selectedMember!.name,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        note: note,
        status: PtSessionStatus.scheduled,
        createdAt: now,
        updatedAt: now,
      );
      await FirestoreService.savePtSession(session);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggle(_Picker picker) {
    setState(() => _open = _open == picker ? _Picker.none : picker);
  }

  /// 선택한 시간대(시작~시작+진행 시간)와 겹치는 다른 예약. 수정 중인 세션·취소된 예약은 제외.
  PtSession? get _conflict =>
      _findConflict(widget.bookedSessions) ?? _findConflict(_fetchedSessions);

  PtSession? _findConflict(Iterable<PtSession> sessions) {
    final existingId = widget.existing?.id;
    final start = _scheduledAt;
    final end = start.add(Duration(minutes: _durationMinutes));
    for (final s in sessions) {
      if (s.id == existingId || s.status == PtSessionStatus.cancelled) continue;
      final otherEnd = s.scheduledAt.add(Duration(minutes: s.durationMinutes));
      if (start.isBefore(otherEnd) && s.scheduledAt.isBefore(end)) return s;
    }
    return null;
  }

  /// 시안 TrainerReserve: '16:00 한유진 PT와 겹쳐요'.
  String _conflictMessage(PtSession other) {
    return '${DateFormat('HH:mm').format(other.scheduledAt)} ${other.memberName} PT와 겹쳐요';
  }

  void _setTime(int hour, int minute) {
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        hour,
        minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _conflict;
    final hm = DateFormat('HH:mm');
    final endAt = _scheduledAt.add(Duration(minutes: _durationMinutes));
    final memberName = _isEditing
        ? widget.existing!.memberName
        : _selectedMember?.name;
    final dateLabel = appDayLabel(_scheduledAt);
    final startLabel = hm.format(_scheduledAt);
    final endLabel = '${hm.format(endAt)} 종료';
    const cardRadius = Radius.circular(AppRadius.button);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: _isEditing ? 'PT 예약 수정' : 'PT 예약',
          gap: AppSpacing.md,
          boldTitle: true,
        ),

        // 회색 묶음 카드: 회원 · 날짜 · 시작/진행
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.canvasCard,
            borderRadius: const BorderRadius.all(cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppShake(
                trigger: _memberShake,
                child: _SheetRow(
                  label: '회원',
                  semanticLabel: '회원 선택',
                  value: memberName ?? '회원을 선택하세요',
                  isPlaceholder: memberName == null,
                  isActive: _open == _Picker.member,
                  isError: _memberError && memberName == null,
                  radius: const BorderRadius.vertical(top: cardRadius),
                  onTap: _isEditing ? null : () => _toggle(_Picker.member),
                ),
              ),
              if (!_isEditing && _open == _Picker.member)
                _MemberPickerList(
                  members: widget.members,
                  selected: _selectedMember,
                  onSelect: (m) => setState(() {
                    _selectedMember = m;
                    _memberError = false;
                    _open = _Picker.none;
                  }),
                ),
              _SheetRow(
                label: '날짜',
                semanticLabel: '날짜 선택',
                value: dateLabel,
                isActive: _open == _Picker.date,
                onTap: () => _toggle(_Picker.date),
              ),
              if (_open == _Picker.date)
                _DateWheel(
                  initial: _scheduledAt,
                  onChanged: (dt) => setState(() {
                    _scheduledAt = DateTime(
                      dt.year,
                      dt.month,
                      dt.day,
                      _scheduledAt.hour,
                      _scheduledAt.minute,
                    );
                  }),
                ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TimeCell(
                        label: '시작',
                        semanticLabel: '시작 시간 선택, $startLabel',
                        value: TextSpan(text: startLabel),
                        isActive: _open == _Picker.time,
                        radius: const BorderRadius.only(bottomLeft: cardRadius),
                        onTap: () => _toggle(_Picker.time),
                      ),
                    ),
                    Container(width: 1, color: AppColors.line),
                    Expanded(
                      child: _TimeCell(
                        label: '진행',
                        semanticLabel:
                            '진행 시간 선택, $_durationMinutes분, $endLabel',
                        value: TextSpan(
                          text: '$_durationMinutes분',
                          children: [
                            TextSpan(
                              text: ' · $endLabel',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: AppColors.mute,
                              ),
                            ),
                          ],
                        ),
                        isActive: _open == _Picker.duration,
                        radius: const BorderRadius.only(
                          bottomRight: cardRadius,
                        ),
                        onTap: () => _toggle(_Picker.duration),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 시작 시간 휠(시 · 5분 단위 분) / 진행 시간 휠(10분 단위)
        if (_open == _Picker.time)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _WheelBox(
              key: const ValueKey('time-wheel'),
              semanticLabel: '시작 시간 휠, $_minuteStep분 단위',
              columns: [
                _WheelColumn(
                  labels: [for (var h = 0; h < 24; h++) '$h시'],
                  initialIndex: _scheduledAt.hour,
                  onChanged: (i) => _setTime(i, _scheduledAt.minute),
                ),
                _WheelColumn(
                  labels: [for (final m in _minuteValues) '$m분'],
                  initialIndex: _minuteValues.indexOf(_scheduledAt.minute),
                  onChanged: (i) =>
                      _setTime(_scheduledAt.hour, _minuteValues[i]),
                ),
              ],
            ),
          )
        else if (_open == _Picker.duration)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _WheelBox(
              key: const ValueKey('duration-wheel'),
              semanticLabel: '진행 시간 휠, $_durationStep분 단위',
              columns: [
                _WheelColumn(
                  labels: [for (final m in _durationValues) '$m분'],
                  initialIndex: _durationValues.indexOf(_durationMinutes),
                  onChanged: (i) =>
                      setState(() => _durationMinutes = _durationValues[i]),
                ),
              ],
            ),
          ),

        // 겹침 경고: 새로 겹칠 때마다 한 번 흔든다.
        AppShake(
          trigger: conflict?.id,
          child: conflict == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: AppInlineNotice(
                    _conflictMessage(conflict),
                    bold: true,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.base),

        // 메모
        AppTextField(
          label: '메모',
          hint: '선택 사항',
          controller: _noteController,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.lg),

        AppButton(
          label: _isEditing ? '예약 수정' : '예약하기',
          size: AppButtonSize.lg,
          fullWidth: true,
          bold: true,
          isLoading: _isSaving,
          // 다른 예약과 겹치면 저장할 수 없다 (위에 안내 문구).
          onPressed: _isSaving || conflict != null ? null : _save,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시트 내 부품
// ─────────────────────────────────────────────────────────────────────────────

/// 묶음 카드 안 56 줄: 왼쪽 15 mute 라벨, 오른쪽 16/700 값. 아래 `line` 구분선.
/// 펼친 줄 = 흰 면 + 2px ink 테두리, 오류 = 1.5px noticeText 테두리 + 라벨 noticeText.
class _SheetRow extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final String value;
  final bool isPlaceholder;
  final bool isActive;
  final bool isError;

  /// 펼침·오류 테두리의 모서리 (카드 맨 위 줄은 위 18).
  final BorderRadius? radius;
  final VoidCallback? onTap;

  const _SheetRow({
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.isActive,
    this.isPlaceholder = false,
    this.isError = false,
    this.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Decoration decoration;
    if (isActive) {
      decoration = BoxDecoration(
        color: AppColors.canvas,
        borderRadius: radius,
        border: Border.all(color: AppColors.ink, width: 2),
      );
    } else if (isError) {
      decoration = BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.noticeText, width: 1.5),
      );
    } else {
      decoration = BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      );
    }
    final valueStyle = AppTextStyles.input.natural;

    // 색·흔들림만으로 알리지 않도록 오류 문구를 읽어 준다.
    return Semantics(
      button: onTap != null,
      expanded: onTap != null ? isActive : null,
      label: isError
          ? '$semanticLabel, 오류: $value. $label을 골라야 예약할 수 있습니다'
          : '$semanticLabel, $value',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: AppSize.listRow,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: decoration,
          child: Row(
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMd.natural.copyWith(
                  color: isError ? AppColors.noticeText : AppColors.mute,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isPlaceholder
                      ? valueStyle.copyWith(color: AppColors.mute)
                      : valueStyle.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시작 · 진행 칸: 13 mute 라벨 + 20/700 값. 펼친 칸 = 흰 면 + 2px ink 테두리.
class _TimeCell extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final InlineSpan value;
  final bool isActive;
  final BorderRadius radius;
  final VoidCallback onTap;

  const _TimeCell({
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.isActive,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isActive,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          decoration: isActive
              ? BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.ink, width: 2),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.bodySm.natural),
              const SizedBox(height: AppSpacing.xxs),
              // 좁은 폭에서는 한 줄을 지키며 글자를 줄인다 ('50분 · 16:20 종료').
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  value,
                  maxLines: 1,
                  style: AppTextStyles.title.bold.natural,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 회원 고르기 목록 (시안 Tr-Reserve-Member): 48 줄, 왼쪽 28 들여쓰기, 위 `line` 구분선,
/// 고른 회원 = 16/500 + 체크 20 (튀어나옴). 최대 224 높이에서 스크롤.
class _MemberPickerList extends StatelessWidget {
  final List<AppUser> members;
  final AppUser? selected;
  final ValueChanged<AppUser> onSelect;

  const _MemberPickerList({
    required this.members,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 224),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: members.isEmpty
          ? Container(
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(28, 0, AppSpacing.base, 0),
              child: Text(
                '담당 회원이 없습니다',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.body),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: members.length,
              itemBuilder: (context, i) {
                final m = members[i];
                final isSelected = selected?.uid == m.uid;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  child: InkWell(
                    onTap: () => onSelect(m),
                    highlightColor: AppColors.canvasSoft,
                    splashFactory: NoSplash.splashFactory,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.fromLTRB(
                        28,
                        0,
                        AppSpacing.base,
                        0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: isSelected
                                  ? AppTextStyles.input.medium.natural
                                  : AppTextStyles.input.natural,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            AppPop(
                              onMount: true,
                              delay: const Duration(milliseconds: 300),
                              child: Icon(
                                AppIcons.checkBold,
                                size: AppSize.icon,
                                color: AppColors.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 날짜 휠 (시안 Tr-Reserve-Date): 카드 안 180 높이, 가운데 흰 띠(48 · 반경 14), 년 · 월 · 일 세 칸.
class _DateWheel extends StatelessWidget {
  final DateTime initial;
  final ValueChanged<DateTime> onChanged;

  const _DateWheel({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '날짜 휠',
      child: Container(
        height: 180,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 66,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
            Localizations.override(
              context: context,
              locale: const Locale('ko', 'KR'),
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: AppColors.isLight
                      ? Brightness.light
                      : Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: AppTextStyles.title.natural
                        .copyWith(color: AppColors.ink),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.ymd,
                  itemExtent: 36,
                  initialDateTime: initial,
                  minimumDate: DateTime(initial.year - 1),
                  // 마지막 날 23:59까지 — 그날 늦은 시각의 초기값이 최대값을 넘지 않게.
                  maximumDate: DateTime(
                    DateTime.now().year + 2,
                    12,
                    31,
                    23,
                    59,
                  ),
                  // 기본 회색 띠 대신 뒤에 그린 흰 띠를 쓴다.
                  selectionOverlayBuilder:
                      (
                        context, {
                        required columnCount,
                        required selectedIndex,
                      }) => null,
                  onDateTimeChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 카드 아래 휠 (시안 TrainerReserve): 180 높이, 가운데 회색 띠(48 · 반경 14), 칸 여러 개.
class _WheelBox extends StatelessWidget {
  final String semanticLabel;
  final List<Widget> columns;

  const _WheelBox({
    super.key,
    required this.semanticLabel,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 66,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.canvasCard,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
            Row(
              children: [for (final column in columns) Expanded(child: column)],
            ),
          ],
        ),
      ),
    );
  }
}

/// 휠 한 칸: 줄 36, 평평하게. 고른 값 22/700 ink, 이웃 18 faint, 그 너머 더 흐리게.
class _WheelColumn extends StatefulWidget {
  final List<String> labels;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  const _WheelColumn({
    required this.labels,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late int _selected = widget.initialIndex.clamp(0, widget.labels.length - 1);
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _selected);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _style(int index) {
    final distance = (index - _selected).abs();
    if (distance == 0) {
      return AppTextStyles.sheetTitle.bold.natural.copyWith(
        color: AppColors.ink,
      );
    }
    final base = AppTextStyles.bodyLg.natural.copyWith(fontSize: 18);
    return base.copyWith(
      color: distance == 1
          ? AppColors.faint
          : AppColors.faint.withValues(alpha: 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: _controller,
      itemExtent: 36,
      diameterRatio: 40,
      squeeze: 1,
      selectionOverlay: null,
      onSelectedItemChanged: (i) {
        setState(() => _selected = i);
        widget.onChanged(i);
      },
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          Center(child: Text(widget.labels[i], style: _style(i))),
      ],
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
