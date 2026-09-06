import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    final height = switch (size) {
      AppButtonSize.sm => 40.0,
      AppButtonSize.md => 52.0,
      AppButtonSize.lg => 56.0,
    };

    final hPad = switch (size) {
      AppButtonSize.sm => 16.0,
      AppButtonSize.md => 24.0,
      AppButtonSize.lg => 28.0,
    };

    final fontSize = switch (size) {
      AppButtonSize.sm => 13.0,
      AppButtonSize.md => 15.0,
      AppButtonSize.lg => 16.0,
    };

    final radius = switch (size) {
      AppButtonSize.sm => AppRadius.sm,
      AppButtonSize.md => AppRadius.sm,
      AppButtonSize.lg => AppRadius.sm,
    };

    final bg = switch (variant) {
      AppButtonVariant.primary =>
        disabled
            ? AppColors.brand.withValues(alpha: 0.35)
            : AppColors.brand,
      AppButtonVariant.secondary => AppColors.textNeutral,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.danger =>
        disabled
            ? AppColors.destructive.withValues(alpha: 0.4)
            : AppColors.destructive,
    };

    final fg = switch (variant) {
      AppButtonVariant.primary =>
        disabled ? AppColors.textDisabled : AppColors.textOnAccent,
      AppButtonVariant.secondary =>
        disabled ? AppColors.textDisabled : AppColors.textOnAccent,
      AppButtonVariant.ghost =>
        disabled ? AppColors.textDisabled : AppColors.brand,
      AppButtonVariant.danger => AppColors.textOnAccent,
    };

    final border = switch (variant) {
      AppButtonVariant.secondary => null,
      AppButtonVariant.ghost => null,
      _ => null,
    };

    final content = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 18),
                  child: icon!,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    Widget button = GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: border,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}
