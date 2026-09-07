import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../models/inbody.dart';
import '../../models/pt_session.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_section.dart';
import 'member_calendar_screen.dart';
import 'member_feedback_screen.dart';
import 'member_meal_log_screen.dart';
import 'member_profile_screen.dart';
import 'member_pt_schedule_screen.dart';
import 'member_workout_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    AppNavItem(
      label: '홈',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavItem(
      label: '캘린더',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    AppNavItem(
      label: 'PT',
      icon: Icons.event_available_outlined,
      activeIcon: Icons.event_available_rounded,
    ),
    AppNavItem(
      label: '마이',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeDashboardTab(
        onGoToMeal: _openMealLog,
        onGoToWorkout: _openWorkoutLog,
        onGoToFeedback: _openFeedback,
        onGoToProfile: () => setState(() => _currentIndex = 3),
        onGoToPt: () => setState(() => _currentIndex = 2),
      ),
      const MemberCalendarScreen(),
      const MemberPtScheduleScreen(showBackButton: false),
      const MemberProfileScreen(),
    ];
  }

  void _openMealLog() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemberMealLogScreen()),
    );
  }

  void _openWorkoutLog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberWorkoutScreen(onExit: () => Navigator.pop(context)),
      ),
    );
  }

  void _openFeedback() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemberFeedbackScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppNavBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: _navItems,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────��───────────────────────────────────────��──────────────────────
// 홈 대시보드 탭
// ─────────────────────────────────────────────────────────────────────────────

class _HomeDashboardTab extends StatefulWidget {
  final VoidCallback onGoToMeal;
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToFeedback;
  final VoidCallback onGoToProfile;
  final VoidCallback onGoToPt;

  const _HomeDashboardTab({
    required this.onGoToMeal,
    required this.onGoToWorkout,
    required this.onGoToFeedback,
    required this.onGoToProfile,
    required this.onGoToPt,
  });

