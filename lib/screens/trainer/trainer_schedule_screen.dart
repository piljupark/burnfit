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
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/calendar_marks.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';
import 'trainer_pt_workout_screen.dart';

class TrainerScheduleScreen extends StatefulWidget {
  const TrainerScheduleScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// 알림 등으로 탭에 들어올 때 최신 일정을 다시 불러온다.
  void refresh() => _loadSessions();

  Future<void> _loadSessions() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final loadId = ++_sessionsLoadId;
    setState(() => _isLoading = true);
    try {
      final focusedDay = _focusedDay;
      final from = DateTime(focusedDay.year, focusedDay.month, 1);
      final to = DateTime(focusedDay.year, focusedDay.month + 1, 0, 23, 59, 59);
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
      final workoutResults = await Future.wait(
        members.map(
          (member) =>
              WorkoutService.getWorkoutsByDateRange(
                user.centerId,
                member.uid,
                DateFormat('yyyy-MM-dd').format(from),
                DateFormat('yyyy-MM-dd').format(to),
              ).catchError((error) {
                AppLogger.debug('[회원 운동 기록 조회 제외] ${member.uid}: $error');
                return <Workout>[];
              }),
        ),
      ).timeout(const Duration(seconds: 12));
      if (!mounted || loadId != _sessionsLoadId) return;
      setState(() {
        _sessions = initialResults[0] as List<PtSession>;
        _members = members;
        _workouts = workoutResults.expand((result) => result).toList();
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

  /// 예약 세션의 수정·취소 시트.
  Future<void> _showSessionActions(PtSession session) async {
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
            ),
            AppSheetAction(
              icon: AppIcons.edit,
              label: '예약 수정',
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

    if (result != null) {
      setState(() => _sessions.add(result));
    }
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
    await _loadSessions();
  }

  Future<void> _cancelSession(PtSession session) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: '예약 취소',
      message:
          '${session.memberName}님의 ${DateFormat('M월 d일 HH:mm', 'ko').format(session.scheduledAt)} 예약을 취소합니다.',
      confirmLabel: '예약 취소',
      cancelLabel: '닫기',
    );
    if (confirm != true) return;

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
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _selectedSessions;
    final workouts = _selectedWorkouts;
    final canPop = Navigator.of(context).canPop();

    final List<Widget> content;
    if (_isLoading) {
      content = const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
          child: Center(child: OrbLoader.screen()),
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
      content = [
        AppEmptyState(
          icon: AppIcons.calendar,
          message: isSameDay(_selectedDay, DateTime.now())
              ? '오늘 예약이 없습니다.'
              : '이 날 예약이 없습니다.',
        ),
      ];
    } else {
      content = [
        if (sessions.isNotEmpty)
          _SessionTimeline(
            sessions: sessions,
            onRecord: _openPtWorkout,
            onManage: _showSessionActions,
          ),
        if (workouts.isNotEmpty) ...[
          if (sessions.isNotEmpty)
            Container(height: AppSpacing.sm, color: AppColors.canvasCard),
          AppMonthHeader(label: '운동 기록', count: '${workouts.length}'),
          for (final workout in workouts) _WorkoutRow(workout: workout),
        ],
      ];
    }

    // 떠 있는 'PT 예약 등록' 버튼 위치: 탭 화면이면 하단 탭(56 + 기기 아래 여백) 위, 단독 화면이면 기기 아래 여백 위.
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
                      AppHero(
                        title: 'PT 일정',
                        actions: [
                          if (canPop) ...[
                            AppIconButton(
                              icon: AppIcons.back,
                              label: '뒤로',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                          ],
                        ],
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
                      AppMonthHeader(
                        label: DateFormat(
                          'M월 d일 (E)',
                          'ko',
                        ).format(_selectedDay),
                        count: '${sessions.length}건',
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.base,
                          AppSpacing.screenH,
                          AppSpacing.sm,
                        ),
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
              label: 'PT 예약 등록',
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

// ─────────────────────────────────────────────────────────────────────────────
// 주간 줄: 선택일 = 흰 원, 오늘 = 외곽선 원, 아래 표시 = CalendarMarkRow
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
    final monday = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day - (selectedDay.weekday - 1),
    );
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v > 200) onPrevWeek();
              if (v < -200) onNextWeek();
            },
            child: Row(
              children: [
                AppIconButton(
                  icon: AppIcons.back,
                  label: '이전 주',
                  onPressed: onPrevWeek,
                  color: AppColors.body,
                ),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _WeekDayCell(
                      day: DateTime(monday.year, monday.month, monday.day + i),
                      weekdayLabel: weekdayLabels[i],
                      isSelected: isSameDay(
                        DateTime(monday.year, monday.month, monday.day + i),
                        selectedDay,
                      ),
                      isToday: isSameDay(
                        DateTime(monday.year, monday.month, monday.day + i),
                        now,
                      ),
                      marks:
                          marks[DateFormat('yyyy-MM-dd').format(
                            DateTime(monday.year, monday.month, monday.day + i),
                          )] ??
                          const <CalendarMark>{},
                      onTap: onSelect,
                    ),
                  ),
                AppIconButton(
                  icon: AppIcons.forward,
                  label: '다음 주',
                  onPressed: onNextWeek,
                  color: AppColors.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const CalendarLegend(alignment: MainAxisAlignment.center),
        ],
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  final DateTime day;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final Set<CalendarMark> marks;
  final ValueChanged<DateTime> onTap;

  const _WeekDayCell({
    required this.day,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.marks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = [
      '${day.month}월 ${day.day}일 $weekdayLabel요일',
      if (isToday) '오늘',
      if (marks.isNotEmpty) calendarMarksSemantics(marks),
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: semantic,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(day),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayLabel,
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.ink : Colors.transparent,
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.ink)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.bodyMd.copyWith(
                  color: isSelected ? AppColors.canvas : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CalendarMarkRow(marks),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시간대별 타임라인: 모노 시각 열(44) + hairline 구분 + 세션 블록
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTimeline extends StatelessWidget {
  final List<PtSession> sessions;
  final ValueChanged<PtSession> onRecord;
  final ValueChanged<PtSession> onManage;

  const _SessionTimeline({
    required this.sessions,
    required this.onRecord,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    // sessions는 시간순으로 정렬돼 있다. 첫 세션 시각부터 마지막 세션 시각까지 빈 시간도 줄로 보여 준다.
    final firstHour = sessions.first.scheduledAt.hour;
    final lastHour = sessions.last.scheduledAt.hour;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        children: [
          for (var hour = firstHour; hour <= lastHour; hour++)
            _HourRow(
              hour: hour,
              children: [
                for (final s in sessions.where(
                  (s) => s.scheduledAt.hour == hour,
                ))
                  _SessionBlock(
                    session: s,
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

  const _HourRow({required this.hour, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.listRow),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: AppTextStyles.counter.copyWith(
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBlock extends StatelessWidget {
  final PtSession session;

  /// 예약 상태에서만 (완료 세션은 null).
  final VoidCallback? onRecord;
  final VoidCallback? onManage;

  const _SessionBlock({required this.session, this.onRecord, this.onManage});

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == PtSessionStatus.completed;
    final note = session.note;
    final meta =
        '${DateFormat('HH:mm').format(session.scheduledAt)} · ${session.durationMinutes}분';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      // 완료 = 회색 면, 예약 = 흰 면 + 강조색 테두리 (모양으로도 구분).
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.canvasCard : AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: isCompleted
            ? null
            : Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.memberName,
                  style: AppTextStyles.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  meta,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    '메모: $note',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isCompleted)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: AppTag('완료', strong: true),
            ),
          if (onRecord != null)
            AppButton(
              label: isCompleted ? '기록 보기' : '기록 시작',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              onPressed: onRecord,
            ),
          if (onManage != null)
            AppIconButton(
              icon: AppIcons.more,
              label: '${session.memberName} 예약 수정·취소',
              onPressed: onManage,
              color: AppColors.body,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 회원 운동 기록 행 (보기 전용)
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutRow extends StatelessWidget {
  final Workout workout;

  const _WorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isPtWorkout = workout.workoutType == WorkoutType.pt;
    final detail = [
      isPtWorkout ? 'PT 운동' : '개인 운동',
      '${workout.category.label} 운동',
      '${workout.totalSets}세트',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.memberName,
                  style: AppTextStyles.bodyLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  style: AppTextStyles.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isPtWorkout) const AppTag('PT'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PT 예약 바텀시트
// ─────────────────────────────────────────────────────────────────────────────

class _SessionSheet extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String centerId;
  final List<AppUser> members;
  final DateTime initialDate;
  final PtSession? existing;

  /// 취소되지 않은 기존 세션. 같은 날짜·시각에 이미 있는 시간 칩을 흐리게 표시한다.
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

  AppUser? _selectedMember;
  late DateTime _scheduledAt;
  int _durationMinutes = 60;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  bool _showMemberPicker = false;
  bool _showDatePicker = false;
  bool _showTimePicker = false;
  bool _showDurationPicker = false;
  bool get _isEditing => widget.existing != null;

  List<int> get _durationValues {
    final values = [
      for (var m = _durationStep; m <= _durationMax; m += _durationStep) m,
    ];
    if (!values.contains(_durationMinutes)) {
      values
        ..add(_durationMinutes)
        ..sort();
    }
    return values;
  }

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
      _scheduledAt = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        10,
        0,
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_isEditing && _selectedMember == null) {
      AppFeedback.showWarning(context, '회원을 선택해주세요.');
      return;
    }
    final conflict = _conflict;
    if (conflict != null) {
      AppFeedback.showWarning(context, _conflictMessage(conflict));
      return;
    }
    setState(() => _isSaving = true);
    try {
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

  void _togglePicker({
    bool member = false,
    bool date = false,
    bool time = false,
    bool duration = false,
  }) {
    setState(() {
      _showMemberPicker = member && !_showMemberPicker;
      _showDatePicker = date && !_showDatePicker;
      _showTimePicker = time && !_showTimePicker;
      _showDurationPicker = duration && !_showDurationPicker;
    });
  }

  /// 선택한 시간대(시작~시작+진행 시간)와 겹치는 다른 예약. 수정 중인 세션·취소된 예약은 제외.
  PtSession? get _conflict {
    final existingId = widget.existing?.id;
    final start = _scheduledAt;
    final end = start.add(Duration(minutes: _durationMinutes));
    for (final s in widget.bookedSessions) {
      if (s.id == existingId || s.status == PtSessionStatus.cancelled) continue;
      final otherEnd = s.scheduledAt.add(Duration(minutes: s.durationMinutes));
      if (start.isBefore(otherEnd) && s.scheduledAt.isBefore(end)) return s;
    }
    return null;
  }

  String _conflictMessage(PtSession other) {
    final f = DateFormat('HH:mm');
    final end = other.scheduledAt.add(Duration(minutes: other.durationMinutes));
    return '이 시간에 ${other.memberName}님 PT가 있어요 (${f.format(other.scheduledAt)}–${f.format(end)})';
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
    final endAt = _scheduledAt.add(Duration(minutes: _durationMinutes));
    final memberName = _isEditing
        ? widget.existing!.memberName
        : _selectedMember?.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(title: _isEditing ? 'PT 예약 수정' : 'PT 예약 등록'),

        // 회원
        const _FieldLabel(label: '회원'),
        _SelectField(
          semanticLabel: '회원 선택',
          value: memberName ?? '회원을 선택하세요',
          isEmpty: memberName == null,
          isActive: _showMemberPicker,
          trailingIcon: _isEditing
              ? null
              : _showMemberPicker
              ? AppIcons.chevronUp
              : AppIcons.chevronDown,
          onTap: _isEditing ? null : () => _togglePicker(member: true),
        ),
        if (!_isEditing && _showMemberPicker)
          _MemberPickerList(
            members: widget.members,
            selected: _selectedMember,
            onSelect: (m) => setState(() {
              _selectedMember = m;
              _showMemberPicker = false;
            }),
          ),
        const SizedBox(height: AppSpacing.base),

        // 날짜
        const _FieldLabel(label: '날짜'),
        _SelectField(
          semanticLabel: '날짜 선택',
          value: DateFormat('M월 d일 (E)', 'ko').format(_scheduledAt),
          isActive: _showDatePicker,
          trailingIcon: AppIcons.calendar,
          onTap: () => _togglePicker(date: true),
        ),
        if (_showDatePicker)
          _PickerContainer(
            child: Localizations.override(
              context: context,
              locale: const Locale('ko', 'KR'),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                dateOrder: DatePickerDateOrder.ymd,
                initialDateTime: _scheduledAt,
                minimumDate: DateTime(_scheduledAt.year - 1),
                maximumDate: DateTime(DateTime.now().year + 2, 12, 31),
                onDateTimeChanged: (dt) => setState(() {
                  _scheduledAt = DateTime(
                    dt.year,
                    dt.month,
                    dt.day,
                    _scheduledAt.hour,
                    _scheduledAt.minute,
                  );
                }),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.base),

        // 시간: 선택 칸 → 휠 (5분 단위)
        const _FieldLabel(label: '시간'),
        _SelectField(
          semanticLabel: '시작 시간 선택',
          value: DateFormat('a h:mm', 'ko').format(_scheduledAt),
          isActive: _showTimePicker,
          trailingIcon: AppIcons.clock,
          onTap: () => _togglePicker(time: true),
        ),
        if (_showTimePicker)
          _PickerContainer(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _scheduledAt.copyWith(
                minute: _scheduledAt.minute - _scheduledAt.minute % 5,
              ),
              use24hFormat: false,
              minuteInterval: 5,
              onDateTimeChanged: (dt) => _setTime(dt.hour, dt.minute),
            ),
          ),
        const SizedBox(height: AppSpacing.base),

        // 진행 시간: 선택 칸 → 휠 (10분 단위)
        const _FieldLabel(label: '진행 시간'),
        _SelectField(
          semanticLabel: '진행 시간 선택',
          value:
              '$_durationMinutes분 · ${DateFormat('a h:mm', 'ko').format(endAt)} 종료',
          isActive: _showDurationPicker,
          trailingIcon: _showDurationPicker
              ? AppIcons.chevronUp
              : AppIcons.chevronDown,
          onTap: () => _togglePicker(duration: true),
        ),
        if (_showDurationPicker)
          _PickerContainer(
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController: FixedExtentScrollController(
                initialItem: _durationValues.indexOf(_durationMinutes),
              ),
              onSelectedItemChanged: (i) =>
                  setState(() => _durationMinutes = _durationValues[i]),
              children: [
                for (final minutes in _durationValues)
                  Center(child: Text('$minutes분', style: AppTextStyles.title)),
              ],
            ),
          ),
        if (conflict != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppInlineNotice(_conflictMessage(conflict)),
        ],
        const SizedBox(height: AppSpacing.base),

        // 메모
        AppTextField(
          label: '메모',
          hint: '선택 사항',
          controller: _noteController,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: _isEditing ? '예약 수정' : '예약 등록',
          size: AppButtonSize.lg,
          fullWidth: true,
          isLoading: _isSaving,
          // 다른 예약과 겹치면 저장할 수 없다 (위에 안내 문구).
          onPressed: _isSaving || conflict != null ? null : _save,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시트 내 공용 위젯
// ─────────────────────────────────────────────────────────────────────────────

/// 모노 필드 라벨 (회원, 날짜 …).
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTextStyles.bodySm),
    );
  }
}

/// 48 높이 선택 필드: canvasSoft + hairline (열린 상태는 흰 테두리).
class _SelectField extends StatelessWidget {
  final String semanticLabel;
  final String value;
  final bool isEmpty;
  final bool isActive;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SelectField({
    required this.semanticLabel,
    required this.value,
    required this.isActive,
    this.isEmpty = false,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      expanded: onTap != null ? isActive : null,
      label: '$semanticLabel, $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.canvasSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isActive ? AppColors.ink : AppColors.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.base,
                right: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: isEmpty ? AppColors.mute : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: trailingIcon == null
                        ? null
                        : Icon(
                            trailingIcon,
                            size: AppSize.icon,
                            color: AppColors.body,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 224),
        decoration: BoxDecoration(
          color: AppColors.canvasSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: members.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Text(
                  '담당 회원이 없습니다',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: members.length,
                separatorBuilder: (_, _) => const AppRowDivider(),
                itemBuilder: (context, i) {
                  final m = members[i];
                  final isSelected = selected?.uid == m.uid;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    child: InkWell(
                      onTap: () => onSelect(m),
                      splashFactory: NoSplash.splashFactory,
                      child: SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  style: AppTextStyles.bodyMd,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  AppIcons.check,
                                  size: AppSize.icon,
                                  color: AppColors.ink,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PickerContainer extends StatelessWidget {
  final Widget child;

  const _PickerContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.canvasSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Brightness.dark,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: AppTextStyles.title,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
