import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// Galloway의 유일한 움직임: 흑백 점 구체. 스피너·스켈레톤 대신 쓴다.
///
/// - 화면 단위 로딩: [OrbLoader.screen] (64px)
/// - 버튼·줄 안: [OrbLoader.inline] (20px)
/// - 기기 설정에서 움직임 줄이기를 켜면 정지한 구체를 그린다.
class OrbLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final String? semanticLabel;

  const OrbLoader({
    super.key,
    this.size = AppSize.orbLoader,
    this.color,
    this.semanticLabel,
  });

  const OrbLoader.screen({super.key, this.color, this.semanticLabel = '불러오는 중'})
    : size = AppSize.orbLoader;

  const OrbLoader.inline({super.key, this.color, this.semanticLabel = '처리 중'})
    : size = AppSize.orbInline;

  @override
  State<OrbLoader> createState() => _OrbLoaderState();
}

class _OrbLoaderState extends State<OrbLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(
                angle: _controller.value * 2 * math.pi,
                color: widget.color ?? AppColors.ink,
                dense: widget.size >= 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool dense;

  _OrbPainter({required this.angle, required this.color, required this.dense});

  // 피보나치 구면 점 (단위 구)
  static List<List<double>> _points(int n) {
    final golden = math.pi * (3 - math.sqrt(5));
    return List.generate(n, (i) {
      final y = 1 - (i / (n - 1)) * 2;
      final r = math.sqrt(1 - y * y);
      final theta = golden * i;
      return [math.cos(theta) * r, y, math.sin(theta) * r];
    });
  }

  static final _dense = _points(140);
  static final _sparse = _points(36);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final cosA = math.cos(angle), sinA = math.sin(angle);
    const tilt = 0.35;
    final cosT = math.cos(tilt), sinT = math.sin(tilt);
    final paint = Paint()..isAntiAlias = true;
    final maxDot = dense ? radius * 0.05 : radius * 0.12;

    for (final p in dense ? _dense : _sparse) {
      // Y축 회전 후 X축으로 살짝 기울인다.
      final x1 = p[0] * cosA + p[2] * sinA;
      final z1 = -p[0] * sinA + p[2] * cosA;
      final y2 = p[1] * cosT - z1 * sinT;
      final z2 = p[1] * sinT + z1 * cosT;
      final depth = (z2 + 1) / 2; // 0(뒤) ~ 1(앞)
      paint.color = color.withValues(alpha: 0.15 + 0.85 * depth);
      canvas.drawCircle(
        center + Offset(x1 * radius * 0.92, y2 * radius * 0.92),
        maxDot * (0.45 + 0.55 * depth),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.angle != angle || old.color != color;
}

/// 화면 가운데 로딩 (선택적으로 모노 캡션).
class AppLoadingView extends StatelessWidget {
  final String? caption;

  const AppLoadingView({super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OrbLoader.screen(),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(caption!.toUpperCase(), style: AppTextStyles.counter),
          ],
        ],
      ),
    );
  }
}
