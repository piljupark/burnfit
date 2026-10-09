import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';
import 'app_progress_bar.dart';

/// 강조 띠 (기준 시안 AdminHome '가입 요청 3건'): 주황 면 · 반경 18 · 높이 64 · 안쪽 0 16 0 18 · 칸 사이 12.
/// 아이콘 24 · 제목 17/500 · 오른쪽 행동 글자 15/500 · 18 Bold 화살표. 화면당 하나만 둔다.
/// - [subtitle]: 제목 아래 13 보조 줄 (높이 68)
/// - [muted]: 회색 면(canvasCard), 아이콘 mute, 화살표 chevron (시안 Ad-Home-NoPending — 할 일이 없을 때)
/// - [ring]: 아이콘이 종처럼 흔들린다 (시안 `ring`)
/// - [bold]: 글자 Bold — 기준 시안 계열(Admin*)
class AppAccentBar extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;
  final bool muted;
  final bool ring;
  final bool bold;

  const AppAccentBar({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onTap,
    this.muted = false,
    this.ring = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    // 주황 면은 두 테마 공통이라 글자는 늘 검정(onPrimary). 회색 면은 테마 색을 따른다.
    final fg = muted ? AppColors.ink : AppColors.onPrimary;
    TextStyle strong(TextStyle t) => bold ? t.bold : t.medium;
    Widget? iconWidget = icon == null
        ? null
        : Icon(
            AppIcons.bold(icon!),
            size: 24,
            color: muted ? AppColors.mute : fg,
          );
    if (iconWidget != null && ring) {
      iconWidget = AppRingShake(child: iconWidget);
    }
    return Semantics(
      button: onTap != null,
      child: Material(
        color: muted ? AppColors.canvasCard : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          highlightColor: muted
              ? AppColors.canvasMid
              : AppColors.onPrimary.withValues(alpha: 0.08),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 64 : 68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
              child: Row(
                children: [
                  if (iconWidget != null) ...[
                    ExcludeSemantics(child: iconWidget),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: strong(
                            AppTextStyles.bodyLg,
                          ).natural.copyWith(color: fg),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: muted
                                  ? AppColors.mute
                                  : fg.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      actionLabel!,
                      style: strong(AppTextStyles.bodyMd).copyWith(color: fg),
                    ),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      AppIcons.chevronRightBold,
                      size: 18,
                      color: muted ? AppColors.chevron : fg,
                    ),
                  ],
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
/// [bold]면 기준 시안 계열(Main·Trainer*)처럼 라벨·값을 Bold로 (회원 마이, 트레이너 홈 오늘 PT).
/// [compact]면 2칸 작은 카드(시안 TrainerMember): 안쪽 16, 반경 18, 라벨 13, 값 22, 막대 6.
class AppHighlightCard extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  final String value;
  final String? unit;

  /// 0~1. null이면 막대를 그리지 않는다.
  final double? progress;
  final String? footer;
  final bool muted;
  final bool bold;
  final bool compact;

  /// 화면 읽기 프로그램용 한 문장 (주면 안쪽 글자 대신 이것만 읽는다).
  final String? semanticLabel;

  const AppHighlightCard({
    super.key,
    required this.label,
    this.trailingLabel,
    required this.value,
    this.unit,
    this.progress,
    this.footer,
    this.muted = false,
    this.bold = false,
    this.compact = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // 주황 바탕은 두 테마 공통이라 글자는 늘 검정(onPrimary). 회색 카드는 테마 색을 따른다.
    final fg = muted ? AppColors.ink : AppColors.onPrimary;
    final soft = muted ? AppColors.mute : fg.withValues(alpha: 0.6);
    final valueSize = compact ? 22.0 : 30.0;
    final valueBase = AppTextStyles.displayMd.copyWith(
      fontSize: valueSize,
      height: compact ? 1.193 : 36 / 30,
      letterSpacing: valueSize * -0.019,
      color: fg,
    );
    final valueStyle = bold ? valueBase.bold : valueBase;
    final labelBase = compact ? AppTextStyles.bodySm : AppTextStyles.bodyMd;
    final labelStyle = (bold ? labelBase.bold.natural : labelBase).copyWith(
      color: muted ? AppColors.body : fg,
    );
    final trailingStyle =
        (bold ? AppTextStyles.bodyMd.bold.natural : AppTextStyles.bodyMd.medium)
            .copyWith(color: fg);
    final card = Container(
      padding: EdgeInsets.all(compact ? AppSpacing.base : AppSpacing.lg),
      decoration: BoxDecoration(
        color: muted ? AppColors.canvasCard : AppColors.primary,
        borderRadius: BorderRadius.circular(
          compact ? AppRadius.button : AppRadius.card,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              if (trailingLabel != null)
                Text(trailingLabel!, style: trailingStyle),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.xs : 6),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            SizedBox(height: compact ? 10 : 14),
            // 시안 `fill`: 1초, cubic-bezier(.2,.8,.2,1)
            AppProgressBar(
              value: progress!,
              height: compact ? 6 : 8,
              color: fg,
              trackColor: muted ? AppColors.track : fg.withValues(alpha: 0.15),
              duration: const Duration(milliseconds: 1000),
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
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, excludeSemantics: true, child: card);
  }
}

/// 안내·경고 줄: 연한 주황 바탕 + 진한 주황 글자 14/500. [warning]이면 경고 아이콘.
/// 회색 안내는 [neutral] (시안 Ad-Withdrawn `role=note`): canvasCard · 안쪽 14 · 정보 아이콘 18 mute(위 2) ·
/// 8 · 14 body 줄 높이 1.55.
class AppInlineNotice extends StatelessWidget {
  final String message;
  final bool warning;
  final bool neutral;

  const AppInlineNotice(
    this.message, {
    super.key,
    this.warning = true,
    this.neutral = false,
    this.bold = false,
  });

  /// 글자 Bold (기준 시안 TrainerReserve 겹침 안내)
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final fg = neutral ? AppColors.body : AppColors.noticeText;
    return Semantics(
      liveRegion: warning && !neutral,
      child: Container(
        padding: neutral
            ? const EdgeInsets.all(14)
            : const EdgeInsets.symmetric(
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
            Padding(
              padding: EdgeInsets.only(top: neutral ? 2 : 0),
              child: Icon(
                warning && !neutral ? AppIcons.warning : AppIcons.info,
                size: 18,
                color: neutral ? AppColors.mute : fg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: fg,
                  height: neutral ? 1.55 : null,
                  fontWeight: neutral
                      ? FontWeight.w400
                      : bold
                      ? FontWeight.w700
                      : FontWeight.w500,
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
/// 글자 16 — 기준 시안(TrainerSchedule)은 Bold, 상세 시안(Nt-Admin-List)은 [bold] false로 Medium.
class AppFloatingAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool extended;
  final bool bold;

  const AppFloatingAction({
    super.key,
    required this.label,
    this.icon = AppIcons.add,
    required this.onPressed,
    this.extended = true,
    this.bold = true,
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
                        style:
                            (bold
                                    ? AppTextStyles.listTitle.bold
                                    : AppTextStyles.listTitle)
                                .copyWith(color: fg),
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
