import 'package:cupertino_liquid_glass/cupertino_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 디자인 시스템 바텀시트 래퍼
/// 모든 바텀시트는 이 함수를 통해 표시한다
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool memberStyle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _AppBottomSheetWrapper(memberStyle: memberStyle, child: child),
  );
}

class _AppBottomSheetWrapper extends StatelessWidget {
  final bool memberStyle;
  final Widget child;

  const _AppBottomSheetWrapper({
    required this.memberStyle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const topRadius = Radius.circular(AppRadius.xs);

    return CupertinoLiquidGlass(
      borderRadius: const BorderRadius.vertical(top: topRadius),
      theme: LiquidGlassThemeData(
        blurSigma: 60,
        tintColor: memberStyle ? AppColors.card : AppColors.surface1,
        tintOpacity: memberStyle ? 0.94 : 0.88,
        borderRadius: const BorderRadius.vertical(top: topRadius),
        edgeLightColor: memberStyle
            ? const Color(0xB3FFFFFF)
            : const Color(0x28FFFFFF),
        edgeShadowColor: const Color(0x00000000),
        borderWidth: 0.5,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xl + bottom,
      ),
      child: _AppBottomSheetStyle(
        memberStyle: memberStyle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: memberStyle
                    ? AppColors.border
                    : AppColors.separatorStrong,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const Gap(AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _AppBottomSheetStyle extends InheritedWidget {
  final bool memberStyle;

  const _AppBottomSheetStyle({required this.memberStyle, required super.child});

  static bool isMember(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppBottomSheetStyle>()
            ?.memberStyle ??
        false;
  }

  @override
  bool updateShouldNotify(_AppBottomSheetStyle oldWidget) {
    return memberStyle != oldWidget.memberStyle;
  }
}

/// 바텀시트 헤더
class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final memberStyle = _AppBottomSheetStyle.isMember(context);
    final closeBg = memberStyle
        ? AppColors.bg
        : AppColors.surfaceElevated;
    final closeFg = memberStyle
        ? AppColors.textSecondary
        : AppColors.labelSecondary;
    final titleColor = memberStyle
        ? AppColors.textPrimary
        : AppColors.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h3.copyWith(color: titleColor),
              ),
            ),
            GestureDetector(
              onTap: onClose ?? () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: closeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 16, color: closeFg),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const Gap(AppSpacing.xs),
          Text(subtitle!, style: AppTextStyles.bodySmall),
        ],
        const Gap(AppSpacing.lg),
      ],
    );
  }
}
