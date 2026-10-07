import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (i) {
          final selected = i == selectedIndex;

          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xs - 2),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icons != null) ...[
                    Icon(
                      icons![i],
                      size: 15,
                      color: selected
                          ? AppColors.brand
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    tabs[i],
                    style: AppTextStyles.label.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppScrollableChips extends StatelessWidget {
  final List<String> labels;
  final int? selectedIndex;
  final void Function(int) onSelected;

  const AppScrollableChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;

          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: !selected
                    ? const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: AppTextStyles.label.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
