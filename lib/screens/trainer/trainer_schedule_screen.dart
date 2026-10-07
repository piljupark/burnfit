import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
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
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day + 7 * delta),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약 취소'),
        content: Text(
          '${session.memberName}님의 ${DateFormat('M월 d일 HH:mm', 'ko').format(session.scheduledAt)} 예약을 취소합니다.',
        ),
        actions: [
          AppButton(
            label: '닫기',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: '예약 취소',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
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
          AppMonthHeader(label: 'WORKOUTS', count: '${workouts.length}'),
          for (final workout in workouts) _WorkoutRow(workout: workout),
        ],
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadSessions,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              AppHero(
                eyebrow:
                    '${DateFormat('yyyy.MM').format(_selectedDay)} · WEEK ${_isoWeek(_selectedDay)}',
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
                  AppIconButton(
                    icon: AppIcons.add,
                    label: 'PT 예약 등록',
                    outlined: true,
                    onPressed: _createSession,
                  ),
                ],
              ),
              _WeekStrip(
                selectedDay: _selectedDay,
                hasPt: (day) =>
                    _sessions.any((s) => isSameDay(s.scheduledAt, day) && s.status != PtSessionStatus.cancelled) ||
                    _workouts.any((w) => w.workoutType == WorkoutType.pt && w.workoutDate == _dateKey(day)),
                hasPersonal: (day) => _workouts.any(
                  (w) => w.workoutType == WorkoutType.personal && w.workoutDate == _dateKey(day),
                ),
                onSelect: _selectDay,
                onPrevWeek: () => _moveWeek(-1),
                onNextWeek: () => _moveWeek(1),
              ),
              AppMonthHeader(
                label: DateFormat('MM.dd EEE', 'en_US').format(_selectedDay),
                count: '${sessions.length} ${sessions.length == 1 ? 'SESSION' : 'SESSIONS'}',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.base, AppSpacing.screenH, AppSpacing.sm,
                ),
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}

String _dateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

