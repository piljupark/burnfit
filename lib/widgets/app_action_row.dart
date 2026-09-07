import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

class AppActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
  final bool isDestructive;
  final Color? iconColor;

  const AppActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.isDestructive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.destructive : AppColors.textPrimary;
    final iColor = iconColor ?? (isDestructive ? AppColors.destructive : AppColors.brand);
    final bColor = badgeColor ?? AppColors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.brand.withValues(alpha: 0.04),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iColor,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const Gap(AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: badge != null
                              ? bColor.withValues(alpha: 0.8)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    badge!,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: bColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!isDestructive)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.base + 40 + AppSpacing.md),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: AppColors.border,
      ),
    );
  }
}
