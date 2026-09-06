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
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_box.dart';
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
      ),
      const MemberCalendarScreen(),
      const MemberPtScheduleScreen(showBackButton: false),
      const MemberProfileScreen(),
    ];
  }

  void _openMealLog() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemberMealLogScreen()));
  }

  void _openWorkoutLog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MemberWorkoutScreen(onExit: () => Navigator.pop(context)),
      ),
    );
  }

  void _openFeedback() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemberFeedbackScreen()));
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

  const _HomeDashboardTab({
    required this.onGoToMeal,
    required this.onGoToWorkout,
    required this.onGoToFeedback,
    required this.onGoToProfile,
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

      // inbody는 복합 인덱스 필요 — 인덱스 없어도 나머지 로드 계속하도록 분리
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

      final upcoming =
          upcomingSessions
              .where(
                (s) =>
                    s.status == PtSessionStatus.scheduled &&
                    s.scheduledAt.isAfter(
                      now.subtract(const Duration(minutes: 1)),
                    ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeTitle(user: user, now: now),
                      const Gap(20),
                      _TodayWorkoutHero(workout: _todayWorkout),
                      const Gap(12),
                      _QuickActionRow(
                        onGoToWorkout: widget.onGoToWorkout,
                        onGoToMeal: widget.onGoToMeal,
                      ),
                      const Gap(12),
                      if (_nextPtSession != null) ...[
                        _NextPtCard(session: _nextPtSession!),
                        const Gap(12),
                      ],
                      _FeedbackPreviewCard(
                        feedback: _latestFeedback,
                        onTap: widget.onGoToFeedback,
                      ),
                      const Gap(12),
                      _CurrentWeightCard(
                        latest: _latestInbody,
                        prev: _prevInbody,
                        onTap: widget.onGoToProfile,
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
// 홈 타이틀
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTitle extends StatelessWidget {
  final dynamic user;
  final DateTime now;

  const _HomeTitle({required this.user, required this.now});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final dateLabel = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name님',
          style: AppTextStyles.h1.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(4),
        Text(
          dateLabel,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),



        ),
      ],
    );
  }
}

class _TodayWorkoutHero extends StatelessWidget {
  final Workout? workout;

  const _TodayWorkoutHero({required this.workout});

  @override
  Widget build(BuildContext context) {
    final hasWorkout = workout != null;
    final title = hasWorkout ? _workoutSummary(workout!) : '아직 기록 전이에요';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 운동',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textOnAccent.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const Gap(8),
          Text(
            title,
            style: AppTextStyles.headline.copyWith(
              color: AppColors.textOnAccent,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  static String _workoutSummary(Workout workout) {
    final category = workout.category.label;
    final minutes = workout.durationSeconds ~/ 60;
    return minutes > 0 ? '$category · $minutes분 완료' : '$category 완료';
  }
}

class _QuickActionRow extends StatelessWidget {
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToMeal;

  const _QuickActionRow({
    required this.onGoToWorkout,
    required this.onGoToMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            label: '운동 기록',
            icon: Icons.fitness_center_rounded,
            color: AppColors.workout,
            onTap: onGoToWorkout,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _QuickActionCard(
            label: '식단 기록',
            icon: Icons.restaurant_rounded,
            color: AppColors.diet,
            onTap: onGoToMeal,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      hasShadow: true,
      hasBorder: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBox(icon: icon, color: color),
          const Gap(10),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackPreviewCard extends StatelessWidget {
  final fb.Feedback? feedback;
  final VoidCallback onTap;

  const _FeedbackPreviewCard({required this.feedback, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final message = feedback?.content ?? '아직 등록된 트레이너 피드백이 없습니다.';

    return AppCard(
      onTap: onTap,
      hasShadow: true,
      hasBorder: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '트레이너 피드백',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '전체보기',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.brand,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textNeutral,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentWeightCard extends StatelessWidget {
  final Inbody? latest;
  final Inbody? prev;
  final VoidCallback onTap;

  const _CurrentWeightCard({
    required this.latest,
    required this.prev,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weight = latest?.weight;
    final diff = (weight != null && prev?.weight != null)
        ? weight - prev!.weight
        : null;

    return AppCard(
      onTap: onTap,
      hasShadow: true,
      hasBorder: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 체중',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Gap(4),
                Text(
                  weight != null ? '${weight.toStringAsFixed(1)}kg' : '--kg',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (diff != null)
            Text(
              '${diff < 0 ? '▼' : '▲'} ${diff.abs().toStringAsFixed(1)}kg',
              style: AppTextStyles.label.copyWith(
                color: diff < 0
                    ? AppColors.workout
                    : AppColors.destructive,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 다음 PT 세션 카드
// ─────────────────────────────────────────────────────────────────────────────

class _NextPtCard extends StatelessWidget {
  final PtSession session;

  const _NextPtCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isTomorrow = isSameDay(
      session.scheduledAt,
      now.add(const Duration(days: 1)),
    );
    final timeStr = DateFormat('HH:mm').format(session.scheduledAt);
    final String dayLabel;
    if (isSameDay(session.scheduledAt, now)) {
      dayLabel = '오늘';
    } else if (isTomorrow) {
      dayLabel = '내일';
    } else {
      dayLabel = DateFormat('M월 d일 (E)', 'ko').format(session.scheduledAt);
    }

    return AppCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MemberPtScheduleScreen())),
      hasShadow: true,
      hasBorder: false,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          const AppIconBox(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.trainer,
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음 PT 일정',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Gap(4),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(text: '$dayLabel $timeStr · '),
                      TextSpan(
                        text: '${session.trainerName} 트레이너',
                        style: const TextStyle(
                          color: AppColors.trainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
