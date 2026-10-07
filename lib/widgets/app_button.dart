import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;

    final height = switch (widget.size) {
      AppButtonSize.sm => 40.0,
      AppButtonSize.md => 52.0,
      AppButtonSize.lg => 56.0,
    };

    final hPad = switch (widget.size) {
      AppButtonSize.sm => 16.0,
      AppButtonSize.md => 24.0,
      AppButtonSize.lg => 28.0,
    };

    // Toss 스타일: sm은 sm 반경, md/lg는 lg 반경
    final radius = switch (widget.size) {
      AppButtonSize.sm => AppRadius.xs,
      AppButtonSize.md => AppRadius.xs,
      AppButtonSize.lg => AppRadius.xs,
    };

    final bg = switch (widget.variant) {
      AppButtonVariant.primary =>
        disabled
            ? AppColors.brand.withValues(alpha: 0.35)
            : AppColors.brand,
      AppButtonVariant.secondary =>
        disabled
            ? AppColors.bg
            : AppColors.bg,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.danger =>
        disabled
            ? AppColors.destructive.withValues(alpha: 0.4)
            : AppColors.destructive,
    };

    final fg = switch (widget.variant) {
      AppButtonVariant.primary =>
        disabled ? AppColors.textDisabled : AppColors.textOnAccent,
      AppButtonVariant.secondary =>
        disabled ? AppColors.textDisabled : AppColors.textPrimary,
      AppButtonVariant.ghost =>
        disabled ? AppColors.textDisabled : AppColors.brand,
      AppButtonVariant.danger => AppColors.textOnAccent,
    };

    final border = switch (widget.variant) {
      AppButtonVariant.secondary => Border.all(
        color: AppColors.border,
        width: 1.0,
      ),
      _ => null,
    };

    final content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 18),
                  child: widget.icon!,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppTextStyles.button.copyWith(
                  color: fg,
                  fontSize: switch (widget.size) {
                    AppButtonSize.sm => 14.0,
                    AppButtonSize.md => 16.0,
                    AppButtonSize.lg => 16.0,
                  },
                ),
              ),
            ],
          );

    Widget button = GestureDetector(
      onTap: disabled ? null : widget.onPressed,
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
      ),
    );

    if (widget.fullWidth) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}
