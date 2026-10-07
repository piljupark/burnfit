import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_target.dart';
import '../../widgets/app_nav_bar.dart';
import 'member_calendar_screen.dart';
import 'member_profile_screen.dart';
import 'member_pt_schedule_screen.dart';
import 'member_routes.dart';
import 'member_workout_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _currentIndex = 0;
  final _calendarKey = GlobalKey<MemberCalendarScreenState>();
  final _ptScheduleKey = GlobalKey<MemberPtScheduleScreenState>();

  static const _homeTab = 0;
  static const _ptTab = 2;

  static const _navItems = [
    AppNavItem(label: '홈', icon: AppIcons.home, activeIcon: AppIcons.homeFill),
    AppNavItem(label: '운동', icon: AppIcons.workout, activeIcon: AppIcons.workoutFill),
    AppNavItem(label: 'PT', icon: AppIcons.calendar, activeIcon: AppIcons.calendarFill),
    AppNavItem(label: '마이', icon: AppIcons.profile, activeIcon: AppIcons.profileFill),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MemberCalendarScreen(key: _calendarKey, showGreeting: true),
      const MemberWorkoutScreen(showAsTab: true),
      MemberPtScheduleScreen(key: _ptScheduleKey, showBackButton: false),
      const MemberProfileScreen(),
    ];
    FcmService.pendingTarget.addListener(_handleNotificationTarget);
    // 앱이 알림으로 실행된 경우: 첫 프레임 뒤 처리 (Navigator 준비 후)
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationTarget());
  }

  @override
  void dispose() {
    FcmService.pendingTarget.removeListener(_handleNotificationTarget);
    super.dispose();
  }

  Future<void> _handleNotificationTarget() async {
    if (!mounted || FcmService.pendingTarget.value == null) return;
    switch (FcmService.takePendingTarget()) {
      case NotificationTarget.feedback:
        _selectTab(_homeTab);
        await MemberRoutes.openFeedback(context);
        _calendarKey.currentState?.refresh();
      case NotificationTarget.ptSchedule:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _selectTab(_ptTab);
        _ptScheduleKey.currentState?.refresh();
      case null:
        break;
    }
  }

  void _selectTab(int index) {
    if (index == _homeTab && _currentIndex != _homeTab) {
      _calendarKey.currentState?.refresh();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              onTap: _selectTab,
              items: _navItems,
            ),
          ),
        ],
      ),
    );
}
