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

// ─────────────────────────────────────────────────────────────────────────────
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
              // ── 상단 인사 헤더 ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _GreetingHeader(user: user, now: now),
              ),

              // ── 오늘의 운동 히어로 카드 ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.base,
                  ),
                  child: _TodayWorkoutHero(workout: _todayWorkout),
                ),
              ),

              // ── 퀵 액션 2×2 그리드 ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.base,
                  ),
                  child: _QuickActionGrid(
                    onGoToWorkout: widget.onGoToWorkout,
                    onGoToMeal: widget.onGoToMeal,
                    onGoToPt: widget.onGoToPt,
                    onGoToFeedback: widget.onGoToFeedback,
                  ),
                ),
              ),

              // ── 다음 PT + 체중 KPI 행 ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.base,
                  ),
                  child: _StatsRow(
                    latestInbody: _latestInbody,
                    prevInbody: _prevInbody,
                    nextSession: _nextPtSession,
                    onWeightTap: widget.onGoToProfile,
                    onPtTap: widget.onGoToPt,
                  ),
                ),
              ),

              // ── 트레이너 피드백 ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                  ),
                  child: _FeedbackCard(
                    feedback: _latestFeedback,
                    onTap: widget.onGoToFeedback,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Gap(120)),
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
        AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                const Gap(AppSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.h1,
                    children: [
                      TextSpan(
                        text: greeting,
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                          fontSize: 22,
                        ),
                      ),
                      const TextSpan(text: '\n'),
                      TextSpan(text: '$name 님'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.brandLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: AppTextStyles.headline.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 오늘의 운동 히어로 카드
// ─────────────────────────────────────────────────────────────────────────────

class _TodayWorkoutHero extends StatelessWidget {
  final Workout? workout;

  const _TodayWorkoutHero({required this.workout});

  @override
  Widget build(BuildContext context) {
    final hasWorkout = workout != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
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
          Row(
            children: [
              Text(
                '오늘의 운동',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasWorkout)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.workout.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '완료',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.workout,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            hasWorkout ? _workoutTitle(workout!) : '아직 기록 전이에요',
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            hasWorkout
                ? '${workout!.exercises.length}종목 · 볼륨 ${workout!.totalVolume.toStringAsFixed(0)}kg · ${workout!.durationSeconds ~/ 60}분'
                : '오늘도 목표를 향해 달려보세요',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
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
// 퀵 액션 2×2 그리드
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionGrid extends StatelessWidget {
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToMeal;
  final VoidCallback onGoToPt;
  final VoidCallback onGoToFeedback;

  const _QuickActionGrid({
    required this.onGoToWorkout,
    required this.onGoToMeal,
    required this.onGoToPt,
    required this.onGoToFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                label: '운동 기록',
                description: '오늘 운동 추가',
                icon: Icons.fitness_center_rounded,
                color: AppColors.workout,
                onTap: onGoToWorkout,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: _QuickTile(
                label: '식단 기록',
                description: '식사 & 칼로리',
                icon: Icons.restaurant_rounded,
                color: AppColors.diet,
                onTap: onGoToMeal,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                label: 'PT 일정',
                description: '예약 확인',
                icon: Icons.event_available_rounded,
                color: AppColors.trainer,
                onTap: onGoToPt,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: _QuickTile(
                label: '피드백',
                description: '트레이너 메시지',
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.brand,
                onTap: onGoToFeedback,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const Gap(AppSpacing.md),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Gap(3),
              Text(
                description,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textTertiary,
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
// 체중 + PT 통계 행
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Inbody? latestInbody;
  final Inbody? prevInbody;
  final PtSession? nextSession;
  final VoidCallback onWeightTap;
  final VoidCallback onPtTap;

  const _StatsRow({
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

    final ptLabel = nextSession != null
        ? _ptTimeLabel(nextSession!)
        : '--';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onWeightTap,
            child: _StatCard(
              label: '현재 체중',
              value: weight != null ? weight.toStringAsFixed(1) : '--',
              unit: 'kg',
              accentColor: AppColors.brand,
              trend: diff != null
                  ? '${diff < 0 ? '' : '+'}${diff.toStringAsFixed(1)}kg'
                  : null,
              trendUp: diff != null ? diff > 0 : null,
            ),
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: onPtTap,
            child: _StatCard(
              label: '다음 PT',
              value: ptLabel,
              unit: '',
              accentColor: AppColors.trainer,
            ),
          ),
        ),
      ],
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final String? trend;
  final bool? trendUp;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.trend,
    this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const Gap(AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.numberLarge.copyWith(
                    fontSize: 28,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (trend != null) ...[
            const Gap(AppSpacing.xs),
            Row(
              children: [
                Icon(
                  trendUp == true
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: trendUp == true ? AppColors.destructive : AppColors.workout,
                ),
                const Gap(2),
                Text(
                  trend!,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: trendUp == true ? AppColors.destructive : AppColors.workout,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 트레이너 피드백 카드
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final fb.Feedback? feedback;
  final VoidCallback onTap;

  const _FeedbackCard({required this.feedback, required this.onTap});

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
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.trainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: AppColors.trainer,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Text(
                    '트레이너 피드백',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '전체보기',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: AppColors.brand,
                ),
              ],
            ),
            const Gap(AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                hasContent
                    ? feedback!.content
                    : '아직 등록된 트레이너 피드백이 없습니다.',
                style: AppTextStyles.body.copyWith(
                  color: hasContent ? AppColors.textPrimary : AppColors.textTertiary,
                  height: 1.6,
                  fontSize: 15,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
