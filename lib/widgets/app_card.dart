import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';

enum AppCardVariant { standard, tinted, outlined }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasBorder;
  final bool hasShadow;
  final AppCardVariant variant;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.hasBorder = false,
    this.hasShadow = true,
    this.variant = AppCardVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? switch (variant) {
      AppCardVariant.standard => AppColors.card,
      AppCardVariant.tinted => AppColors.bg,
      AppCardVariant.outlined => AppColors.card,
    };

    final shadow = hasShadow && variant == AppCardVariant.standard
        ? const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ]
        : null;

    final border = (hasBorder || variant == AppCardVariant.outlined)
        ? Border.all(color: AppColors.border, width: 0.75)
        : null;

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      border: border,
      boxShadow: shadow,
    );

    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        splashColor: AppColors.brand.withValues(alpha: 0.04),
        highlightColor: AppColors.brand.withValues(alpha: 0.02),
        child: content,
      ),
    );
  }
}
