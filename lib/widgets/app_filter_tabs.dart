import 'package:flutter/material.dart';

import '../core/app_spacing.dart';
import 'app_tag.dart';

/// 필터 탭: pill 칩 줄 (선택 = 흰 채움). 넘치면 가로로 스크롤한다.
class AppFilterTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int) onChanged;
  final List<IconData>? icons;

  const AppFilterTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return AppScrollableChips(
      labels: tabs,
      selectedIndex: selectedIndex,
      onSelected: onChanged,
      icons: icons,
    );
  }
}

class AppScrollableChips extends StatelessWidget {
  final List<String> labels;
  final int? selectedIndex;
  final void Function(int) onSelected;
  final List<IconData>? icons;
  final EdgeInsetsGeometry padding;

  const AppScrollableChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: labels[i],
              selected: i == selectedIndex,
              icon: icons != null && i < icons!.length ? icons![i] : null,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}
