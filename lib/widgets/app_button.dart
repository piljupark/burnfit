import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_loader.dart';

/// 버튼 종류.
/// - [primary]: 주황 채움 + 검정 글자. 화면당 하나의 주 행동에만.
/// - [secondary]: 회색(canvasSoft) 채움. 대부분의 보조 행동.
/// - [ghost]: 면 없는 글자. 취소·보조 행동.
/// - [danger]: 외곽선 + 빨간 글자. 되돌릴 수 없는 행동에만.
/// - [dangerText]: 테두리 없는 빨간 글자.
/// - [dark]: 검정 채움 + 흰 글자. 파괴적 확정 버튼, 기준 시안의 검정 버튼.
enum AppButtonVariant { primary, secondary, ghost, danger, dangerText, dark }

/// 크기. 시각 높이와 별개로 터치 영역은 44 이상.
/// sm 32(알약) · md 40(알약) · row 44(반경 14, 15 — 줄 안 2칸 버튼·다시 시도) ·
/// dialog 52(반경 14, 16 — 확인 창) · lg 56(반경 18, 17 — 화면 아래 주 버튼)
enum AppButtonSize { sm, md, row, lg, dialog }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final Widget? icon;

  /// 글자 700 (기준 시안 Main 계열 화면의 주 버튼)
  final bool bold;

  /// 글자 크기를 바꿀 때 (예: 2칸 버튼 16)
  final double? labelSize;

  /// 처리 중에 글자 없이 점 세 개만 보인다 (시안 Ad-Requests 승인 버튼)
  final bool loadingOnly;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.icon,
    this.bold = false,
    this.labelSize,
    this.loadingOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final height = switch (size) {
      AppButtonSize.sm => AppSize.buttonHeightSm,
      AppButtonSize.md => AppSize.buttonHeight,
      AppButtonSize.row => AppSize.touchMin,
      AppButtonSize.lg => AppSize.buttonHeightLg,
      AppButtonSize.dialog => 52.0,
    };
    final hPad = switch (size) {
      AppButtonSize.sm => AppSpacing.md,
      AppButtonSize.md => AppSpacing.base,
      AppButtonSize.row => 18.0,
      AppButtonSize.lg || AppButtonSize.dialog => AppSpacing.xl,
    };
    final fontSize = switch (size) {
      AppButtonSize.sm => 14.0,
      AppButtonSize.md => 15.0,
      AppButtonSize.row => 15.0,
      AppButtonSize.lg => 17.0,
      AppButtonSize.dialog => 16.0,
    };
    final isPrimary = variant == AppButtonVariant.primary;
    final isDark = variant == AppButtonVariant.dark;
    // 회색으로 채운 보조 버튼 (soft)
    final isSoft = variant == AppButtonVariant.secondary;
    // 큰 버튼은 모서리 18, 꽉 찬 중간 버튼·row 크기는 14, 그 외(작은·내용 폭)는 알약
    final OutlinedBorder shape = size == AppButtonSize.lg
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          )
        : fullWidth || size == AppButtonSize.row
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          )
        : const StadiumBorder();
    final fg = switch (variant) {
      AppButtonVariant.primary => AppColors.onPrimary,
      AppButtonVariant.dark => AppColors.canvas,
      AppButtonVariant.danger ||
      AppButtonVariant.dangerText => AppColors.danger,
      _ => AppColors.ink,
    };
    final borderColor = switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.danger => AppColors.outline,
      _ => Colors.transparent,
    };

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading && loadingOnly)
          AppLoader.inline(color: fg)
        else if (isLoading) ...[
          AppLoader.inline(color: fg),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          IconTheme(
            data: IconThemeData(
              color: fg,
              size: size == AppButtonSize.lg ? 20 : 18,
            ),
            child: icon!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (!(isLoading && loadingOnly))
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.buttonLabel.copyWith(
                color: fg,
                fontSize: labelSize ?? fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
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
          // 가로로는 내용 폭만 차지한다 (Align·Row 안에서 의도한 위치에 놓이도록).
          child: Center(
            heightFactor: 1,
            widthFactor: fullWidth ? null : 1,
            child: SizedBox(
              height: height,
              width: fullWidth ? double.infinity : null,
              child: Material(
                color: isPrimary
                    ? AppColors.primary
                    : isDark
                    ? AppColors.ink
                    : isSoft
                    ? AppColors.canvasSoft
                    : Colors.transparent,
                shape: shape.copyWith(side: BorderSide(color: borderColor)),
                child: InkWell(
                  customBorder: shape,
                  onTap: disabled ? null : onPressed,
                  // 눌림: 외곽선은 canvasSoft, primary는 반투명 검정, dark는 반투명 흰색
                  highlightColor: isPrimary
                      ? AppColors.ink.withValues(alpha: 0.12)
                      : isDark
                      ? AppColors.canvas.withValues(alpha: 0.16)
                      : AppColors.canvasMid,
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
