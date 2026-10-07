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
import '../../widgets/delete_account_sheet.dart';
import 'trainer_calendar_screen.dart';
import 'trainer_schedule_screen.dart';

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
    AppNavItem(label: '일정', icon: AppIcons.calendar, activeIcon: AppIcons.calendarFill),
    AppNavItem(label: '마이', icon: AppIcons.profile, activeIcon: AppIcons.profileFill),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TrainerCalendarScreen(key: _calendarKey, showGreeting: true),
      TrainerScheduleScreen(key: _scheduleKey),
      const _TrainerProfileTab(),
    ];
    FcmService.pendingTarget.addListener(_handleNotificationTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationTarget());
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
                if (i == 0 && _currentIndex != 0) {
                  _calendarKey.currentState?.refresh();
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
// 마이 탭: AppHero → 프로필 → hairline 목록 → 로그아웃(danger) → 탈퇴 링크
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerProfileTab extends StatelessWidget {
  const _TrainerProfileTab();

  Future<void> _signOut(BuildContext context) async {
    await context.read<UserProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.memberLogin);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final subtitle = [
      if ((user?.centerName ?? '').isNotEmpty) user!.centerName,
      if ((user?.email ?? '').isNotEmpty) user!.email,
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const AppHero(eyebrow: 'BURNFIT · TRAINER', title: '마이'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
              child: AppProfileCard(
                name: user?.name ?? '',
                subtitle: subtitle,
                roleLabel: '트레이너',
                seed: user?.uid,
              ),
            ),
            const AppMonthHeader(label: 'ACCOUNT'),
            AppActionRow(
              icon: AppIcons.signOut,
              label: '로그아웃',
              isDestructive: true,
              onTap: () => _signOut(context),
            ),
            const AppRowDivider(),
            const SizedBox(height: AppSpacing.xl),
            const DeleteAccountLink(),
          ],
        ),
      ),
    );
  }
}
