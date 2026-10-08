import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_action_row.dart';
import 'app_icon_button.dart';

/// 하위 화면 머리 모양.
enum AppHeaderStyle {
  /// 예전 모양: 뒤로 + 왼쪽 20 제목 (트레이너·관리자 화면)
  leading,

  /// 시안 MemB-*·MemA-* 하위 화면: 56 높이, 뒤로(24) · 가운데 17/500 제목 · 오른쪽 44.
  /// 보조 줄이 있으면 높이 64, 제목 아래 가운데 12 mute.
  centered,

  /// 시안 Com-Register·Com-Notifications·Nt-List: 위 뒤로 줄(56), 그 아래 28/500 큰 제목(좌우 20)
  /// + 보조 줄 14 mute(위 4).
  large,
}

/// 하위 화면 앱바. 화면 폭에 그대로 놓는다 (여백을 스스로 둔다).
/// - [subtitle]: 제목 아래 보조 줄. 날짜는 넣지 않는다.
/// - [divider]: 아래 hairline (기본 없음).
/// - [trailing]: 오른쪽 행동 (AppIconButton 또는 글자 버튼).
class AppScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool divider;
  final AppHeaderStyle style;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.divider = false,
    this.style = AppHeaderStyle.leading,
  });

  /// 가운데 17/500 제목 (시안 MemB-*·MemA-* 하위 화면).
  const AppScreenHeader.centered({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.divider = false,
  }) : style = AppHeaderStyle.centered;

  /// 뒤로 줄 아래 28/500 큰 제목 (시안 Com-Register·Com-Notifications·Nt-List).
  const AppScreenHeader.large({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.divider = false,
  }) : style = AppHeaderStyle.large;

  Widget _back() => onBack == null
      ? const SizedBox(width: AppSize.touchMin)
      : AppIconButton(
          icon: AppIcons.backBold,
          label: '뒤로',
          iconSize: 24,
          onPressed: onBack,
        );

  @override
  Widget build(BuildContext context) {
    final Widget bar = switch (style) {
      AppHeaderStyle.leading => _leadingBar(),
      AppHeaderStyle.centered => _centeredBar(),
      AppHeaderStyle.large => _largeBar(),
    };
    if (!divider) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, const AppRowDivider()],
    );
  }

  Widget _centeredBar() {
    return SizedBox(
      height: subtitle == null ? AppSize.appBar : 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            _back(),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.section,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppTextStyles.bodySm.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: AppSize.touchMin,
              child: trailing == null
                  ? null
                  : OverflowBox(maxWidth: 120, child: trailing),
            ),
          ],
        ),
      ),
    );
  }

  Widget _largeBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSize.appBar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                _back(),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.displayMd),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              0,
            ),
            child: Text(subtitle!, style: AppTextStyles.fieldLabel),
          ),
      ],
    );
  }

  Widget _leadingBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.appBar),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          if (onBack != null) ...[
            // 앱바 안에서는 아이콘을 시각적으로 화면 가장자리에 맞춘다
            Transform.translate(
              offset: const Offset(-12, 0),
              child: AppIconButton(
                icon: AppIcons.back,
                label: '뒤로',
                onPressed: onBack,
              ),
            ),
          ],
          Expanded(
            child: Transform.translate(
              offset: Offset(onBack != null ? -12 : 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // 오른쪽 아이콘 버튼도 시각적으로 화면 가장자리에 맞춘다
          if (trailing != null)
            Transform.translate(offset: const Offset(12, 0), child: trailing),
        ],
      ),
    );
  }
}
