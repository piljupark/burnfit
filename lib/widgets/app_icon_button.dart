import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';

/// 원형 아이콘 버튼: 44px 터치 영역, 기본 20px 아이콘 ([iconSize]로 바꾼다 — 알림 종은 24).
/// 아이콘만 있는 버튼이므로 [label](스크린리더·툴팁)은 필수다.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool showDot;
  final Color? color;
  final double iconSize;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.showDot = false,
    this.color,
    this.iconSize = AppSize.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          // [outlined]는 호출부 호환용 — 외곽선은 그리지 않는다.
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            highlightColor: AppColors.canvasSoft,
            child: SizedBox.square(
              dimension: AppSize.touchMin,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: onPressed == null
                        ? AppColors.mute
                        : (color ?? AppColors.ink),
                  ),
                  if (showDot)
                    // 점은 아이콘 오른쪽 위 모서리에서 1px 안쪽 (20 → 11, 24 → 9)
                    Positioned(
                      top: (AppSize.touchMin - iconSize) / 2 - 1,
                      right: (AppSize.touchMin - iconSize) / 2 - 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.newDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
