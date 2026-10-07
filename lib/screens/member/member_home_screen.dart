import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_nav_bar.dart';
import 'member_calendar_screen.dart';
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
  final _calendarKey = GlobalKey<MemberCalendarScreenState>();

  static const _navItems = [
    AppNavItem(
      label: '홈',
      icon: Iconsax.home,
      activeIcon: Iconsax.home,
    ),
    AppNavItem(
      label: '운동',
      icon: Iconsax.activity,
      activeIcon: Iconsax.activity,
    ),
    AppNavItem(
      label: 'PT',
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
      MemberCalendarScreen(key: _calendarKey, showGreeting: true),
      const MemberWorkoutScreen(showAsTab: true),
      const MemberPtScheduleScreen(showBackButton: false),
      const MemberProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
