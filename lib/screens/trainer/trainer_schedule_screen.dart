import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_section.dart';
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

  Future<void> _createSession() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    final result = await showModalBottomSheet<PtSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionSheet(
        trainerId: trainer.uid,
        trainerName: trainer.name,
        centerId: trainer.centerId,
        members: _members,
        initialDate: _selectedDay,
      ),
    );

    if (result != null) {
      setState(() => _sessions.add(result));
    }
  }

  Future<void> _editSession(PtSession session) async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    final result = await showModalBottomSheet<PtSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionSheet(
        trainerId: trainer.uid,
        trainerName: trainer.name,
        centerId: trainer.centerId,
        members: _members,
        initialDate: session.scheduledAt,
        existing: session,
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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        title: Text('예약 취소', style: AppTextStyles.h3),
        content: Text(
          '${session.memberName}님의 예약을 취소하시겠습니까?',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '닫기',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '취소',
              style: AppTextStyles.body.copyWith(
                color: AppColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop()) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                  ],
                  Expanded(child: Text('PT 일정', style: AppTextStyles.h1)),
                  GestureDetector(
                    onTap: _createSession,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 캘린더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: TableCalendar<PtSession>(
              firstDay: DateTime(2024),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() {
                  _focusedDay = focused;
                  if (_selectedDay.year != focused.year ||
                      _selectedDay.month != focused.month) {
                    _selectedDay = DateTime(focused.year, focused.month, 1);
                  }
                });
                _loadSessions();
              },
              eventLoader: (day) => _sessions
                  .where(
                    (s) =>
                        isSameDay(s.scheduledAt, day) &&
                        s.status == PtSessionStatus.scheduled,
                  )
                  .toList(),
              calendarBuilders: CalendarBuilders<PtSession>(
                markerBuilder: (context, day, reservations) {
                  final dateKey = DateFormat('yyyy-MM-dd').format(day);
                  final hasPersonalWorkout = _workouts.any(
                    (item) =>
                        item.workoutDate == dateKey &&
                        item.workoutType == WorkoutType.personal,
                  );
                  final hasPtWorkout = _workouts.any(
                    (item) =>
                        item.workoutDate == dateKey &&
                        item.workoutType == WorkoutType.pt,
                  );
                  final hasReservation = reservations.isNotEmpty;
                  if (!hasPersonalWorkout && !hasPtWorkout && !hasReservation) {
                    return null;
                  }
                  return Positioned(
                    bottom: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPersonalWorkout)
                          const _CalendarMarker(
                            color: AppColors.workout,
                          ),
                        if (hasPersonalWorkout && hasPtWorkout) const Gap(3),
                        if (hasPtWorkout)
                          const _CalendarMarker(
                            color: AppColors.trainer,
                          ),
                        if ((hasPersonalWorkout || hasPtWorkout) &&
                            hasReservation)
                          const Gap(3),
                        if (hasReservation)
                          const _CalendarMarker(
                            color: AppColors.brand,
                          ),
                      ],
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brand),
                ),
                todayTextStyle: AppTextStyles.body.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                markerSize: 5,
                defaultTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                weekendTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textPrimary,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: _ScheduleLegend(),
          ),
          // 구분선
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              0,
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('M월 d일 EEEE', 'ko').format(_selectedDay),
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedSessions.length + _selectedWorkouts.length}건',
                  style: AppTextStyles.label.copyWith(
                    color:
                        _selectedSessions.isEmpty && _selectedWorkouts.isEmpty
                        ? AppColors.textDisabled
                        : AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.xs),
          // 세션 리스트
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brand,
                    ),
                  )
                : _errorMessage != null
                ? AppErrorCard(message: _errorMessage!, onRetry: _loadSessions)
                : _selectedSessions.isEmpty && _selectedWorkouts.isEmpty
                ? AppEmptyState(
                    icon: Icons.calendar_today_outlined,
                    message: isSameDay(_selectedDay, DateTime.now())
                        ? '오늘 예약이 없습니다.'
                        : '이 날 예약이 없습니다.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xs,
                      AppSpacing.screenH,
                      AppSpacing.xl2,
                    ),
                    children: [
                      for (final s in _selectedSessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _SessionCard(
                            session: s,
                            onRecord: s.status == PtSessionStatus.scheduled
                                ? () => _openPtWorkout(s)
                                : null,
                            onEdit: s.status == PtSessionStatus.scheduled
                                ? () => _editSession(s)
                                : null,
                            onCancel: s.status == PtSessionStatus.scheduled
                                ? () => _cancelSession(s)
                                : null,
                          ),
                        ),
                      for (final workout in _selectedWorkouts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _WorkoutCalendarCard(workout: workout),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleLegend extends StatelessWidget {
  const _ScheduleLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        _ScheduleLegendItem(
          color: AppColors.workout,
          label: '개인 운동',
        ),
        _ScheduleLegendItem(
          color: AppColors.trainer,
          label: 'PT 운동',
        ),
        _ScheduleLegendItem(color: AppColors.brand, label: 'PT 예약'),
      ],
    );
  }
}

