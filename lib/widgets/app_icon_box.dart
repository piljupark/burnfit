import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';

/// 아이콘 상자: canvasSoft 면 + hairline, 반경 8, 아이콘 ink.
/// [color]는 기존 호출부 호환용 — 아이콘에 색을 입히지 않는다.
class AppIconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const AppIconBox({super.key, required this.icon, this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Icon(icon, size: size * 0.5, color: AppColors.ink),
    );
  }
}
