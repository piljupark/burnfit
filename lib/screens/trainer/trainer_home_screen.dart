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
// 홈 탭 (오늘 일정 + 담당 회원)
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
        _todaySessions =
            sessions
                .where((s) => s.status != PtSessionStatus.cancelled)
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final now = DateTime.now();
    final dateLabel = DateFormat('M월 d일 EEEE', 'ko').format(now);

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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(2),
                      RichText(
                        text: TextSpan(
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                          children: [
                            TextSpan(
                              text: user?.name ?? '',
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                            const TextSpan(
                              text: ' 트레이너',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Gap(AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                    ),
                    child: _TodayScheduleSection(
                      sessions: _todaySessions,
                      members: _members,
                      onRecordTap: _openPtWorkout,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Gap(AppSpacing.xl)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm,
                    ),
                    child: AppSectionHeader(
                      title: '담당 회원',
                      trailing: '${_members.length}명',
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
                      delegate: SliverChildBuilderDelegate((_, i) {
                        if (i.isOdd) return const Gap(AppSpacing.xs);
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
                      }, childCount: _members.length * 2 - 1),
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
// 오늘의 PT 일정 섹션
// ─────────────────────────────────────────────────────────────────────────────

class _TodayScheduleSection extends StatelessWidget {
  final List<PtSession> sessions;
  final List<AppUser> members;
  final void Function(PtSession) onRecordTap;

  const _TodayScheduleSection({
    required this.sessions,
    required this.members,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '오늘의 PT',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${sessions.length}건',
                  style: AppTextStyles.caption.copyWith(
                    color: sessions.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (sessions.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
                horizontal: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    '오늘 예정된 PT가 없습니다.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Gap(AppSpacing.xs),
            ...sessions.asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              return Column(
                children: [
                  if (idx > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: AppColors.border,
                      ),
                    ),
                  _TodaySessionRow(
                    session: s,
                    onRecordTap: s.status == PtSessionStatus.scheduled
                        ? () => onRecordTap(s)
                        : null,
                  ),
                ],
              );
            }),
          ],
          const Gap(AppSpacing.xs),
        ],
      ),
    );
  }
}

class _TodaySessionRow extends StatelessWidget {
  final PtSession session;
  final VoidCallback? onRecordTap;

  const _TodaySessionRow({required this.session, this.onRecordTap});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(session.scheduledAt);
    final isCompleted = session.status == PtSessionStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              timeStr,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const Gap(AppSpacing.xs),
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.workout : AppColors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.memberName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (session.note != null && session.note!.isNotEmpty)
                  Text(
                    session.note!,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onRecordTap != null)
            GestureDetector(
              onTap: onRecordTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '기록',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.brand.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTextStyles.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (weight != null) ...[
                      const Gap(2),
                      Text(
                        '${weight.toStringAsFixed(1)} kg'
                        '${bmi != null ? '  ·  BMI ${bmi.toStringAsFixed(1)}' : ''}',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ] else ...[
                      const Gap(2),
                      Text(
                        '신체 정보 없음',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textDisabled,
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
                  AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '마이',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    AppProfileCard(
                      name: user?.name ?? '',
                      subtitle: user?.centerName ?? '',
                      roleLabel: '트레이너',
                    ),
                    const Gap(AppSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: AppActionRow(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        isDestructive: true,
                        onTap: () async {
                          await context.read<UserProvider>().signOut();
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRoutes.memberLogin);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
