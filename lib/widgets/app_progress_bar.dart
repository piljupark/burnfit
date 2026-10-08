import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import 'app_motion.dart';

/// 진행 막대: pill 트랙(기본 track #E6E6EA) + 채움(기본 ink). 채움은 왼쪽부터 차오른다
/// (시안 `grow`·`fill`, [animate]=false면 바로 그린다).
class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final String? semanticLabel;
  final Color? color;
  final Color? trackColor;
  final bool animate;
  final Duration delay;
  final Duration duration;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 2,
    this.semanticLabel,
    this.color,
    this.trackColor,
    this.animate = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    // 채움 끝도 둥글게 (시안 막대 채움 border-radius 999px)
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: height,
          color: trackColor ?? AppColors.track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            heightFactor: 1,
            child: animate
                ? AppGrow(delay: delay, duration: duration, child: fill)
                : fill,
          ),
        ),
      ),
    );
  }
}
