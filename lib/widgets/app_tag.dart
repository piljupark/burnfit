import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

final _hangul = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]');

/// 한글이 없으면 모노 대문자, 있으면 sans로 쓴다 (Galloway: 한글을 모노로 쓰지 않는다).
TextStyle monoOrSans(String text, {required TextStyle mono, required TextStyle sans}) =>
    _hangul.hasMatch(text) ? sans : mono;

String monoCase(String text) => _hangul.hasMatch(text) ? text : text.toUpperCase();

/// 상태·역할 태그. 외곽선 pill이 기본, [strong]은 흰 채움(완료·선택된 상태).
/// 색으로 상태를 나타내지 않는다 — 다른 상태는 strong/외곽선/[muted]로 구분.
class AppTag extends StatelessWidget {
  final String label;
  final bool strong;
  final bool muted;
  final bool danger;

  const AppTag(this.label, {super.key, this.strong = false, this.muted = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fg = strong
        ? AppColors.onPrimary
        : danger
            ? AppColors.danger
            : muted
                ? AppColors.mute
                : AppColors.body;
    final style = monoOrSans(
      label,
      mono: AppTextStyles.counter,
      sans: AppTextStyles.captionSmall,
    ).copyWith(color: fg);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: strong ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: strong ? AppColors.primary : AppColors.outline),
      ),
      // 글자 폭만큼만 차지한다 (부모가 넓어도 늘어나지 않게)
      child: Center(widthFactor: 1, child: Text(monoCase(label), style: style, maxLines: 1)),
    );
  }
}

/// 숫자 카운터 배지 (사진 위·목록 위): scrim 배경 pill, 모노.
class AppCountBadge extends StatelessWidget {
  final String label;

  const AppCountBadge(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.scrim,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Center(widthFactor: 1, child: Text(monoCase(label), style: AppTextStyles.counter.copyWith(color: AppColors.ink))),
    );
  }
}

/// 필터·선택 pill. 선택되면 흰 채움, 아니면 외곽선.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onPrimary : AppColors.ink;
    final style = monoOrSans(
      label,
      mono: AppTextStyles.counter.copyWith(fontSize: 12),
      sans: AppTextStyles.bodySm,
    ).copyWith(color: fg);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            // 시각 높이 32, 터치 영역은 세로 여백으로 확보
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              height: AppSize.buttonHeightSm,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(monoCase(label), style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
