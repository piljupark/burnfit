import 'dart:math' as math;

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

  /// 새 소식 점(7, newDot)을 아이콘 오른쪽 위에 찍을 탭 (예: 트레이너 식단 — 피드백할 식단이 있을 때).
  final Set<int> dotIndexes;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.dotIndexes = const {},
  });

  /// 위아래 여백 (위 10, 아래는 기기 안전 영역이 더 크면 그만큼)
  static const double _edge = 10;

  /// 안전 영역을 뺀 탭 바 높이 (위 여백 10 + 줄 44).
  static const double contentHeight = _edge + 44;

  /// 탭 바 아래 여백: 기기 안전 영역(홈 표시줄)이 있으면 그 높이, 없으면(웹·데스크톱) 위와 같은 10.
  static double bottomInset(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, _edge);

  /// 화면 아래에서 탭 바 위 선까지의 높이. 탭 바 위에 띄우는 것의 위치 계산용.
  static double totalHeight(BuildContext context) =>
      contentHeight + bottomInset(context);

  @override
  Widget build(BuildContext context) {
    final bottom = bottomInset(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.navLine)),
      ),
      // 시안: 위 10 + 아이콘 26 + 4 + 글자 11/14, 아래는 안전 영역(최소 10 — 위와 같게)
      padding: EdgeInsets.only(top: _edge, bottom: bottom),
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
                label: dotIndexes.contains(i)
                    ? '${item.label}, 새 소식'
                    : item.label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            size: AppSize.iconNav,
                            color: color,
                          ),
                          if (dotIndexes.contains(i))
                            Positioned(
                              top: 0,
                              right: -2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.newDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
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
