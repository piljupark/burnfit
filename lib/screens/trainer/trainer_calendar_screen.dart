import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/notification_bell_button.dart';
import 'trainer_member_detail_screen.dart';
import 'trainer_pt_workout_screen.dart';

class TrainerCalendarScreen extends StatefulWidget {
  final bool showGreeting;

  const TrainerCalendarScreen({super.key, this.showGreeting = false});

  @override
  State<TrainerCalendarScreen> createState() => TrainerCalendarScreenState();
}

class TrainerCalendarScreenState extends State<TrainerCalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  List<AppUser> _members = [];
  List<Workout> _workouts = [];
  List<PtSession> _ptSessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadId = 0;

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

    final loadId = ++_loadId;
    setState(() => _isLoading = true);

    try {
      final focusedMonth = _focusedMonth;
      final start = DateTime(focusedMonth.year, focusedMonth.month);
      final end = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
      final startKey = _key(start);
      final endKey = _key(end);

      final members = await FirestoreService.getMembersByTrainer(user.centerId, user.uid);

      if (!mounted || loadId != _loadId) return;

      final results = await Future.wait([
        Future.wait(
          members.isEmpty
              ? <Future<List<Workout>>>[]
              : members.map(
                  (m) => WorkoutService.getWorkoutsByDateRange(
                    user.centerId,
                    m.uid,
                    startKey,
                    endKey,
                  ),
                ),
        ),
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: start,
          to: DateTime(focusedMonth.year, focusedMonth.month + 1, 0, 23, 59, 59),
        ),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted || loadId != _loadId) return;

      final allWorkouts =
          (results[0] as List<List<Workout>>).expand((l) => l).toList();
      final ptSessions = results[1] as List<PtSession>;

      setState(() {
        _members = members;
        _workouts = allWorkouts;
        _ptSessions =
            ptSessions.where((s) => s.status != PtSessionStatus.cancelled).toList();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted && loadId == _loadId) setState(() => _isLoading = false);
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
    return _workouts
        .where((w) => w.workoutDate == key && w.workoutType == WorkoutType.personal)
        .toList();
  }

  List<PtSession> get _selectedPtSessions {
    return _ptSessions
        .where((s) => _sameDate(s.scheduledAt, _selectedDay))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Map<String, int> get _personalCountByDay {
    final map = <String, int>{};
    for (final w in _workouts.where((w) => w.workoutType == WorkoutType.personal)) {
      map[w.workoutDate] = (map[w.workoutDate] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _ptCountByDay {
    final map = <String, int>{};
    for (final s in _ptSessions) {
      final key = _key(s.scheduledAt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadMonth,
          color: AppColors.brand,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showGreeting)
                        _TrainerGreetingHeader(
                          user: context.watch<UserProvider>().user,
                        )
                      else
                        Text('캘린더', style: AppTextStyles.h1),
                      const Gap(16),
                      _MonthHeader(
                        month: _focusedMonth,
                        onPrev: () => _moveMonth(-1),
                        onNext: () => _moveMonth(1),
                      ),
                      const Gap(16),
                      _TrainerCalendarGrid(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        personalCountByDay: _personalCountByDay,
                        ptCountByDay: _ptCountByDay,
                        onSelect: (day) => setState(() => _selectedDay = day),
                      ),
                      const Gap(20),
                      Text(
                        DateFormat('M월 d일 (E)', 'ko').format(_selectedDay),
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(12),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.brand),
                          ),
                        )
                      else if (_errorMessage != null)
                        AppErrorCard(message: _errorMessage!, onRetry: _loadMonth)
                      else
                        _DayRecords(
                          workouts: _selectedWorkouts,
                          ptSessions: _selectedPtSessions,
                          members: _members,
                          onPtTap: (session) async {
                            final member = _members
                                .where((m) => m.uid == session.memberId)
                                .firstOrNull;
                            if (member == null) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrainerPtWorkoutScreen(
                                  session: session,
                                  member: member,
                                ),
                              ),
                            );
                            _loadMonth();
                          },
                          onMemberTap: (member) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrainerMemberDetailScreen(member: member),
                              ),
                            );
                          },
                        ),
                      const Gap(120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 인사 헤더
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerGreetingHeader extends StatelessWidget {
  final dynamic user;

  const _TrainerGreetingHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '${user?.name ?? ''} 트레이너님',
            style: AppTextStyles.h1,
          ),
        ),
        const NotificationBellButton(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 월 헤더
// ─────────────────────────────────────────────────────────────────────────────

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MonthButton(icon: Iconsax.arrow_square_left, onTap: onPrev),
        const Gap(12),
        Text(
          DateFormat('yyyy년 M월', 'ko').format(month),
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(12),
        Transform.rotate(
          angle: 3.14159,
          child: _MonthButton(icon: Iconsax.arrow_square_left, onTap: onNext),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: const Color(0xFF111111)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 트레이너용 캘린더 그리드
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerCalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, int> personalCountByDay;
  final Map<String, int> ptCountByDay;
  final ValueChanged<DateTime> onSelect;

  const _TrainerCalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.personalCountByDay,
    required this.ptCountByDay,
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
    final totalCells = cells <= 35 ? 35 : 42;

    return Column(
      children: [
        Row(
          children: weekdayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const Gap(6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 58,
            crossAxisSpacing: 4,
            mainAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > lastDay.day) {
              return const SizedBox.shrink();
            }

            final day = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
            final key = _key(day);
            final isToday = _sameDate(day, DateTime.now());
            final isSelected = _sameDate(day, selectedDay);
            final personalCount = personalCountByDay[key] ?? 0;
            final ptCount = ptCountByDay[key] ?? 0;

            return GestureDetector(
              onTap: () => onSelect(day),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand
                          : isToday
                              ? AppColors.brand.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? AppColors.brand
                                : AppColors.textPrimary,
                        fontWeight: (isToday || isSelected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const Gap(2),
                  SizedBox(
                    height: 24,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (personalCount > 0)
                          _CalendarLabel(
                            label: '개인운동 $personalCount건',
                            color: AppColors.brand,
                          ),
                        if (ptCount > 0) ...[
                          if (personalCount > 0) const Gap(1),
                          _CalendarLabel(
                            label: 'PT $ptCount건',
                            color: AppColors.destructive,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _CalendarLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'WantedSans',
        fontSize: 8,
        color: color,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 선택된 날짜 기록
// ─────────────────────────────────────────────────────────────────────────────

class _DayRecords extends StatelessWidget {
  final List<Workout> workouts;
  final List<PtSession> ptSessions;
  final List<AppUser> members;
  final void Function(PtSession) onPtTap;
  final void Function(AppUser) onMemberTap;

  const _DayRecords({
    required this.workouts,
    required this.ptSessions,
    required this.members,
    required this.onPtTap,
    required this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty && ptSessions.isEmpty) {
      return AppCard(
        hasShadow: true,
        hasBorder: false,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            '이 날의 기록이 없습니다',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final session in ptSessions) ...[
          _PtSessionCard(
            session: session,
            onTap: session.status == PtSessionStatus.scheduled
                ? () => onPtTap(session)
                : null,
          ),
          const Gap(12),
        ],
        for (final workout in workouts) ...[
          _WorkoutCard(
            workout: workout,
            onTap: () {
              final member =
                  members.where((m) => m.uid == workout.memberId).firstOrNull;
              if (member != null) onMemberTap(member);
            },
          ),
          const Gap(12),
        ],
      ],
    );
  }
}

class _PtSessionCard extends StatelessWidget {
  final PtSession session;
  final VoidCallback? onTap;

  const _PtSessionCard({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == PtSessionStatus.completed;
    final timeStr = DateFormat('a h:mm', 'ko').format(session.scheduledAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            AppIconBox(icon: Iconsax.activity, color: AppColors.destructive, size: 40),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PT · ${session.memberName}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    '$timeStr · ${session.durationMinutes}분',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.workout.withValues(alpha: 0.1)
                    : AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                isCompleted ? '완료' : '기록',
                style: AppTextStyles.captionSmall.copyWith(
                  color: isCompleted ? AppColors.workout : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _WorkoutCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final minutes = workout.durationSeconds ~/ 60;
    final detail = [
      if (minutes > 0) '$minutes분',
      '${workout.totalSets}세트',
      '${workout.totalVolume.toStringAsFixed(0)}kg',
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            AppIconBox(icon: Iconsax.weight, color: AppColors.brand, size: 40),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '개인운동 · ${workout.memberName}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    detail,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