  @override
  State<_HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<_HomeDashboardTab> {
  Inbody? _latestInbody;
  Inbody? _prevInbody;
  PtSession? _nextPtSession;
  Workout? _todayWorkout;
  fb.Feedback? _latestFeedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final todayKey = _key(now);

      final inbodiesFuture = FirestoreService.getInbodiesByMember(
        user.uid,
        centerId: user.centerId,
        limit: 2,
      ).catchError((_) => <Inbody>[]);

      final results = await Future.wait([
        inbodiesFuture,
        FirestoreService.getPtSessionsByMember(
          user.uid,
          centerId: user.centerId,
          from: now,
          to: now.add(const Duration(days: 30)),
        ),
        WorkoutService.getWorkoutsByDateRange(
          user.centerId,
          user.uid,
          _key(weekStart),
          _key(weekEnd),
        ),
        FirestoreService.getFeedbacksForMember(
          user.uid,
          centerId: user.centerId,
          limit: 1,
        ).catchError((_) => <fb.Feedback>[]),
      ]);

      final inbodies = results[0] as List<Inbody>;
      final upcomingSessions = results[1] as List<PtSession>;
      final weekWorkouts = results[2] as List<Workout>;
      final feedbacks = results[3] as List<fb.Feedback>;

      final upcoming = upcomingSessions
          .where(
            (s) =>
                s.status == PtSessionStatus.scheduled &&
                s.scheduledAt.isAfter(now.subtract(const Duration(minutes: 1))),
          )
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      final todaysWorkouts =
          weekWorkouts.where((w) => w.workoutDate == todayKey).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _latestInbody = inbodies.isNotEmpty ? inbodies[0] : null;
        _prevInbody = inbodies.length > 1 ? inbodies[1] : null;
        _nextPtSession = upcoming.isNotEmpty ? upcoming.first : null;
        _todayWorkout = todaysWorkouts.isNotEmpty ? todaysWorkouts.first : null;
        _latestFeedback = feedbacks.isNotEmpty ? feedbacks.first : null;
      });
    } catch (e) {
      AppLogger.debug('[홈 데이터 로드 오류] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brand,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 인사 헤더 ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _GreetingHeader(user: user, now: now),
              ),

              // ── 오늘의 운동 카드 ───────────────────���─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md,
                  ),
                  child: _TodayCard(workout: _todayWorkout),
                ),
              ),

              // ── 퀵 액션 행 ──────────────────────────────���───────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl2,
                  ),
                  child: _QuickActionRow(
                    onGoToWorkout: widget.onGoToWorkout,
                    onGoToMeal: widget.onGoToMeal,
                    onGoToPt: widget.onGoToPt,
                    onGoToFeedback: widget.onGoToFeedback,
                  ),
                ),
              ),

              // ── 체중 + PT 정보 ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                  ),
                  child: AppSectionHeader(
                    title: '내 정보',
                    accentColor: AppColors.brand,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.xl2,
                  ),
                  child: _InfoCard(
                    latestInbody: _latestInbody,
                    prevInbody: _prevInbody,
                    nextSession: _nextPtSession,
                    onWeightTap: widget.onGoToProfile,
                    onPtTap: widget.onGoToPt,
                  ),
                ),
              ),

              // ── 트레이너 피드백 ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                  ),
                  child: AppSectionHeader(
                    title: '트레이너 피드백',
                    trailing: '전체보기',
                    onTrailingTap: widget.onGoToFeedback,
                    accentColor: AppColors.trainer,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.xl2,
                  ),
                  child: _FeedbackPreview(
                    feedback: _latestFeedback,
                    onTap: widget.onGoToFeedback,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────��──────────────────────────────────────────��─────────────────────
// 인사 헤더
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final dynamic user;
  final DateTime now;

  const _GreetingHeader({required this.user, required this.now});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final hour = now.hour;
    final greeting = hour < 12 ? '좋은 아침이에요' : hour < 18 ? '안녕하세요' : '수고하셨어요';
    final dateLabel = DateFormat('M월 d일 EEEE', 'ko').format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(AppSpacing.sm),
          Text(
            greeting,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(2),
          Text(
            '$name 님',
            style: AppTextStyles.h1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 오늘의 운동 카드
// ─────────────────────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final Workout? workout;

  const _TodayCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final hasWorkout = workout != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 운동',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  hasWorkout ? _workoutTitle(workout!) : '아직 기록 전이에요',
                  style: AppTextStyles.headline.copyWith(
                    color: hasWorkout
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                if (hasWorkout) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    '${workout!.exercises.length}종목 · 볼륨 ${workout!.totalVolume.toStringAsFixed(0)}kg · ${workout!.durationSeconds ~/ 60}분',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hasWorkout
                  ? AppColors.workout.withValues(alpha: 0.10)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              hasWorkout ? '완료' : '미완료',
              style: AppTextStyles.captionSmall.copyWith(
                color: hasWorkout ? AppColors.workout : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _workoutTitle(Workout w) {
    final category = w.category.label;
    final minutes = w.durationSeconds ~/ 60;
    return minutes > 0 ? '$category · $minutes분' : category;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 퀵 액션 행
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionRow extends StatelessWidget {
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToMeal;
  final VoidCallback onGoToPt;
  final VoidCallback onGoToFeedback;

  const _QuickActionRow({
    required this.onGoToWorkout,
    required this.onGoToMeal,
    required this.onGoToPt,
    required this.onGoToFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionItem(
              icon: Icons.fitness_center_rounded,
              label: '운동',
              color: AppColors.workout,
              onTap: onGoToWorkout,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: Icons.restaurant_rounded,
              label: '식단',
              color: AppColors.diet,
              onTap: onGoToMeal,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: Icons.event_available_rounded,
              label: 'PT',
              color: AppColors.trainer,
              onTap: onGoToPt,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: '피드백',
              color: AppColors.brand,
              onTap: onGoToFeedback,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const Gap(8),
          Text(
            label,
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 정보 카드 (체중 + PT)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Inbody? latestInbody;
  final Inbody? prevInbody;
  final PtSession? nextSession;
  final VoidCallback onWeightTap;
  final VoidCallback onPtTap;

  const _InfoCard({
    required this.latestInbody,
    required this.prevInbody,
    required this.nextSession,
    required this.onWeightTap,
    required this.onPtTap,
  });

  @override
  Widget build(BuildContext context) {
    final weight = latestInbody?.weight;
    final diff = (weight != null && prevInbody?.weight != null)
        ? weight - prevInbody!.weight
        : null;
    final ptLabel = nextSession != null ? _ptTimeLabel(nextSession!) : '--';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onWeightTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _InfoStat(
                    label: '현재 체중',
                    value: weight != null ? weight.toStringAsFixed(1) : '--',
                    unit: 'kg',
                    trend: diff != null
                        ? '${diff < 0 ? '' : '+'}${diff.toStringAsFixed(1)}kg'
                        : null,
                    trendPositive: diff != null ? diff > 0 : null,
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 0.5,
              color: AppColors.border,
            ),
            Expanded(
              child: GestureDetector(
                onTap: onPtTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _InfoStat(
                    label: '다음 PT',
                    value: ptLabel,
                    unit: '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ptTimeLabel(PtSession s) {
    final now = DateTime.now();
    final diff = s.scheduledAt.difference(now);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '내일';
    return '${diff.inDays}일 후';
  }
}

class _InfoStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? trend;
  final bool? trendPositive;

  const _InfoStat({
    required this.label,
    required this.value,
    required this.unit,
    this.trend,
    this.trendPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption,
        ),
        const Gap(AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTextStyles.numberLarge,
            ),
            if (unit.isNotEmpty) ...[
              const Gap(3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (trend != null) ...[
          const Gap(AppSpacing.xs),
          Row(
            children: [
              Icon(
                trendPositive == true
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 11,
                color: trendPositive == true
                    ? AppColors.destructive
                    : AppColors.workout,
              ),
              const Gap(2),
              Text(
                trend!,
                style: AppTextStyles.captionSmall.copyWith(
                  color: trendPositive == true
                      ? AppColors.destructive
                      : AppColors.workout,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 피드백 미리보기
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackPreview extends StatelessWidget {
  final fb.Feedback? feedback;
  final VoidCallback onTap;

  const _FeedbackPreview({required this.feedback, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasContent = feedback != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasContent) ...[
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.trainer.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      feedback!.trainerName.isNotEmpty
                          ? feedback!.trainerName[0]
                          : 'T',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.trainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    feedback!.trainerName,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
            ],
            Text(
              hasContent
                  ? feedback!.content
                  : '아직 등록된 트레이너 피드백이 없습니다.',
              style: AppTextStyles.body.copyWith(
                color: hasContent
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
