import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_feedback.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/relative_time.dart';
import '../../models/app_notification.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_target.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

/// 알림함 (회원·트레이너 공용).
///
/// 열면 목록을 보여준 뒤 모두 읽음 처리한다 (새 알림은 이번 화면에서만 강조).
/// 항목을 누르면 푸시 알림을 눌렀을 때와 같은 화면으로 간다 (역할별 홈이 처리).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  Set<String> _newIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  String? get _uid => context.read<UserProvider>().user?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _isLoading = true);
    try {
      final items = await NotificationService.getRecent(uid);
      if (!mounted) return;
      final unread = items.where((n) => !n.isRead).map((n) => n.id).toSet();
      setState(() {
        _items = items;
        _newIds = {..._newIds, ...unread};
        _errorMessage = null;
      });
      // 읽음 처리 실패는 목록 표시를 막지 않는다 (다음에 열 때 다시 시도).
      NotificationService.markRead(uid, unread).catchError((Object e) {
        AppLogger.debug('[알림 읽음 처리 실패] $e');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(AppNotification item) {
    final target = item.target;
    if (target == null) return;
    // 먼저 닫고 넘긴다: 홈이 대상을 받는 즉시 화면을 열기 때문에,
    // 순서가 바뀌면 방금 열린 화면이 대신 닫힌다.
    Navigator.of(context).pop();
    FcmService.pendingTarget.value = target;
  }

  Future<void> _delete(AppNotification item) async {
    final uid = _uid;
    if (uid == null) return;
    final index = _items.indexOf(item);
    setState(() => _items.removeAt(index));
    try {
      await NotificationService.delete(uid, item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '알림',
              subtitle: '${NotificationService.retentionDays}일 동안 보관돼요',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _items.isEmpty,
                onRefresh: _load,
                padding: EdgeInsets.zero,
                empty: const AppEmptyState(
                  icon: AppIcons.bell,
                  message: '받은 알림이 없어요',
                  description: 'PT 일정이나 피드백 소식이 오면 여기에 모여요.',
                ),
                children: [
                  for (final item in _items)
                    Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: const _DeleteBackground(),
                      onDismissed: (_) => _delete(item),
                      child: _NotificationTile(
                        item: item,
                        isNew: _newIds.contains(item.id),
                        onTap: item.target == null ? null : () => _open(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 한 줄: 아이콘 상자 + 제목(17) + 내용 + 시각. 새 알림은 오른쪽 흰 점(모양)으로 표시한다.
class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool isNew;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.item,
    required this.isNew,
    this.onTap,
  });

  static IconData _iconFor(NotificationTarget? target) {
    switch (target) {
      case NotificationTarget.feedback:
        return AppIcons.feedback;
      case NotificationTarget.ptSchedule:
        return AppIcons.calendar;
      case NotificationTarget.home:
        return AppIcons.home;
      case NotificationTarget.notices:
        return AppIcons.clipboard;
      case null:
        return AppIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: isNew ? '새 알림, ${item.title}' : item.title,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBox(icon: _iconFor(item.target)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTextStyles.bodyLg),
                    if (item.body.isNotEmpty)
                      Text(
                        item.body,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatRelativeTime(item.createdAt!),
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ],
                ),
              ),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm, top: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvasSoft,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.trash, color: AppColors.danger, size: AppSize.icon),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '삭제',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
