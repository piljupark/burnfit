import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/admin_stats.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/app_section.dart';
import 'admin_dashboard_screen.dart';
import 'admin_member_list_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_trainer_list_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    AppNavItem(
      label: '홈',
      icon: Iconsax.home,
      activeIcon: Iconsax.home,
    ),
    AppNavItem(
      label: '회원',
      icon: Iconsax.people,
      activeIcon: Iconsax.people,
    ),
    AppNavItem(
      label: '트레이너',
      icon: Iconsax.activity,
      activeIcon: Iconsax.activity,
    ),
    AppNavItem(
      label: '마이',
      icon: Iconsax.user,
      activeIcon: Iconsax.user,
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _AdminDashboardTab(),
      const AdminMemberListScreen(),
      const AdminTrainerListScreen(),
      const _AdminProfileTab(),
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
// 관리자 대시보드 탭
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDashboardTab extends StatefulWidget {
  const _AdminDashboardTab();

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  int _pendingCount = 0;
  AdminStats? _stats;
  bool _isLoading = false;
  String? _loadError;

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
      final results = await Future.wait([
        FirestoreService.getPendingRequests(user.centerId),
        FirestoreService.getAdminStats(user.centerId),
      ]);
      if (!mounted) return;
      final requests = results[0] as List;
      final stats = results[1] as AdminStats?;
      setState(() {
        _pendingCount = requests.length;
        _stats = stats;
        _loadError = null;
      });
    } catch (e) {
      AppLogger.debug('[AdminHome] 관리자 홈 로드 실패: $e');
      if (!mounted) return;
      setState(() => _loadError = '데이터를 불러올 수 없습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final monthLabel = DateFormat('M월').format(DateTime.now());

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
              // ── 인사 헤더 ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.xl,
                    AppSpacing.screenH, AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.centerName ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      Text(
                        '관리자 대시보드',
                        style: AppTextStyles.h1,
                      ),
                      if (_pendingCount > 0) ...[
                        const Gap(AppSpacing.md),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminRequestsScreen(),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.diet.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: AppColors.diet.withValues(alpha: 0.4),
                                width: 0.75,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.diet,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(6),
                                Text(
                                  '가입 신청 $_pendingCount건 대기 중',
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: AppColors.diet,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Gap(4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: AppColors.diet,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
              else if (_loadError != null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _loadError!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else ...[
                // ── KPI 카드 그리드 ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl2,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppKpiCard(
                                label: '전체 회원',
                                value: '${_stats?.memberCount ?? '-'}',
                                unit: '명',
                                icon: Icons.people_outline_rounded,
                                accentColor: AppColors.brand,
                              ),
                            ),
                            const Gap(AppSpacing.sm),
                            Expanded(
                              child: AppKpiCard(
                                label: '트레이너',
                                value: '${_stats?.trainerCount ?? '-'}',
                                unit: '명',
                                icon: Icons.fitness_center_outlined,
                                accentColor: AppColors.workout,
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppKpiCard(
                                label: '$monthLabel PT 완료',
                                value: '${_stats?.monthlyCompletedSessions ?? '-'}',
                                unit: '회',
                                icon: Icons.check_circle_outline_rounded,
                                isHighlight: true,
                                accentColor: AppColors.brand,
                              ),
                            ),
                            const Gap(AppSpacing.sm),
                            Expanded(
                              child: AppKpiCard(
                                label: '예정 세션',
                                value: '${_stats?.upcomingSessionCount ?? '-'}',
                                unit: '건',
                                icon: Icons.calendar_today_outlined,
                                accentColor: AppColors.trainer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 관리 메뉴 ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, 0,
                    ),
                    child: AppSectionHeader(
                      title: '관리',
                      accentColor: AppColors.brand,
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, 120,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          AppActionRow(
                            icon: Icons.bar_chart_rounded,
                            label: '대시보드',
                            subtitle: '센터 통계 및 분석',
                            iconColor: AppColors.brand,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboardScreen(),
                              ),
                            ),
                          ),
                          const AppRowDivider(),
                          AppActionRow(
                            icon: Icons.person_add_outlined,
                            label: '가입 신청',
                            subtitle: _pendingCount > 0
                                ? '대기 중 $_pendingCount건'
                                : '대기 없음',
                            badge: _pendingCount > 0 ? '$_pendingCount' : null,
                            badgeColor: AppColors.diet,
                            iconColor: AppColors.diet,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminRequestsScreen(),
                              ),
                            ),
                          ),
                          const AppRowDivider(),
                          AppActionRow(
                            icon: Icons.people_outline_rounded,
                            label: '회원 관리',
                            subtitle: '회원 목록 및 상세 정보',
                            iconColor: AppColors.workout,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminMemberListScreen(),
                              ),
                            ),
                          ),
                          const AppRowDivider(),
                          AppActionRow(
                            icon: Icons.fitness_center_outlined,
                            label: '트레이너 관리',
                            subtitle: '트레이너 목록 및 배정',
                            iconColor: AppColors.trainer,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminTrainerListScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
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
// 마이 탭
// ─────────────────────────────────────────────────────────────────────────────

class _AdminProfileTab extends StatelessWidget {
  const _AdminProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('마이', style: AppTextStyles.h1),
              const Gap(AppSpacing.xl),
              AppProfileCard(
                name: user?.name ?? '',
                subtitle: user?.centerName ?? '',
                roleLabel: '관리자',
                gradientStart: const Color(0xFF2C2C2E),
                gradientEnd: const Color(0xFF48484A),
              ),
              const Gap(AppSpacing.xl),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
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
    );
  }
}
