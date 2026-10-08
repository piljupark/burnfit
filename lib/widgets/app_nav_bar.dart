import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 하단 탭 항목. [icon]은 Phosphor Light, [activeIcon]은 같은 아이콘의 Fill.
class AppNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const AppNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// 하단 탭: canvas 바탕 + 위 hairline. 선택은 색이 아니라 모양(Fill)으로 바꾸고 글자도 ink로.
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<AppNavItem> items;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 56,
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == currentIndex;
            final item = items[i];
            final color = active ? AppColors.ink : AppColors.mute;
            return Expanded(
              child: Semantics(
                button: true,
                selected: active,
                label: item.label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: AppSize.iconNav,
                        color: color,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.label,
                        style: AppTextStyles.badge.copyWith(
                          color: color,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
