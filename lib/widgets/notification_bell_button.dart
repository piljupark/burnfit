import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../screens/common/notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/user_provider.dart';
import 'app_icon_button.dart';
import 'app_motion.dart';

/// 홈 상단 알림 버튼. 안 읽은 알림이 있으면 숨 쉬는 점(시안 MemA-Home `pulse`)을 표시하고,
/// 누르면 알림함을 연다.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  String? _uid;
  Stream<int>? _unreadCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 사용자가 바뀔 때만 구독을 새로 만든다 (빌드마다 다시 구독하지 않게).
    final uid = context.watch<UserProvider>().user?.uid;
    if (uid != _uid) {
      _uid = uid;
      _unreadCount = uid == null
          ? null
          : NotificationService.watchUnreadCount(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCount,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return Stack(
          children: [
            AppIconButton(
              icon: AppIcons.bell,
              iconSize: 24,
              label: unread > 0 ? '알림, 새 알림 $unread개' : '알림',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            if (unread > 0)
              // 점: 24 아이콘 오른쪽 위 모서리에서 1px 안쪽 (44 상자 기준 위 9 · 오른쪽 9)
              Positioned(
                top: 9,
                right: 9,
                child: IgnorePointer(
                  child: AppPulse(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.newDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
