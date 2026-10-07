import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_target.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
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
    AppNavItem(
      label: '홈',
      icon: Iconsax.home,
      activeIcon: Iconsax.home,
    ),
    AppNavItem(
      label: '일정',
      icon: Iconsax.calendar_1,
      activeIcon: Iconsax.calendar_1,
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
                  AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, 0,
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
                    const Gap(AppSpacing.lg),
                    const DeleteAccountLink(),
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
