import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../screens/common/notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/user_provider.dart';
import 'app_icon_button.dart';

/// 홈 상단 알림 버튼. 안 읽은 알림이 있으면 점을 표시하고, 누르면 알림함을 연다.
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
        return AppIconButton(
          icon: AppIcons.bell,
          label: unread > 0 ? '알림, 새 알림 $unread개' : '알림',
          showDot: unread > 0,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      },
    );
  }
}
