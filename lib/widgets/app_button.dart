import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'orb_loader.dart';

/// 버튼 모양은 pill 하나뿐.
/// - [primary]: 흰 채움. 화면당 하나의 주 행동에만.
/// - [secondary]: 흰 외곽선(기본 모양). 대부분의 행동.
/// - [ghost]: 테두리 없음. 취소·보조 행동.
/// - [danger]: 외곽선 + 빨간 글자. 되돌릴 수 없는 행동에만.
/// - [dangerText]: 테두리 없는 빨간 글자.
enum AppButtonVariant { primary, secondary, ghost, danger, dangerText }

/// sm 32 · md 40 · lg 52(폼 대표 버튼). 시각 높이와 별개로 터치 영역은 44 이상.
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
      AppButtonSize.sm => AppSize.buttonHeightSm,
      AppButtonSize.md => AppSize.buttonHeight,
      AppButtonSize.lg => AppSize.buttonHeightLg,
    };
    final hPad = switch (size) {
      AppButtonSize.sm => AppSpacing.md,
      AppButtonSize.md => AppSpacing.base,
      AppButtonSize.lg => AppSpacing.xl,
    };
    final fontSize = switch (size) {
      AppButtonSize.sm => 13.0,
      AppButtonSize.md => 14.0,
      AppButtonSize.lg => 15.0,
    };
    final isPrimary = variant == AppButtonVariant.primary;
    final fg = switch (variant) {
      AppButtonVariant.primary => AppColors.onPrimary,
      AppButtonVariant.danger || AppButtonVariant.dangerText => AppColors.danger,
      _ => AppColors.ink,
    };
    final borderColor = switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary || AppButtonVariant.danger => AppColors.outline,
      _ => Colors.transparent,
    };

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          OrbLoader.inline(color: fg),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          IconTheme(data: IconThemeData(color: fg, size: 18), child: icon!),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.buttonLabel.copyWith(color: fg, fontSize: fontSize),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled && !isLoading ? 0.4 : 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touchMin),
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              height: height,
              width: fullWidth ? double.infinity : null,
              child: Material(
                color: isPrimary ? AppColors.primary : Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: borderColor)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: disabled ? null : onPressed,
                  // 눌림: 외곽선은 canvasSoft, primary는 body
                  highlightColor: isPrimary ? AppColors.body : AppColors.canvasSoft,
                  splashFactory: NoSplash.splashFactory,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
