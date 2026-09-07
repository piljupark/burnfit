import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/app_section.dart';
import 'trainer_member_detail_screen.dart';
import 'trainer_pt_workout_screen.dart';
import 'trainer_schedule_screen.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    AppNavItem(
      label: '홈',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavItem(
      label: '일정',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
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
      const _TrainerDashboardTab(),
      const TrainerScheduleScreen(),
      const _TrainerProfileTab(),
    ];
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
// 대시보드 탭
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerDashboardTab extends StatefulWidget {
  const _TrainerDashboardTab();

  @override
  State<_TrainerDashboardTab> createState() => _TrainerDashboardTabState();
}

class _TrainerDashboardTabState extends State<_TrainerDashboardTab> {
  List<AppUser> _members = [];
  List<PtSession> _todaySessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final results = await Future.wait([
        FirestoreService.getMembersByTrainer(user.centerId, user.uid),
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: todayStart,
          to: todayEnd,
        ),
      ]);

      if (!mounted) return;
      final members = results[0] as List<AppUser>;
      final sessions = results[1] as List<PtSession>;
      setState(() {
        _members = members;
        _todaySessions = sessions
            .where((s) => s.status != PtSessionStatus.cancelled)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPtWorkout(PtSession session) async {
    final member = _members.where((m) => m.uid == session.memberId).firstOrNull;
    if (member == null) {
      AppFeedback.showErrorSnackBar(context, ArgumentError('회원 정보를 찾을 수 없습니다.'));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerPtWorkoutScreen(session: session, member: member),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final now = DateTime.now();
    final dateLabel = DateFormat('M월 d일 EEEE', 'ko').format(now);
    final completedCount =
        _todaySessions.where((s) => s.status == PtSessionStatus.completed).length;

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
                child: _TrainerGreetingHeader(
                  user: user,
                  dateLabel: dateLabel,
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                )
              else ...[
                // ── 오늘 PT 통계 배너 ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.base,
                    ),
                    child: _TodayStatsBanner(
                      total: _todaySessions.length,
                      completed: completedCount,
                    ),
                  ),
                ),

                // ── 오늘 PT 일정 ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: '오늘 PT 일정',
                          accentColor: AppColors.brand,
                        ),
                        _TodayScheduleList(
                          sessions: _todaySessions,
                          onRecordTap: _openPtWorkout,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 담당 회원 ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md,
                    ),
                    child: AppSectionHeader(
                      title: '담당 회원',
                      trailing: '${_members.length}명',
                      accentColor: AppColors.workout,
                    ),
                  ),
                ),

                if (_members.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                      ),
                      child: const AppEmptyState(
                        icon: Icons.people_outline_rounded,
                        message: '배정된 회원이 없습니다.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, 120,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          if (i.isOdd) return const Gap(AppSpacing.sm);
                          final m = _members[i ~/ 2];
                          return _MemberCard(
                            member: m,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TrainerMemberDetailScreen(member: m),
                              ),
                            ),
                          );
                        },
                        childCount: _members.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
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
  final String dateLabel;

  const _TrainerGreetingHeader({required this.user, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
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
                        text: '$name 트레이너',
                        style: AppTextStyles.h1,
                      ),
                      TextSpan(
                        text: '\n오늘도 파이팅!',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.trainer.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0] : 'T',
              style: AppTextStyles.headline.copyWith(
                color: AppColors.trainer,
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
// 오늘 PT 통계 배너
// ─────────────────────────────────────────────────────────────────────────────

class _TodayStatsBanner extends StatelessWidget {
  final int total;
  final int completed;

  const _TodayStatsBanner({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final remaining = total - completed;
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 PT',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$total',
                      style: AppTextStyles.numberLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 40,
                        letterSpacing: -2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '건',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 48,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
          const Gap(AppSpacing.base),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(
                label: '완료',
                value: '$completed',
                color: AppColors.workout,
              ),
              const Gap(AppSpacing.sm),
              _StatRow(
                label: '대기',
                value: '$remaining',
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value,
          style: AppTextStyles.h2.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 오늘 PT 일정 리스트
// ─────────────────────────────────────────────────────────────────────────────

class _TodayScheduleList extends StatelessWidget {
  final List<PtSession> sessions;
  final void Function(PtSession) onRecordTap;

  const _TodayScheduleList({
    required this.sessions,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.textDisabled,
            ),
            const Gap(AppSpacing.sm),
            Text(
              '오늘 예정된 PT가 없습니다.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: sessions.asMap().entries.map((e) {
          final idx = e.key;
          final s = e.value;
          return Column(
            children: [
              if (idx > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: AppColors.border,
                  indent: AppSpacing.base + 36 + AppSpacing.md,
                ),
              _ScheduleRow(
                session: s,
                onRecordTap: s.status == PtSessionStatus.scheduled
                    ? () => onRecordTap(s)
                    : null,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final PtSession session;
  final VoidCallback? onRecordTap;

  const _ScheduleRow({required this.session, this.onRecordTap});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(session.scheduledAt);
    final isCompleted = session.status == PtSessionStatus.completed;
    final accentColor = isCompleted ? AppColors.workout : AppColors.brand;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              timeStr,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.memberName,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (session.note != null && session.note!.isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    session.note!,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          if (onRecordTap != null)
            GestureDetector(
              onTap: onRecordTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '기록',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.workout.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 회원 카드
// ─────────────────────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final AppUser member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0] : '?';
    final weight = member.profile?.weight;
    final bmi = member.profile?.bmi;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: AppColors.brand.withValues(alpha: 0.04),
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTextStyles.headline.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      weight != null
                          ? '${weight.toStringAsFixed(1)} kg${bmi != null ? '  ·  BMI ${bmi.toStringAsFixed(1)}' : ''}'
                          : '신체 정보 없음',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: weight != null
                            ? AppColors.textTertiary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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
// 마이 탭
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerProfileTab extends StatelessWidget {
  const _TrainerProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '마이',
                      style: AppTextStyles.h1,
                    ),
                    const Gap(AppSpacing.xl),
                    AppProfileCard(
                      name: user?.name ?? '',
                      subtitle: user?.centerName ?? '',
                      roleLabel: '트레이너',
                      gradientStart: AppColors.trainer,
                      gradientEnd: const Color(0xFF6A5DB8),
                    ),
                    const Gap(AppSpacing.xl),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AppActionRow(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        isDestructive: true,
                        onTap: () async {
                          await context.read<UserProvider>().signOut();
                          if (!context.mounted) return;
                          Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.memberLogin);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Gap(120)),
          ],
        ),
      ),
    );
  }
}
