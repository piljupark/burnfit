import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 예전에는 영문을 모노 대문자로 썼다. 지금은 글꼴을 하나(sans)로 통일해 항상 [sans]를 돌려준다.
/// 호출부를 바꾸지 않으려고 이름은 남겨 둔다.
TextStyle monoOrSans(
  String text, {
  required TextStyle mono,
  required TextStyle sans,
}) => sans;

/// 글자를 그대로 돌려준다 (예전 모노 대문자 변환 자리).
String monoCase(String text) => text;

/// 상태 글자. 배지(테두리·채움) 없이 글자만 쓴다 — 글자 배지는 쓰지 않는다.
/// - [strong]: 500 진한 글자 (완료·새 글처럼 눈에 띄어야 할 상태)
/// - 기본: 회색 글자 / [muted]: 흐린 글자 / [danger]: 위험 글자
class AppTag extends StatelessWidget {
  final String label;
  final bool strong;
  final bool muted;
  final bool danger;

  const AppTag(
    this.label, {
    super.key,
    this.strong = false,
    this.muted = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? AppColors.danger
        : strong
        ? AppColors.noticeText
        : muted
        ? AppColors.mute.withValues(alpha: 0.7)
        : AppColors.mute;
    final style = AppTextStyles.bodySm.copyWith(
      color: fg,
      fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
    );
    return SizedBox(
      height: 22,
      // 글자 폭만큼만 차지한다 (부모가 넓어도 늘어나지 않게)
      child: Center(
        widthFactor: 1,
        child: Text(label, style: style, maxLines: 1),
      ),
    );
  }
}

/// 사진 위 숫자 (예: +2): 어두운 덮개 알약.
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
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          // 사진 위 어두운 덮개 위라 테마와 관계없이 흰 글자
          style: AppTextStyles.counter.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// 필터·선택 알약. 선택되면 검정 채움 + 흰 글자, 아니면 회색 채움.
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
    final fg = selected ? AppColors.canvas : AppColors.body;
    final style = AppTextStyles.bodySmall.copyWith(
      color: fg,
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
    );
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
                color: selected ? AppColors.ink : AppColors.canvasSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(label, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
