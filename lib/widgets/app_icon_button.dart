import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';

/// 원형 아이콘 버튼: 44px 터치 영역, 20px Phosphor Light 아이콘.
/// 아이콘만 있는 버튼이므로 [label](스크린리더·툴팁)은 필수다.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool showDot;
  final Color color;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.showDot = false,
    this.color = AppColors.ink,
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
          shape: CircleBorder(
            side: outlined ? const BorderSide(color: AppColors.outline) : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            highlightColor: AppColors.canvasSoft,
            child: SizedBox.square(
              dimension: AppSize.touchMin,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: AppSize.icon, color: onPressed == null ? AppColors.mute : color),
                  if (showDot)
                    Positioned(
                      top: 11,
                      right: 11,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
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
