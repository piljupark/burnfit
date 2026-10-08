import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 앱 전체 Navigator. 화면 context가 없을 때(푸시 알림, 닫힌 시트 뒤) 토스트를 띄우는 데 쓴다.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 화면 위쪽 토스트 (앱 전체에서 이것만 쓴다 — SnackBar 금지).
///
/// - 위치: 상태 표시줄 바로 아래, 좌우 16 여백의 화면 폭. 화면·하단 탭·시트와 관계없이 폭이 같다.
/// - 모양: 검정 채움 + 둥근 사각형, 선택 아이콘(주황 원 배지), 선택 제목, 선택 글자 행동 하나(주황 글자).
/// - 한 번에 하나: 새 토스트가 이전 것을 바로 바꾼다. 위로 밀면 닫힌다.
/// - 스크린리더: live region으로 읽힌다. 움직임 줄이기면 애니메이션 없이 나타난다.
class AppToast {
  AppToast._();

  static const _defaultDuration = Duration(seconds: 3);

  static OverlayEntry? _entry;
  static Timer? _timer;
  static GlobalKey<_ToastViewState>? _viewKey;

  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = _defaultDuration,
  }) {
    final overlay =
        (context != null && context.mounted
            ? Overlay.maybeOf(context, rootOverlay: true)
            : null) ??
        appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _removeNow();
    final viewKey = GlobalKey<_ToastViewState>();
    final entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: viewKey,
        message: message,
        title: title,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: () => _removeEntry(viewKey),
      ),
    );
    _entry = entry;
    _viewKey = viewKey;
    overlay.insert(entry);
    _timer = Timer(duration, () => viewKey.currentState?.dismiss());
  }

  /// 떠 있는 토스트를 닫는다 (없으면 아무 일도 없다).
  static void hide() => _viewKey?.currentState?.dismiss();

  static void _removeEntry(GlobalKey<_ToastViewState> key) {
    if (_viewKey != key) return; // 이미 새 토스트로 바뀜
    _removeNow();
  }

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _viewKey = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const _ToastView({
    super.key,
    required this.message,
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.onDismissed,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _dismissing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion) await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    final hasAction = widget.actionLabel != null && widget.onAction != null;

    return Positioned(
      top: top,
      left: AppSpacing.screenH,
      right: AppSpacing.screenH,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(curved),
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) dismiss();
            },
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.md,
                    hasAction ? AppSpacing.sm : AppSpacing.base,
                    AppSpacing.md,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 14,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null)
                              Text(
                                widget.title!,
                                style: AppTextStyles.buttonLabel.copyWith(
                                  color: AppColors.canvas,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              widget.message,
                              style: widget.title != null
                                  ? AppTextStyles.bodySm.copyWith(
                                      color: AppColors.canvas.withValues(
                                        alpha: 0.7,
                                      ),
                                    )
                                  : AppTextStyles.buttonLabel.copyWith(
                                      color: AppColors.canvas,
                                    ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasAction)
                        TextButton(
                          onPressed: () {
                            widget.onAction!();
                            dismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(
                              AppSize.touchMin,
                              AppSize.touchMin,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: AppTextStyles.buttonLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
