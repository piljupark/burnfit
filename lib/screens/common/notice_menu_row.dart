import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_text_styles.dart';
import '../../services/notice_read_store.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import 'notice_list_screen.dart';

/// 마이 탭 '센터' 섹션의 공지사항 줄. 새 글이 있으면 점 + '새 글 n'.
class NoticeMenuRow extends StatefulWidget {
  /// 아이콘 없는 글자 줄([AppPlainRow], 회원 마이)
  final bool plain;

  const NoticeMenuRow({super.key, this.plain = false});

  @override
  State<NoticeMenuRow> createState() => _NoticeMenuRowState();
}

class _NoticeMenuRowState extends State<NoticeMenuRow> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      final items = await NoticeService.getForViewer(user.centerId, user.role);
      final lastSeen = await NoticeReadStore.lastSeen(user.uid);
      if (!mounted) return;
      setState(() => _unread = NoticeReadStore.unreadCount(items, lastSeen));
    } catch (e) {
      AppLogger.debug('[공지 새 글 수 로드 실패] $e');
    }
  }

  Future<void> _open() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoticeListScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plain) {
      return AppPlainRow(
        label: '공지사항',
        onTap: _open,
        trailing: _unread > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.newDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '새 글 $_unread',
                    style: AppTextStyles.eyebrow.medium.copyWith(
                      color: AppColors.noticeText,
                    ),
                  ),
                ],
              )
            : null,
      );
    }
    // 시안 Tr-My: 60 메뉴 줄, 확성기 아이콘, '● 새 글 N'(15/500 noticeText) + 18 화살표
    return AppActionRow(
      icon: AppIcons.megaphone,
      label: '공지사항',
      onTap: _open,
      menu: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_unread > 0) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.newDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '새 글 $_unread',
              style: AppTextStyles.eyebrow.medium.copyWith(
                color: AppColors.noticeText,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(AppIcons.chevronRightBold, size: 18, color: AppColors.chevron),
        ],
      ),
    );
  }
}
