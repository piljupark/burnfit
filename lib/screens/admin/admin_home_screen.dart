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
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_motion.dart';
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
    final rate = stats == null
        ? null
        : (stats.monthlyCompletionRate * 100).clamp(0, 100).round();

    AppKpiCard kpi(String label, int? value, String unit) => AppKpiCard(
      framed: false,
      label: label,
      value: '${value ?? '-'}',
      unit: unit,
      // 기준 시안 AdminHome: 안쪽 18 · 라벨 14 · 6 · 값 26 Bold
      padding: const EdgeInsets.all(18),
      labelSize: 14,
      labelGap: 6,
      valueSize: 26,
      bold: true,
    );

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
                  // 시안 Ad-Home-Error: 제목 아래 24 (카드 바깥 16 + 8)
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: AppErrorCard(message: _loadError!, onRetry: _load),
                  ),
                )
              else ...[
                // ── 가입 요청 (화면의 단 하나 강조 띠) ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: _pendingCount > 0
                        ? AppAccentBar(
                            icon: AppIcons.bell,
                            ring: true,
                            bold: true,
                            title: '가입 요청 $_pendingCount건',
                            actionLabel: '확인하기',
                            onTap: () => _push(const AdminRequestsScreen()),
                          )
                        : AppAccentBar(
                            icon: AppIcons.bell,
                            muted: true,
                            bold: true,
                            title: '가입 요청',
                            subtitle: '대기 중인 요청이 없어요',
                            onTap: () => _push(const AdminRequestsScreen()),
                          ),
                  ),
                ),

                // ── 숫자 2×2 (회색 칸) ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: AppStatGrid(
                      entrance: const AppStatEntrance(),
                      cells: [
                        kpi('전체 회원', stats?.memberCount, '명'),
                        kpi('트레이너', stats?.trainerCount, '명'),
                        kpi(
                          '$monthLabel PT 완료',
                          stats?.monthlyCompletedSessions,
                          '회',
                        ),
                        kpi('예정 PT', stats?.upcomingSessionCount, '회'),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: AppSectionBand(top: AppSpacing.xl),
                ),

                // ── 관리 메뉴 (60 줄 · 오른쪽 14 mute 값) ──────────────
                const SliverToBoxAdapter(
                  child: AppMonthHeader(label: '관리', padding: _sectionPadding),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                  sliver: SliverList.list(
                    children: [
                      _MenuRow(
                        icon: AppIcons.chartBar,
                        label: '대시보드',
                        value: rate == null ? null : '완료율 $rate%',
                        onTap: () => _push(const AdminDashboardScreen()),
                      ),
                      _MenuRow(
                        icon: AppIcons.userPlus,
                        label: '가입 요청',
                        value: _pendingCount > 0 ? '$_pendingCount건' : null,
                        onTap: () => _push(const AdminRequestsScreen()),
                      ),
                      _MenuRow(
                        icon: AppIcons.megaphone,
                        label: '공지사항',
                        onTap: () => _push(const AdminNoticeListScreen()),
                      ),
                      _MenuRow(
                        icon: AppIcons.archive,
                        label: '탈퇴 회원 PT 이력',
                        onTap: () => _push(const AdminWithdrawnMembersScreen()),
                      ),
                    ],
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

/// 섹션 머리말 여백 (시안 AdminHome·Ad-My: 띠 아래 20 20 4)
const _sectionPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenH,
  AppSpacing.lg,
  AppSpacing.screenH,
  AppSpacing.xs,
);

/// 관리 메뉴 한 줄 (기준 시안 AdminHome): 60 · 아이콘 상자 · 16 Regular · 오른쪽 14 mute 값, 화살표 없음.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      icon: icon,
      label: label,
      menu: true,
      showChevron: false,
      trailing: value == null
          ? null
          : Text(value!, style: AppTextStyles.fieldLabel),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 마이 탭
// ─────────────────────────────────────────────────────────────────────────────

class _AdminProfileTab extends StatelessWidget {
  const _AdminProfileTab();

  Future<void> _signOut(BuildContext context) async {
    await context.read<UserProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.memberLogin);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    // 시안 `slide`: 줄마다 0.06초 간격으로 왼쪽에서 들어온다
    Widget slide(int i, Widget child) => AppEntrance.slide(
      delay: Duration(milliseconds: 60 * i),
      child: child,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
          children: [
            const AppHero(title: '마이', bottomGap: 0),
            AppProfileRow(
              large: true,
              name: user?.name ?? '',
              subtitle: [
                '센터 관리자',
                if ((user?.centerName ?? '').isNotEmpty) user!.centerName,
              ].join(' · '),
            ),
            // 시안 Ad-My: 8 띠 → '계정'(20 20 4) → 메뉴 줄 60 (사이 선은 좌우 20 안쪽, 마지막 줄 아래 없음)
            // 관리자 탈퇴는 서버에서 막는다 (탈퇴 링크 없음).
            const AppSectionBand(),
            const AppMonthHeader(label: '계정', padding: _sectionPadding),
            slide(
              0,
              AppActionRow(
                icon: AppIcons.lock,
                label: '비밀번호 재설정 메일',
                menu: true,
                onTap: () =>
                    showPasswordResetSheet(context, initialEmail: user?.email),
              ),
            ),
            const AppRowDivider.inset(),
            slide(1, const ThemeSettingRow()),
            const AppRowDivider.inset(),
            slide(
              2,
              AppActionRow(
                icon: AppIcons.signOut,
                label: '로그아웃',
                menu: true,
                showChevron: false,
                onTap: () => _signOut(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
