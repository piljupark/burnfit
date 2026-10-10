import 'dart:math' as math;

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
import '../../widgets/app_motion.dart';
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
            AppScreenHeader.large(
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
                // 시안: 목록은 머리 아래 12, 빈 카드는 24 (AppAsyncBody가 24를 둔다)
                padding: _items.isEmpty
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(top: AppSpacing.md),
                empty: const AppEmptyState(
                  icon: AppIcons.bell,
                  message: '받은 알림이 없어요',
                  description: 'PT 일정이나 피드백 소식이 오면 여기에 모여요.',
                  card: true,
                  illustration: _EmptyBellArt(),
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                ),
                children: [
                  // 시안 `row`: 줄마다 0.05초씩 늦게 아래 8에서 올라온다
                  for (var i = 0; i < _items.length; i++)
                    AppEntrance(
                      key: ValueKey('in-${_items[i].id}'),
                      offset: const Offset(0, 8),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 50 * i),
                      child: Dismissible(
                        key: ValueKey(_items[i].id),
                        direction: DismissDirection.endToStart,
                        background: const _DeleteBackground(),
                        onDismissed: (_) => _delete(_items[i]),
                        child: _NotificationTile(
                          item: _items[i],
                          isNew: _newIds.contains(_items[i].id),
                          onTap: _items[i].target == null
                              ? null
                              : () => _open(_items[i]),
                        ),
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

/// 알림 한 줄 (시안 Com-Notifications): 여백 14 20, 아이콘 상자 40 + 간격 12,
/// 제목 16/500 · 내용 15 body(위 2, 줄 높이 1.45) · 시각 13 faint(위 4). 새 알림은 오른쪽 주황 점(맥박).
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
      case NotificationTarget.workout:
        return AppIcons.workout;
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
            vertical: 14,
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
                    Text(item.title, style: AppTextStyles.listTitle),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.body,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (item.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatRelativeTime(item.createdAt!),
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md, top: 8),
                  child: AppPulse(
                    scale: 1.4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.newDot,
                        shape: BoxShape.circle,
                      ),
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

/// 밀어서 지우기 배경 (시안): 연한 주황 면 + 휴지통 20 + '삭제' 15/500 진한 주황, 간격 6, 오른쪽 24.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.noticeBg,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.trash, color: AppColors.noticeText, size: AppSize.icon),
          const SizedBox(width: 6),
          Text(
            '삭제',
            style: AppTextStyles.bodyMd.medium.copyWith(
              color: AppColors.noticeText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 빈 알림 그림 (시안 Com-Notifications-Empty): 흰 원 72 안 종 32(ink)가 흔들리고(3s),
/// 오른쪽 위 주황 점 6이 떠올랐다 사라진다(2.4s).
class _EmptyBellArt extends StatefulWidget {
  const _EmptyBellArt();

  @override
  State<_EmptyBellArt> createState() => _EmptyBellArtState();
}

class _EmptyBellArtState extends State<_EmptyBellArt>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _ring.stop();
      _float.stop();
      _float.value = 0.3; // 점이 보이는 자리에서 멈춘다
    } else {
      if (!_ring.isAnimating) _ring.repeat();
      if (!_float.isAnimating) _float.repeat();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _float.dispose();
    super.dispose();
  }

  /// 0·60·100% 0°, 10·30·50% −12°, 20·40% +12° (구간마다 ease-in-out)
  static double _bellAngle(double v) {
    const keys = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6];
    const values = [0.0, -12.0, 12.0, -12.0, 12.0, -12.0, 0.0];
    if (v >= 0.6) return 0;
    for (var i = 0; i < keys.length - 1; i++) {
      if (v <= keys[i + 1]) {
        final t = Curves.easeInOut.transform((v - keys[i]) / 0.1);
        return values[i] + (values[i + 1] - values[i]) * t;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ring,
            builder: (context, child) => Transform.rotate(
              angle: _bellAngle(_ring.value) * math.pi / 180,
              // 기준점: 가로 가운데, 위에서 10%
              alignment: const Alignment(0, -0.8),
              child: child,
            ),
            child: Icon(AppIcons.bell, size: 32, color: AppColors.ink),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, child) {
                // 0% (0,0) 투명 → 30% 보임 → 100% (10,−16) 투명 (ease-out)
                final v = _float.value;
                final t = Curves.easeOut.transform(v);
                final opacity = v < 0.3 ? v / 0.3 : 1 - (v - 0.3) / 0.7;
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(10 * t, -16 * t),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
