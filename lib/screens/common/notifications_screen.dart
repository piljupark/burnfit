import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0,
              ),
              child: AppScreenHeader(
                title: '알림',
                subtitle: '${NotificationService.retentionDays}일 동안 보관돼요',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _items.isEmpty,
                onRefresh: _load,
                empty: const AppEmptyState(
                  icon: Iconsax.notification,
                  message: '받은 알림이 없습니다.',
                ),
                children: [
                  for (final item in _items) ...[
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
                    const Gap(AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool isNew;
  final VoidCallback? onTap;

  const _NotificationTile({required this.item, required this.isNew, this.onTap});

  static IconData _iconFor(NotificationTarget? target) {
    switch (target) {
      case NotificationTarget.feedback:
        return Iconsax.message_text_1;
      case NotificationTarget.ptSchedule:
        return Iconsax.calendar_1;
      case null:
        return Iconsax.notification;
    }
  }

  static Color _colorFor(NotificationTarget? target) {
    switch (target) {
      case NotificationTarget.feedback:
        return AppColors.trainer;
      case NotificationTarget.ptSchedule:
        return AppColors.brand;
      case null:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.target);
    return Semantics(
      button: onTap != null,
      label: isNew ? '새 알림, ${item.title}' : item.title,
      child: Material(
        color: isNew ? AppColors.brand.withValues(alpha: 0.06) : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(_iconFor(item.target), size: 18, color: color),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: isNew ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (item.createdAt != null)
                            Text(
                              formatRelativeTime(item.createdAt!),
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      if (item.body.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          item.body,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isNew) ...[
                  const Gap(AppSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
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
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: const Icon(Iconsax.trash, color: AppColors.textOnAccent),
    );
  }
}
