import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 진행 고리 (기준 시안 AdminDashboard 완료율): 지름 [size], 선 [stroke], 바탕 track,
/// 채움 주황 둥근 끝(12시에서 시계 방향), 가운데 [label] 24/500. 1.4초 동안 차오른다.
class AppRing extends StatefulWidget {
  /// 0~1
  final double value;
  final String label;
  final double size;
  final double stroke;
  final bool bold;

  const AppRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 112,
    this.stroke = 12,
    this.bold = false,
  });

  @override
  State<AppRing> createState() => _AppRingState();
}

class _AppRingState extends State<AppRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _controller, curve: AppMotion.fill);
    final labelStyle = AppTextStyles.displayMd.natural.copyWith(
      fontSize: 24,
      letterSpacing: 24 * -0.019,
    );
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: t,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            value: widget.value.clamp(0.0, 1.0) * t.value,
            stroke: widget.stroke,
            track: AppColors.track,
            fill: AppColors.primary,
          ),
          child: child,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: widget.bold ? labelStyle.bold : labelStyle,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color track;
  final Color fill;

  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, paint..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint
        ..color = fill
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      old.fill != fill;
}

/// 순위 가로 막대 한 줄 (기준 시안 AdminDashboard '트레이너별'): 위아래 10,
/// 이름 15 + 오른쪽 값 15/500 · 단위 400 mute / (8) 6 높이 막대(바탕 navLine, 채움 ink 또는 [highlight] 주황).
/// [ratio](0~1)만큼 [delay] 뒤 0.9초 동안 차오른다.
class AppRankBar extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double ratio;
  final bool highlight;
  final bool bold;
  final Duration delay;

  const AppRankBar({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    required this.ratio,
    this.highlight = false,
    this.bold = false,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = bold
        ? AppTextStyles.bodyMd.bold
        : AppTextStyles.bodyMd.medium;
    return Semantics(
      label: '$label $value$unit',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value),
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: unit,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.mute,
                          ),
                        ),
                    ],
                  ),
                  style: valueStyle,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.navLine,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                heightFactor: 1,
                child: AppGrow(
                  delay: delay,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: highlight ? AppColors.primary : AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 세로 막대 묶음 (기준 시안 AdminDashboard '주별 PT'): 높이 [height], 칸 사이 14,
/// 칸마다 위 값 13/500 · (8) 막대(반경 10, ink — [highlightIndex]는 주황) · (8) 아래 이름 12 mute.
/// 가장 큰 값이 막대 자리를 꽉 채우고, 막대는 0.08초 간격으로 아래에서 자란다.
class AppColumnChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int? highlightIndex;
  final double height;
  final bool bold;

  const AppColumnChart({
    super.key,
    required this.labels,
    required this.values,
    this.highlightIndex,
    this.height = 150,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, math.max);
    final valueStyle = bold
        ? AppTextStyles.bodySm.bold
        : AppTextStyles.bodySm.medium;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          // 값 줄(18) + 8 + 막대 + 8 + 이름 줄(16)
          final barMax = math.max(0.0, box.maxHeight - 18 - 8 - 8 - 16);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    label: '${labels[i]} ${values[i]}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${values[i]}',
                          style: valueStyle.copyWith(color: AppColors.ink),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppGrow(
                          axis: Axis.vertical,
                          duration: const Duration(milliseconds: 800),
                          delay: Duration(milliseconds: 80 * i),
                          child: Container(
                            height: maxValue == 0
                                ? 0
                                : barMax * values[i] / maxValue,
                            decoration: BoxDecoration(
                              color: i == highlightIndex
                                  ? AppColors.primary
                                  : AppColors.ink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(labels[i], style: AppTextStyles.captionSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
