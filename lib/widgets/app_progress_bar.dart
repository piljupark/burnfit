import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';

/// 진행 막대: canvasMid pill 트랙 + ink 채움. 요약 수치 아래는 2, 목록 막대는 4.
class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final String? semanticLabel;

  const AppProgressBar({super.key, required this.value, this.height = 2, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: height,
          color: AppColors.canvasMid,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            heightFactor: 1,
            child: const ColoredBox(color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
