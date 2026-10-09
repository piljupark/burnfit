import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 앱 전체 Navigator. 화면 context가 없을 때(푸시 알림, 닫힌 시트 뒤) 토스트를 띄우는 데 쓴다.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 토스트 앞 표시 (주황 원 24 안의 기호).
enum AppToastKind {
  /// 표시 없음 (제목이 있는 알림 토스트)
  none,

  /// 체크 — 선을 그리며 나타남 (완료·발송)
  success,

  /// '!' (오류·경고)
  error,

  /// 시계 (기다림, 예: 승인 대기)
  wait,
}

/// 화면 위쪽 토스트 (시안 Com-Login-Error·ResetSent·Pending·Toast-Push). 앱 전체에서 이것만 쓴다 — SnackBar 금지.
///
/// - 위치: 안전 영역 아래 12, 좌우 16. 최소 높이 56, 반경 18, 검정(#191919, 두 테마 공통) 면.
/// - 앞 표시: 주황 원 24 + 기호([AppToastKind]), 사이 10. 글자 15/500 흰색.
/// - 제목이 있으면(알림): 제목 15/500 한 줄 + 본문 14 흰색 70%, 오른쪽 '보기' 15/500 주황.
/// - 움직임: 화면 밖 위에서 내려옴 450ms (AppMotion.sheet), 페이드 없음. 위로 밀면 닫힌다.
/// - 한 번에 하나: 새 토스트가 이전 것을 바로 바꾼다. 스크린리더는 live region으로 읽는다.
class AppToast {
  AppToast._();

  static const _defaultDuration = Duration(milliseconds: 3200);

  static OverlayEntry? _entry;
  static Timer? _timer;
  static GlobalKey<_ToastViewState>? _viewKey;

  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    AppToastKind? kind,
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
        kind:
            kind ?? (title != null ? AppToastKind.none : AppToastKind.success),
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
  final AppToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const _ToastView({
    super.key,
    required this.message,
    required this.title,
    required this.kind,
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
    duration: const Duration(milliseconds: 450),
  );
  bool _dismissing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    if (!AppMotion.reduced(context)) await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + AppSpacing.md;
    final slide = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.sheet,
      reverseCurve: Curves.easeIn,
    );
    final hasAction = widget.actionLabel != null && widget.onAction != null;
    final white = Colors.white;

    return Positioned(
      top: top,
      left: AppSpacing.base,
      right: AppSpacing.base,
      child: AnimatedBuilder(
        animation: slide,
        builder: (context, child) => Transform.translate(
          // 토스트 높이(약 56)와 위 여백만큼 화면 밖에서 내려온다.
          offset: Offset(0, -(top + 72) * (1 - slide.value)),
          child: child,
        ),
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
                constraints: const BoxConstraints(minHeight: 56),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  widget.title != null ? AppSpacing.md : 14,
                  hasAction ? 6 : AppSpacing.base,
                  widget.title != null ? AppSpacing.md : 14,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.timerBar,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.kind != AppToastKind.none) ...[
                      _ToastMark(kind: widget.kind, progress: _controller),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              style: AppTextStyles.bodyMd.medium.copyWith(
                                color: white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.title != null) const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: widget.title != null
                                ? AppTextStyles.buttonLabel.copyWith(
                                    color: white.withValues(alpha: 0.7),
                                    height: 1.4,
                                  )
                                : AppTextStyles.bodyMd.medium.copyWith(
                                    color: white,
                                    height: 1.4,
                                  ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasAction) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Semantics(
                        button: true,
                        child: InkWell(
                          onTap: () {
                            widget.onAction!();
                            dismiss();
                          },
                          customBorder: const StadiumBorder(),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: AppSize.touchMin,
                              minHeight: AppSize.touchMin,
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: AppTextStyles.bodyMd.medium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 주황 원 24 안의 기호. 체크는 토스트가 내려온 뒤 선을 그리며 나타난다 (시안 `check`).
class _ToastMark extends StatelessWidget {
  final AppToastKind kind;
  final Animation<double> progress;

  const _ToastMark({required this.kind, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => CustomPaint(
          painter: _MarkPainter(
            kind: kind,
            // 내려오는 동안(앞 절반)은 비어 있다가 뒤 절반에 그려진다
            draw: AppMotion.reduced(context)
                ? 1
                : ((progress.value - 0.5) * 2).clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final AppToastKind kind;
  final double draw;

  const _MarkPainter({required this.kind, required this.draw});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = AppPalette.light.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case AppToastKind.success:
        // 시안 체크 'm7 12.5 3.2 3.2L17 8.8' (선 3.4/24 × 24)
        final path = Path()
          ..moveTo(7, 12.5)
          ..lineTo(10.2, 15.7)
          ..lineTo(17, 8.8);
        for (final metric in path.computeMetrics()) {
          canvas.drawPath(
            metric.extractPath(0, metric.length * draw),
            paint..strokeWidth = 2.6,
          );
        }
      case AppToastKind.error:
        paint.strokeWidth = 2.6;
        canvas.drawLine(const Offset(12, 7.5), const Offset(12, 13), paint);
        canvas.drawCircle(
          const Offset(12, 16.6),
          1.5,
          Paint()..color = AppPalette.light.ink,
        );
      case AppToastKind.wait:
        paint.strokeWidth = 2.2;
        canvas.drawCircle(const Offset(12, 12), 6.5, paint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 8.6)
            ..lineTo(12, 12)
            ..lineTo(14.4, 13.4),
          paint,
        );
      case AppToastKind.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.draw != draw || oldDelegate.kind != kind;
}
