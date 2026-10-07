import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
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
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_box.dart';
import 'package:iconsax/iconsax.dart';

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
  List<PtSession> _ptSessions = [];
  List<Meal> _meals = [];
  List<fb.Feedback> _feedbacks = [];
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
      setState(() {
        _workouts = results[0] as List<Workout>;
        _meals = results[1] as List<Meal>;
        _feedbacks = (results[2] as List<fb.Feedback>).where((item) {
          final targetDate = item.targetDate;
          return targetDate != null &&
              targetDate.compareTo(startKey) >= 0 &&
              targetDate.compareTo(endKey) <= 0;
        }).toList();
        _ptSessions = (results[3] as List<PtSession>)
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
                        _GreetingHeader(user: context.watch<UserProvider>().user)
                      else
                        Text('캘린더', style: AppTextStyles.h1),
                      const Gap(16),
                      _MonthHeader(
                        month: _focusedMonth,
                        onPrev: () => _moveMonth(-1),
                        onNext: () => _moveMonth(1),
                      ),
                      const Gap(16),
                      _CalendarGrid(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        workouts: _workouts,
                        ptReservations: _ptSessions,
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
                          child: Center(child: CircularProgressIndicator()),
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
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w400,
        height: 1.2,
        letterSpacing: -0.2,
      ),
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

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<Workout> workouts;
  final List<PtSession> ptReservations;
  final ValueChanged<DateTime> onSelect;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.workouts,
    required this.ptReservations,
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
    final personalWorkoutDays = workouts
        .where((item) => item.workoutType == WorkoutType.personal)
        .map((item) => item.workoutDate)
        .toSet();
    final ptWorkoutDays = workouts
        .where((item) => item.workoutType == WorkoutType.pt)
        .map((item) => item.workoutDate)
        .toSet();
    final ptScheduledDays = ptReservations
        .map((item) => _key(item.scheduledAt))
        .toSet();
    final todayBase = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

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

            final day = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final key = _key(day);
            final isToday = _sameDate(day, DateTime.now());
            final isSelected = _sameDate(day, selectedDay);
            final isPast = day.isBefore(todayBase);
            final hasPersonalWorkout = personalWorkoutDays.contains(key);
            final hasPtDone = ptWorkoutDays.contains(key);
            final hasPtSession = hasPtDone || ptScheduledDays.contains(key);

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
                        fontWeight: (isSelected || isToday)
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
                        if (hasPersonalWorkout)
                          _CalendarLabel(label: '개인운동', color: AppColors.brand),
                        if (hasPtSession) ...[
                          if (hasPersonalWorkout) const Gap(1),
                          _CalendarLabel(
                            label: hasPtDone ? 'PT운동' : (isPast ? 'PT운동' : 'PT예약'),
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

class _DayRecords extends StatelessWidget {
  final List<Workout> workouts;
  final List<PtSession> ptReservations;
  final List<Meal> meals;
  final List<fb.Feedback> feedbacks;

  const _DayRecords({
    required this.workouts,
    required this.ptReservations,
    required this.meals,
    required this.feedbacks,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty &&
        ptReservations.isEmpty &&
        meals.isEmpty &&
        feedbacks.isEmpty) {
      return AppCard(
        hasShadow: true,
        hasBorder: false,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            '이 날의 기록이 없습니다',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final workout in workouts) ...[
          _WorkoutRecordCard(workout: workout),
          const Gap(12),
        ],
        for (final reservation in ptReservations) ...[
          _PtReservationRecordCard(reservation: reservation),
          const Gap(12),
        ],
        for (final meal in meals) ...[
          _MealRecordCard(meal: meal),
          const Gap(12),
        ],
        for (final feedback in feedbacks) ...[
          _FeedbackRecordCard(feedback: feedback),
          const Gap(12),
        ],
      ],
    );
  }
}

class _WorkoutRecordCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutRecordCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final minutes = workout.durationSeconds ~/ 60;
    final detail = [
      if (minutes > 0) '$minutes분',
      '${workout.totalSets}세트',
      '${workout.totalVolume.toStringAsFixed(0)}kg',
    ].join(' · ');

    final isPt = workout.workoutType == WorkoutType.pt;
    return _RecordCard(
      icon: isPt ? Iconsax.activity : Iconsax.weight,
      color: isPt ? AppColors.destructive : AppColors.brand,
      title: isPt
          ? 'PT 운동 · ${workout.category.label}'
          : '개인 운동 · ${workout.category.label}',
      detail: detail,
    );
  }
}

class _PtReservationRecordCard extends StatelessWidget {
  final PtSession reservation;

  const _PtReservationRecordCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return _RecordCard(
      icon: Iconsax.calendar_tick,
      color: AppColors.destructive,
      title: 'PT 예약',
      detail:
          '${DateFormat('a h:mm', 'ko').format(reservation.scheduledAt)} · ${reservation.durationMinutes}분 · ${reservation.trainerName}',
    );
  }
}

class _MealRecordCard extends StatelessWidget {
  final Meal meal;

  const _MealRecordCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if ((meal.description ?? '').trim().isNotEmpty) meal.description!.trim(),
      if (meal.calories != null) '${meal.calories}kcal',
    ].join(' · ');

    return _RecordCard(
      icon: Iconsax.cup,
      color: AppColors.diet,
      title: meal.mealType.label,
      detail: detail.isNotEmpty ? detail : '메모 없음',
    );
  }
}

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  const _RecordCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          AppIconBox(icon: icon, color: color, size: 40),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
        ],
      ),
    );
  }
}

class _FeedbackRecordCard extends StatelessWidget {
  final fb.Feedback feedback;

  const _FeedbackRecordCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBox(icon: Iconsax.message_text_1, color: AppColors.trainer, size: 40),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feedback.trainerName,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('a h:mm', 'ko').format(feedback.createdAt),
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  feedback.content,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.5,
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


bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _GreetingHeader extends StatelessWidget {
  final dynamic user;

  const _GreetingHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '${user?.name ?? ''}님',
            style: AppTextStyles.h1,
          ),
        ),
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm),
            child: Icon(
              Iconsax.notification,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
