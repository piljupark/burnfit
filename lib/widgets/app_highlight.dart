import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 강조 띠: 강조색 바탕 한 줄. 왼쪽 내용, 오른쪽 행동 글자 + 화살표.
/// 화면당 하나만 둔다 (예: 관리자 홈 '가입 신청 n건').
class AppAccentBar extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  const AppAccentBar({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onPrimary;
    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          highlightColor: AppColors.ink.withValues(alpha: 0.08),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.base,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: fg),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyLg.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: fg.withValues(alpha: 0.72),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (actionLabel != null)
                    Text(
                      actionLabel!,
                      style: AppTextStyles.bodyMd.copyWith(color: fg),
                    ),
                  if (onTap != null)
                    Icon(AppIcons.forward, size: 18, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 강조 요약 카드 (시안 MemA-PtSchedule): 강조색 바탕, 안쪽 20, 반경 20.
/// 라벨 15 + 오른쪽 15/500 / (위 6) 값 30/500 + 단위 400 반투명 / (위 14) 8 높이 막대(1초 차오름) /
/// (위 12) 보조 줄 14. 화면당 하나만 둔다.
/// [muted]면 회색 카드(시안 MemA-PtSchedule-Empty): 라벨 body, 단위·보조 줄 mute, 막대 바탕 track.
class AppHighlightCard extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  final String value;
  final String? unit;

  /// 0~1. null이면 막대를 그리지 않는다.
  final double? progress;
  final String? footer;
  final bool muted;

  const AppHighlightCard({
    super.key,
    required this.label,
    this.trailingLabel,
    required this.value,
    this.unit,
    this.progress,
    this.footer,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    // 주황 바탕은 두 테마 공통이라 글자는 늘 검정(onPrimary). 회색 카드는 테마 색을 따른다.
    final fg = muted ? AppColors.ink : AppColors.onPrimary;
    final soft = muted ? AppColors.mute : fg.withValues(alpha: 0.6);
    final valueStyle = AppTextStyles.displayMd.copyWith(
      fontSize: 30,
      height: 36 / 30,
      letterSpacing: 30 * -0.019,
      color: fg,
    );
    final clamped = (progress ?? 0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: muted ? AppColors.canvasCard : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: muted ? AppColors.body : fg,
                  ),
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: AppTextStyles.bodyMd.medium.copyWith(color: fg),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: TextStyle(fontWeight: FontWeight.w400, color: soft),
                  ),
              ],
            ),
            style: valueStyle,
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: muted
                          ? AppColors.track
                          : fg.withValues(alpha: 0.15),
                    ),
                    if (clamped > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: clamped,
                          heightFactor: 1,
                          // 시안 `fill`: 1초, cubic-bezier(.2,.8,.2,1)
                          child: AppGrow(
                            duration: const Duration(milliseconds: 1000),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: fg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              footer!,
              style: AppTextStyles.bodySmall.copyWith(
                color: muted ? AppColors.mute : fg.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 안내·경고 줄: 연한 주황 바탕 + 진한 주황 글자. [warning]이면 경고 아이콘.
/// 회색 안내는 [neutral].
class AppInlineNotice extends StatelessWidget {
  final String message;
  final bool warning;
  final bool neutral;

  const AppInlineNotice(
    this.message, {
    super.key,
    this.warning = true,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = neutral ? AppColors.body : AppColors.noticeText;
    return Semantics(
      liveRegion: warning,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base - 2,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: neutral ? AppColors.canvasCard : AppColors.noticeBg,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warning && !neutral ? AppIcons.warning : AppIcons.info,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: fg,
                  fontWeight: neutral ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 떠 있는 행동 버튼: 검정 알약 + 아이콘 + 글자. 화면 오른쪽 아래에 둔다.
/// [extended]가 false면 글자를 접고 아이콘만 있는 원(56)이 된다 (아래로 스크롤할 때 내용을 덜 가리게).
class AppFloatingAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool extended;

  const AppFloatingAction({
    super.key,
    required this.label,
    this.icon = AppIcons.add,
    required this.onPressed,
    this.extended = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.canvas;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: extended
                    ? const EdgeInsets.fromLTRB(18, 0, 22, 0)
                    : const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: fg),
                    if (extended) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        // 시안 TrainerSchedule 'PT 예약': 16, 기준 시안이라 Bold
                        style: AppTextStyles.listTitle.bold.copyWith(color: fg),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
