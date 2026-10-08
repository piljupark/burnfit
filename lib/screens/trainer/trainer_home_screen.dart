import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/constants.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_target.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/theme_setting_row.dart';
import '../../widgets/password_reset_sheet.dart';
import '../../widgets/delete_account_sheet.dart';
import 'trainer_calendar_screen.dart';
import 'trainer_schedule_screen.dart';
import '../common/notice_list_screen.dart';
import '../common/notice_menu_row.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  int _currentIndex = 0;
  final _calendarKey = GlobalKey<TrainerCalendarScreenState>();
  final _scheduleKey = GlobalKey<TrainerScheduleScreenState>();

  static const _scheduleTab = 1;

  static const _navItems = [
    AppNavItem(label: '홈', icon: AppIcons.home, activeIcon: AppIcons.homeFill),
    AppNavItem(
      label: '일정',
      icon: AppIcons.calendar,
      activeIcon: AppIcons.calendarFill,
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
      TrainerCalendarScreen(key: _calendarKey),
      TrainerScheduleScreen(key: _scheduleKey),
      const _TrainerProfileTab(),
    ];
    FcmService.pendingTarget.addListener(_handleNotificationTarget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleNotificationTarget(),
    );
  }

  @override
  void dispose() {
    FcmService.pendingTarget.removeListener(_handleNotificationTarget);
    super.dispose();
  }

  void _handleNotificationTarget() {
    if (!mounted || FcmService.pendingTarget.value == null) return;
    switch (FcmService.takePendingTarget()) {
      case NotificationTarget.ptSchedule:
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _currentIndex = _scheduleTab);
        _scheduleKey.currentState?.refresh();
      case NotificationTarget.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _currentIndex = 0);
        _calendarKey.currentState?.refresh();
      case NotificationTarget.notices:
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NoticeListScreen()));
      // 트레이너에게는 피드백 알림이 오지 않는다.
      case NotificationTarget.feedback:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
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
              onTap: (i) {
                // 홈에서 기록한 PT가 일정 탭에, 일정 탭의 예약이 홈에 바로 보이도록 다시 불러온다.
                if (i != _currentIndex) {
                  if (i == 0) _calendarKey.currentState?.refresh();
                  if (i == _scheduleTab) _scheduleKey.currentState?.refresh();
                }
                setState(() => _currentIndex = i);
              },
              items: _navItems,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 마이 탭 (시안 Tr-My): 프로필 줄 → 센터(공지사항) → 계정(비밀번호 재설정 메일 · 화면 테마 · 로그아웃) → 탈퇴 링크
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerProfileTab extends StatelessWidget {
  const _TrainerProfileTab();

  static const _sectionPadding = EdgeInsets.fromLTRB(
    AppSpacing.screenH,
    18,
    AppSpacing.screenH,
    AppSpacing.xs,
  );

  Future<void> _signOut(BuildContext context) async {
    await context.read<UserProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.memberLogin);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final subtitle = [
      '트레이너',
      if ((user?.centerName ?? '').isNotEmpty) user!.centerName,
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSize.navClearance),
          children: [
            const AppHero(title: '마이', divider: false),
            AppProfileRow(name: user?.name ?? '', subtitle: subtitle),
            // 시안 Tr-My: 8 회색 띠 → '센터'(15 mute, 18 20 4) → 공지 줄
            const AppSectionBand(),
            const AppMonthHeader(label: '센터', padding: _sectionPadding),
            const NoticeMenuRow(),
            const AppSectionBand(top: AppSpacing.md),
            const AppMonthHeader(label: '계정', padding: _sectionPadding),
            AppActionRow(
              icon: AppIcons.lock,
              label: '비밀번호 재설정 메일',
              menu: true,
              onTap: () =>
                  showPasswordResetSheet(context, initialEmail: user?.email),
            ),
            const AppRowDivider.inset(),
            const ThemeSettingRow(),
            const AppRowDivider.inset(),
            AppActionRow(
              icon: AppIcons.signOut,
              label: '로그아웃',
              menu: true,
              showChevron: false,
              onTap: () => _signOut(context),
            ),
            const AppRowDivider.inset(),
            const SizedBox(height: AppSpacing.xl),
            const DeleteAccountLink(),
          ],
        ),
      ),
    );
  }
}
