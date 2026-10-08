import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 하단 탭 항목. [icon]은 Phosphor Regular, [activeIcon]은 같은 아이콘의 Fill.
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

/// 하단 탭: canvas 바탕 + 위 hairline. 선택 = Fill 아이콘 + ink 500 글자, 나머지 = Regular 아이콘 + faint 글자.
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

  /// 안전 영역을 뺀 탭 바 높이 (위 여백 10 + 줄 44). 탭 바 위에 띄우는 것의 위치 계산용.
  static const double contentHeight = 54;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      // 시안: 위 10 여백 + 아이콘 26 + 4 + 글자 11/14 = 54, 그 아래는 기기 안전 영역
      padding: EdgeInsets.only(top: 10, bottom: bottom),
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(items.length, (i) {
            final active = i == currentIndex;
            final item = items[i];
            final color = active ? AppColors.ink : AppColors.faint;
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
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
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
