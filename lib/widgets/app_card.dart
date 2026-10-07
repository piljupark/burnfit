import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';

enum AppCardVariant { standard, tinted, outlined }

/// 카드: canvasCard 면 + 1px hairline, 반경 8. 그림자는 쓰지 않는다.
/// - [AppCardVariant.outlined]: 캔버스 위 외곽선만 (면 없음)
/// - [AppCardVariant.tinted]: canvasSoft 면 (중첩·강조)
///
/// [hasShadow]는 기존 호출부 호환용이며 무시된다.
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
    this.hasBorder = true,
    this.hasShadow = false,
    this.variant = AppCardVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        color ??
        switch (variant) {
          AppCardVariant.standard => AppColors.canvasCard,
          AppCardVariant.tinted => AppColors.canvasSoft,
          AppCardVariant.outlined => Colors.transparent,
        };
    final radius = BorderRadius.circular(AppRadius.card);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: hasBorder || variant == AppCardVariant.outlined
            ? BorderSide(color: AppColors.hairline)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.base),
          child: child,
        ),
      ),
    );
  }
}
