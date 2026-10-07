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
  /// accentColor kept for API compat — used only for the icon color, not bar
  final Color? accentColor;
  final String? trend;
  final bool? trendUp;

  const AppKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.icon,
    this.isHighlight = false,
    this.accentColor,
    this.trend,
    this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? (isHighlight ? AppColors.brand : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨 + 아이콘
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: color),
            ],
          ),
          const Gap(AppSpacing.sm),
          // 숫자 + 단위
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.numberLarge.copyWith(
                  color: isHighlight ? AppColors.brand : AppColors.textPrimary,
                  letterSpacing: -1.5,
                ),
              ),
              const Gap(4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          // 추세
          if (trend != null) ...[
            const Gap(AppSpacing.xs),
            Row(
              children: [
                Icon(
                  trendUp == true
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: trendUp == true ? AppColors.destructive : AppColors.workout,
                ),
                const Gap(2),
                Text(
                  trend!,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: trendUp == true ? AppColors.destructive : AppColors.workout,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