class _ScheduleLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ScheduleLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarMarker(color: color),
        const Gap(4),
        Text(
          label,
          style: AppTextStyles.captionSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _CalendarMarker extends StatelessWidget {
  final Color color;

  const _CalendarMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _WorkoutCalendarCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCalendarCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isPtWorkout = workout.workoutType == WorkoutType.pt;
    final color = isPtWorkout
        ? AppColors.trainer
        : AppColors.workout;
    final label = isPtWorkout ? 'PT 운동' : '개인 운동';
    final detail = [
      '${workout.category.label} 운동',
      '${workout.totalSets}세트',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${workout.memberName} · $label',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Gap(3),
                Text(
                  detail,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 세션 카드
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final PtSession session;
  final VoidCallback? onRecord;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const _SessionCard({
    required this.session,
    this.onRecord,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(session.scheduledAt);
    final isCompleted = session.status == PtSessionStatus.completed;
    final barColor = isCompleted
        ? AppColors.workout
        : AppColors.brand;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: AppTextStyles.label.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        '${session.durationMinutes}분',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const Spacer(),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.workout.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '완료',
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.workout,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    session.memberName,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (session.note != null && session.note!.isNotEmpty) ...[
                    const Gap(3),
                    Text(
                      session.note!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (onRecord != null ||
                      onEdit != null ||
                      onCancel != null) ...[
                    const Gap(AppSpacing.sm),
                    Row(
                      children: [
                        if (onRecord != null)
                          GestureDetector(
                            onTap: onRecord,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                              child: Text(
                                '기록 시작',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textOnAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (onRecord != null && onEdit != null)
                          const Gap(AppSpacing.xs),
                        if (onEdit != null)
                          GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                              child: Text(
                                '수정',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (onEdit != null && onCancel != null)
                          const Gap(AppSpacing.xs),
                        if (onCancel != null)
                          GestureDetector(
                            onTap: onCancel,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.destructive,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

  const _SessionSheet({
    required this.trainerId,
    required this.trainerName,
    required this.centerId,
    required this.members,
    required this.initialDate,
    this.existing,
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
  bool _showDurationPicker = false;
  bool get _isEditing => widget.existing != null;

  List<int> get _durationValues {
    final values = [..._durationOptions];
    if (!values.contains(_durationMinutes)) {
      values.add(_durationMinutes);
      values.sort();
    }
    return values;
  }

  int get _durationInitialIndex {
    final index = _durationValues.indexOf(_durationMinutes);
    return index < 0 ? 0 : index;
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Text(
            _isEditing ? 'PT 예약 수정' : 'PT 예약 등록',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(AppSpacing.lg),

          // 회원 선택
          _FieldLabel(label: '회원'),
          const Gap(AppSpacing.xs),
          _PickerField(
            icon: Icons.person_outline_rounded,
            value: _isEditing
                ? widget.existing!.memberName
                : _selectedMember?.name ?? '회원을 선택하세요',
            isEmpty: !_isEditing && _selectedMember == null,
            isExpanded: _showMemberPicker,
            onTap: _isEditing
                ? () {}
                : () => setState(() {
                    _showMemberPicker = !_showMemberPicker;
                    _showDatePicker = false;
                    _showTimePicker = false;
                    _showDurationPicker = false;
                  }),
          ),
          if (!_isEditing && _showMemberPicker && widget.members.isNotEmpty)
            _PickerContainer(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedMember == null
                      ? 0
                      : widget.members
                            .indexOf(_selectedMember!)
                            .clamp(0, widget.members.length - 1),
                ),
                itemExtent: 44,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: AppColors.brand.withValues(
                    alpha: 0.15,
                  ),
                ),
                onSelectedItemChanged: (i) =>
                    setState(() => _selectedMember = widget.members[i]),
                children: widget.members
                    .map(
                      (m) => Center(
                        child: Text(m.name, style: AppTextStyles.body),
                      ),
                    )
                    .toList(),
              ),
            ),
          const Gap(AppSpacing.md),

          // 날짜 + 시간 (가로 배치)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: '날짜'),
                    const Gap(AppSpacing.xs),
                    _PickerField(
                      icon: Icons.calendar_today_outlined,
                      value: DateFormat('M월 d일 (E)', 'ko').format(_scheduledAt),
                      isExpanded: _showDatePicker,
                      onTap: () => setState(() {
                        _showDatePicker = !_showDatePicker;
                        _showTimePicker = false;
                        _showDurationPicker = false;
                        _showMemberPicker = false;
                      }),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: '시간'),
                    const Gap(AppSpacing.xs),
                    _PickerField(
                      icon: Icons.access_time_rounded,
                      value: DateFormat('HH:mm').format(_scheduledAt),
                      isExpanded: _showTimePicker,
                      onTap: () => setState(() {
                        _showTimePicker = !_showTimePicker;
                        _showDatePicker = false;
                        _showDurationPicker = false;
                        _showMemberPicker = false;
                      }),
                    ),
                  ],
                ),
              ),
            ],
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
          if (_showTimePicker)
            _PickerContainer(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _scheduledAt,
                use24hFormat: true,
                minuteInterval: 5,
                onDateTimeChanged: (dt) => setState(() {
                  _scheduledAt = DateTime(
                    _scheduledAt.year,
                    _scheduledAt.month,
                    _scheduledAt.day,
                    dt.hour,
                    dt.minute,
                  );
                }),
              ),
            ),
          const Gap(AppSpacing.md),

          _FieldLabel(label: '수업 시간'),
          const Gap(AppSpacing.xs),
          _PickerField(
            icon: Icons.timer_outlined,
            value: '$_durationMinutes분',
            isExpanded: _showDurationPicker,
            onTap: () => setState(() {
              _showDurationPicker = !_showDurationPicker;
              _showDatePicker = false;
              _showTimePicker = false;
              _showMemberPicker = false;
            }),
          ),
          if (_showDurationPicker)
            _PickerContainer(
              child: Builder(
                builder: (context) {
                  final durationValues = _durationValues;
                  return CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: _durationInitialIndex,
                    ),
                    itemExtent: 44,
                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                      background: AppColors.brand.withValues(
                        alpha: 0.15,
                      ),
                    ),
                    onSelectedItemChanged: (i) =>
                        setState(() => _durationMinutes = durationValues[i]),
                    children: durationValues
                        .map(
                          (minutes) => Center(
                            child: Text('$minutes분', style: AppTextStyles.body),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          const Gap(AppSpacing.md),

          // 메모
          _FieldLabel(label: '메모'),
          const Gap(AppSpacing.xs),
          TextField(
            controller: _noteController,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: '선택 사항',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textDisabled,
              ),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(
                  color: AppColors.brand,
                  width: 1,
                ),
              ),
            ),
          ),
          const Gap(AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor: AppColors.brand.withValues(
                  alpha: 0.35,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : Text(
                      _isEditing ? '예약 수정' : '예약 등록',
                      style: AppTextStyles.headline.copyWith(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시트 내 공용 위젯
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.captionSmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool isExpanded;
  final bool isEmpty;
  final VoidCallback onTap;

  const _PickerField({
    required this.icon,
    required this.value,
    required this.isExpanded,
    required this.onTap,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: isExpanded
                ? AppColors.brand
                : AppColors.border,
            width: isExpanded ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textTertiary),
            const Gap(AppSpacing.xs),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isEmpty
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 15,
              color: AppColors.textTertiary,
            ),
          ],
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
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: child,
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