/// ISO 8601 주차 (월요일 시작).
int _isoWeek(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  return thursday.difference(firstDay).inDays ~/ 7 + 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// 주간 줄: 선택일 = 흰 원, 오늘 = 외곽선 원, PT = 채운 점, 개인운동 = 외곽선 점
// ─────────────────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final DateTime selectedDay;
  final bool Function(DateTime) hasPt;
  final bool Function(DateTime) hasPersonal;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  const _WeekStrip({
    required this.selectedDay,
    required this.hasPt,
    required this.hasPersonal,
    required this.onSelect,
    required this.onPrevWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final monday = DateTime(selectedDay.year, selectedDay.month, selectedDay.day - (selectedDay.weekday - 1));
    final now = DateTime.now();

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline))),
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
                AppIconButton(icon: AppIcons.back, label: '이전 주', onPressed: onPrevWeek, color: AppColors.body),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _WeekDayCell(
                      day: DateTime(monday.year, monday.month, monday.day + i),
                      weekdayLabel: weekdayLabels[i],
                      isSelected: isSameDay(DateTime(monday.year, monday.month, monday.day + i), selectedDay),
                      isToday: isSameDay(DateTime(monday.year, monday.month, monday.day + i), now),
                      hasPt: hasPt(DateTime(monday.year, monday.month, monday.day + i)),
                      hasPersonal: hasPersonal(DateTime(monday.year, monday.month, monday.day + i)),
                      onTap: onSelect,
                    ),
                  ),
                AppIconButton(icon: AppIcons.forward, label: '다음 주', onPressed: onNextWeek, color: AppColors.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
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
  final bool hasPt;
  final bool hasPersonal;
  final ValueChanged<DateTime> onTap;

  const _WeekDayCell({
    required this.day,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.hasPt,
    required this.hasPersonal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = [
      '${day.month}월 ${day.day}일 $weekdayLabel요일',
      if (isToday) '오늘',
      if (hasPt) 'PT 있음',
      if (hasPersonal) '개인운동 있음',
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
            Text(weekdayLabel, style: AppTextStyles.bodySm.copyWith(fontSize: 12, height: 16 / 12)),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: isToday && !isSelected ? Border.all(color: AppColors.ink) : null,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.bodyMd.copyWith(
                  color: isSelected ? AppColors.onPrimary : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasPt) const _Dot(filled: true, size: 4),
                  if (hasPt && hasPersonal) const SizedBox(width: 3),
                  if (hasPersonal) const _Dot(filled: false, size: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;
  final double size;

  const _Dot({required this.filled, this.size = 5});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.ink : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.ink),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final caption = AppTextStyles.bodySm.copyWith(fontSize: 12, height: 16 / 12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Dot(filled: true),
        const SizedBox(width: 6),
        Text('PT 예약·운동', style: caption),
        const SizedBox(width: AppSpacing.base),
        const _Dot(filled: false),
        const SizedBox(width: 6),
        Text('개인운동', style: caption),
      ],
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.hairline))),
      child: Column(
        children: [
          for (var hour = firstHour; hour <= lastHour; hour++)
            _HourRow(
              hour: hour,
              children: [
                for (final s in sessions.where((s) => s.scheduledAt.hour == hour))
                  _SessionBlock(
                    session: s,
                    onRecord: s.status == PtSessionStatus.scheduled ? () => onRecord(s) : null,
                    onManage: s.status == PtSessionStatus.scheduled ? () => onManage(s) : null,
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
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: AppTextStyles.counter.copyWith(fontSize: 12, height: 16 / 12),
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
    final meta = '${DateFormat('HH:mm').format(session.scheduledAt)} · ${session.durationMinutes}분';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          AppAvatar(name: session.memberName, seed: session.memberId, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.memberName, style: AppTextStyles.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xxs),
                Text(meta, style: AppTextStyles.bodySm.copyWith(color: AppColors.body)),
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
              child: AppTag('DONE', strong: true),
            ),
          if (onRecord != null)
            AppButton(
              label: '기록 시작',
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline))),
      child: Row(
        children: [
          AppAvatar(name: workout.memberName, seed: workout.memberId),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.memberName, style: AppTextStyles.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xxs),
                Text(detail, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
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
  static const List<int> _durationOptions = [30, 40, 50, 60, 70, 80, 90, 120];

  AppUser? _selectedMember;
  late DateTime _scheduledAt;
  int _durationMinutes = 60;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  bool _showMemberPicker = false;
  bool _showDatePicker = false;
  bool _showTimePicker = false;
  bool get _isEditing => widget.existing != null;

  List<int> get _durationValues {
    final values = [..._durationOptions];
    if (!values.contains(_durationMinutes)) {
      values.add(_durationMinutes);
      values.sort();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원을 선택해주세요.')));
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

  static const List<int> _hourOptions = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];

  void _togglePicker({bool member = false, bool date = false, bool time = false}) {
    setState(() {
      _showMemberPicker = member && !_showMemberPicker;
      _showDatePicker = date && !_showDatePicker;
      _showTimePicker = time && !_showTimePicker;
    });
  }

  /// 같은 날짜에 이미 잡힌 시각 (수정 중인 세션은 제외).
  Set<int> get _bookedMinutes {
    final existingId = widget.existing?.id;
    return {
      for (final s in widget.bookedSessions)
        if (s.id != existingId &&
            s.scheduledAt.year == _scheduledAt.year &&
            s.scheduledAt.month == _scheduledAt.month &&
            s.scheduledAt.day == _scheduledAt.day)
          s.scheduledAt.hour * 60 + s.scheduledAt.minute,
    };
  }

  void _setTime(int hour, int minute) {
    setState(() {
      _scheduledAt = DateTime(_scheduledAt.year, _scheduledAt.month, _scheduledAt.day, hour, minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final booked = _bookedMinutes;
    final currentMinutes = _scheduledAt.hour * 60 + _scheduledAt.minute;
    final timeOptions = {for (final h in _hourOptions) h * 60, currentMinutes}.toList()..sort();
    final memberName = _isEditing ? widget.existing!.memberName : _selectedMember?.name;
    final memberSeed = _isEditing ? widget.existing!.memberId : _selectedMember?.uid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(title: _isEditing ? 'PT 예약 수정' : 'PT 예약 등록'),

        // 회원
        const _FieldLabel(label: 'MEMBER'),
        _SelectField(
          semanticLabel: '회원 선택',
          leading: memberName == null ? null : AppAvatar(name: memberName, seed: memberSeed, size: 28),
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
        const _FieldLabel(label: 'DATE'),
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
                minimumDate: DateTime(2024),
                maximumDate: DateTime(2030),
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

        // 시간: 정시 칩 + 직접 입력(5분 단위)
        const _FieldLabel(label: 'TIME'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final minutes in timeOptions)
              AppChip(
                label: '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
                selected: minutes == currentMinutes,
                enabled: minutes == currentMinutes || !booked.contains(minutes),
                onTap: () {
                  _setTime(minutes ~/ 60, minutes % 60);
                  if (_showTimePicker) _togglePicker();
                },
              ),
            AppChip(
              label: '직접 입력',
              icon: AppIcons.clock,
              selected: false,
              onTap: () => _togglePicker(time: true),
            ),
          ],
        ),
        if (_showTimePicker)
          _PickerContainer(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _scheduledAt,
              use24hFormat: true,
              minuteInterval: 5,
              onDateTimeChanged: (dt) => _setTime(dt.hour, dt.minute),
            ),
          ),
        const SizedBox(height: AppSpacing.base),

        // 수업 시간
        const _FieldLabel(label: 'DURATION'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final minutes in _durationValues)
              AppChip(
                label: '$minutes분',
                selected: minutes == _durationMinutes,
                onTap: () => setState(() => _durationMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // 메모
        AppTextField(
          label: 'MEMO',
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
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시트 내 공용 위젯
// ─────────────────────────────────────────────────────────────────────────────

/// 영문 대문자 모노 필드 라벨 (MEMBER, DATE …).
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTextStyles.eyebrow),
    );
  }
}

/// 48 높이 선택 필드: canvasSoft + hairline (열린 상태는 흰 테두리).
class _SelectField extends StatelessWidget {
  final String semanticLabel;
  final Widget? leading;
  final String value;
  final bool isEmpty;
  final bool isActive;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SelectField({
    required this.semanticLabel,
    required this.value,
    required this.isActive,
    this.leading,
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
          side: BorderSide(color: isActive ? AppColors.ink : AppColors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.only(left: leading == null ? AppSpacing.base : AppSpacing.md, right: AppSpacing.xs),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.bodyMd.copyWith(color: isEmpty ? AppColors.mute : AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: trailingIcon == null
                        ? null
                        : Icon(trailingIcon, size: AppSize.icon, color: AppColors.body),
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

  const _MemberPickerList({required this.members, required this.selected, required this.onSelect});

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
                child: Text('담당 회원이 없습니다', style: AppTextStyles.bodySm.copyWith(color: AppColors.body)),
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
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Row(
                            children: [
                              AppAvatar(name: m.name, seed: m.uid, size: 28),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(m.name, style: AppTextStyles.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (isSelected) const Icon(AppIcons.check, size: AppSize.icon, color: AppColors.ink),
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
