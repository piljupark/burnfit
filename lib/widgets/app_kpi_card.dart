import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

class AppKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData? icon;
  final bool isHighlight;

  const AppKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.icon,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.brand.withValues(alpha: 0.08)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isHighlight
              ? AppColors.brand.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: isHighlight ? AppColors.brand : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 14,
                  color: isHighlight ? AppColors.brand : AppColors.textDisabled,
                ),
            ],
          ),
          const Gap(AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: isHighlight ? AppColors.brand : AppColors.textPrimary,
                ),
              ),
              const Gap(4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: isHighlight
                        ? AppColors.brand.withValues(alpha: 0.7)
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
