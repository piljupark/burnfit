import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 로딩 표시: 점 세 개가 차례로 진해졌다 흐려진다 (시안 Com-Splash 하단 점).
///
/// - 화면·목록 자리 로딩: [AppLoader.screen] (점 6, 간격 8)
/// - 버튼·줄 안: [AppLoader.inline] (점 4, 간격 4)
/// - 기기 설정에서 움직임 줄이기를 켜면 멈춘 점을 그린다.
class AppLoader extends StatefulWidget {
  final double dotSize;
  final double gap;
  final Color? color;
  final String? semanticLabel;

  const AppLoader({
    super.key,
    this.dotSize = 6,
    this.gap = AppSpacing.sm,
    this.color,
    this.semanticLabel = '불러오는 중',
  });

  const AppLoader.screen({super.key, this.color, this.semanticLabel = '불러오는 중'})
    : dotSize = 6,
      gap = AppSpacing.sm;

  const AppLoader.inline({super.key, this.color, this.semanticLabel = '처리 중'})
    : dotSize = 4,
      gap = AppSpacing.xs;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  // 한 바퀴 1.2초, 점마다 0.2초씩 늦게 (시안 animation: dots 1.2s, delay .2s/.4s)
  static const _period = Duration(milliseconds: 1200);
  static const _delay = 0.2 / 1.2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0.25 → 1 → 0.25 (ease-in-out)
  double _opacity(int index) {
    if (_reduceMotion) return 1;
    final phase = (_controller.value - index * _delay) % 1;
    final triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.25 + 0.75 * Curves.easeInOut.transform(triangle);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.ink;
    return Semantics(
      label: widget.semanticLabel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: widget.gap),
                Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _opacity(i)),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 화면 가운데 로딩 (선택적으로 캡션).
class AppLoadingView extends StatelessWidget {
  final String? caption;

  const AppLoadingView({super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoader.screen(),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.base),
            Text(caption!, style: AppTextStyles.counter),
          ],
        ],
      ),
    );
  }
}
