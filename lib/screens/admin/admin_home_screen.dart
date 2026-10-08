import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/admin_stats.dart';
import '../../services/account_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/theme_setting_row.dart';
import '../../widgets/password_reset_sheet.dart';
import '../../widgets/app_loader.dart';
import 'admin_dashboard_screen.dart';
import 'admin_member_list_screen.dart';
import 'admin_notice_list_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_trainer_list_screen.dart';
import 'admin_withdrawn_members_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    AppNavItem(label: '홈', icon: AppIcons.home, activeIcon: AppIcons.homeFill),
    AppNavItem(
      label: '회원',
      icon: AppIcons.members,
      activeIcon: AppIcons.membersFill,
    ),
    AppNavItem(
      label: '트레이너',
      icon: AppIcons.trainers,
      activeIcon: AppIcons.trainersFill,
    ),
    AppNavItem(
      label: '마이',
      icon: AppIcons.profile,
      activeIcon: AppIcons.profileFill,
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
      backgroundColor: AppColors.canvas,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 관리자 홈 탭
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

  /// 하위 화면에서 승인·PT 등록 등을 했을 수 있으므로 돌아오면 홈 숫자를 다시 불러온다.
  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final monthLabel = DateFormat('M월').format(DateTime.now());
    final stats = _stats;
    final centerName = user?.centerName ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AppHero(title: centerName.isEmpty ? '관리자' : centerName),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppLoadingView(),
                )
              else if (_loadError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: AppErrorCard(message: _loadError!, onRetry: _load),
                  ),
                )
              else ...[
                // ── 가입 신청 (화면의 단 하나 강조 띠) ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.sm,
                      AppSpacing.screenH,
                      AppSpacing.base,
                    ),
                    child: _PendingRequestsCard(
                      count: _pendingCount,
                      onTap: () => _push(const AdminRequestsScreen()),
                    ),
                  ),
                ),

                // ── KPI 2×2 (회색 칸) ───────────────────────────────────
                SliverToBoxAdapter(
                  child: AppStatGrid(
                    cells: [
                      AppKpiCard(
                        framed: false,
                        label: '전체 회원',
                        value: '${stats?.memberCount ?? '-'}',
                        unit: '명',
                      ),
                      AppKpiCard(
                        framed: false,
                        label: '트레이너',
                        value: '${stats?.trainerCount ?? '-'}',
                        unit: '명',
                      ),
                      AppKpiCard(
                        framed: false,
                        label: '$monthLabel PT 완료',
                        value: '${stats?.monthlyCompletedSessions ?? '-'}',
                        unit: '회',
                        trend: stats == null
                            ? null
                            : '${(stats.monthlyCompletionRate * 100).clamp(0, 100).toStringAsFixed(0)}% 완료',
                      ),
                      AppKpiCard(
                        framed: false,
                        label: '예정 세션',
                        value: '${stats?.upcomingSessionCount ?? '-'}',
                        unit: '건',
                        trend: stats == null
                            ? null
                            : '오늘 ${stats.todayScheduledSessions}',
                      ),
                    ],
                  ),
                ),

                // ── 관리 메뉴 ───────────────────────────────────────────
                const SliverToBoxAdapter(child: AppMonthHeader(label: '관리')),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        AppActionRow(
                          icon: AppIcons.clipboard,
                          label: '공지사항',
                          subtitle: '센터 공지 작성 및 관리',
                          onTap: () => _push(const AdminNoticeListScreen()),
                        ),
                        const AppRowDivider(indent: AppSpacing.screenH),
                        AppActionRow(
                          icon: AppIcons.chartBar,
                          label: '대시보드',
                          subtitle: '센터 통계 및 분석',
                          onTap: () => _push(const AdminDashboardScreen()),
                        ),
                        const AppRowDivider(indent: AppSpacing.screenH),
                        AppActionRow(
                          icon: AppIcons.members,
                          label: '회원 관리',
                          subtitle: '회원 목록 및 상세 정보',
                          onTap: () => _push(const AdminMemberListScreen()),
                        ),
                        const AppRowDivider(indent: AppSpacing.screenH),
                        AppActionRow(
                          icon: AppIcons.trainers,
                          label: '트레이너 관리',
                          subtitle: '트레이너 목록 및 배정',
                          onTap: () => _push(const AdminTrainerListScreen()),
                        ),
                        const AppRowDivider(indent: AppSpacing.screenH),
                        AppActionRow(
                          icon: AppIcons.archive,
                          label: '탈퇴 회원 PT 이력',
                          subtitle:
                              '분쟁 대응용 · ${AccountService.ptRecordRetentionYears}년 보관 후 파기',
                          onTap: () =>
                              _push(const AdminWithdrawnMembersScreen()),
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
    );
  }
}

/// 가입 신청 요약: 대기 신청이 있으면 강조 띠(AppAccentBar),
/// 없으면 회색 줄(아이콘 + 안내 + 화살표).
class _PendingRequestsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingRequestsCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count > 0) {
      return AppAccentBar(
        icon: AppIcons.userPlus,
        title: '가입 신청 $count건',
        subtitle: '승인을 기다리고 있어요',
        actionLabel: '확인하기',
        onTap: onTap,
      );
    }
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          highlightColor: AppColors.canvasMid,
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.base,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(AppIcons.userPlus, size: 22, color: AppColors.body),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('가입 신청', style: AppTextStyles.bodyLg),
                        Text(
                          '대기 중인 신청이 없어요',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.forward, size: 18, color: AppColors.body),
                ],
              ),
            ),
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
          children: [
            const AppHero(title: '마이', divider: false),
            AppProfileRow(
              name: user?.name ?? '',
              subtitle: [
                '센터 관리자',
                if ((user?.centerName ?? '').isNotEmpty) user!.centerName,
              ].join(' · '),
            ),
            // 관리자 탈퇴는 서버에서 막는다 (탈퇴 링크 없음).
            const AppMonthHeader(label: '계정'),
            AppActionRow(
              icon: AppIcons.lock,
              label: '비밀번호 재설정 메일',
              menu: true,
              onTap: () =>
                  showPasswordResetSheet(context, initialEmail: user?.email),
            ),
            const AppRowDivider(),
            const ThemeSettingRow(),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.signOut,
              label: '로그아웃',
              menu: true,
              showChevron: false,
              onTap: () async {
                await context.read<UserProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.memberLogin);
              },
            ),
            const AppRowDivider(),
          ],
        ),
      ),
    );
  }
}
