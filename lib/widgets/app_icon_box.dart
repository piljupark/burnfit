import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';

/// 아이콘 상자: 40 둥근 사각형(반경 12) + canvasCard 면, 아이콘 20 (Bold 굵기).
/// [background]·[iconColor]는 강조 줄(예: PT 운동 = noticeBg + noticeText)에만 바꾼다.
class AppIconBox extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? iconColor;
  final double size;

  const AppIconBox({
    super.key,
    required this.icon,
    this.background,
    this.iconColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.iconBox),
      ),
      // 20 크기에서는 Bold(선 약 1.9)가 시안 선 1.8에 가장 가깝다
      child: Icon(
        AppIcons.bold(icon),
        size: size * 0.5,
        color: iconColor ?? AppColors.ink,
      ),
    );
  }
}
