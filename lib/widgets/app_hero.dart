import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 탭 화면 맨 위 제목 (회원·트레이너·관리자 모든 탭 공통, 시안 Main·My·TrainerHome·AdminHome).
/// 위 20 · 좌우 20, 44 높이 한 줄에 28/700 제목(한 줄) + 오른쪽 아이콘 버튼.
/// 아래 [bottomGap](기본 16) 뒤에 본문이 온다 — 탭마다 제목 모양과 위치가 같게, 탭 화면은 모두 이것만 쓴다.
/// 하위 화면은 AppScreenHeader(뒤로 버튼)를 쓴다.
class AppHero extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool divider;
  final double bottomGap;

  /// 제목 바로 뒤 개수 28/400 mute, 8 띄움 (기준 시안 AdminMembers '회원 128')
  final String? count;

  const AppHero({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.divider = false,
    this.bottomGap = AppSpacing.base,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            )
          : null,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        bottomGap,
      ),
      child: SizedBox(
        height: AppSize.touchMin,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.base),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: title),
                      if (count != null) ...[
                        const WidgetSpan(child: SizedBox(width: AppSpacing.sm)),
                        TextSpan(
                          text: count,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ],
                  ),
                  style: AppTextStyles.displayMd.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 묶음 머리말 (시안 공통): 왼쪽 라벨, 오른쪽 끝 개수(15 mute, 글자 바닥선 맞춤).
/// - 기본: 15 mute 라벨 (시안 MemB-Feedback·Share 등)
/// - [strong]: 17/500 ink 라벨, 여백 20 20 4 (시안 MemA-PtSchedule·Stats·Workout '저장된 기록',
///   회원·트레이너 캘린더의 고른 날 머리말 등)
/// - [bold]: [strong]을 Bold로, 오른쪽 개수도 15 ink Bold (기준 시안 TrainerHome '혼자 운동한 회원 3명')
/// - [strongCount]: 개수를 15/500 ink로, [unit]은 그 뒤 400 mute (시안 Ad-* '8명'·'12건')
/// - [actionLabel]: 오른쪽 끝 글자 링크 15 body + 16 Bold 화살표(chevron), 터치 44 (시안 'PT 정보 수정 ›')
class AppMonthHeader extends StatelessWidget {
  final String label;
  final String? count;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;
  final bool strong;
  final bool bold;
  final bool strongCount;
  final String? unit;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppMonthHeader({
    super.key,
    required this.label,
    this.count,
    this.padding,
    this.trailing,
    this.strong = false,
    this.bold = false,
    this.strongCount = false,
    this.unit,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = bold
        ? AppTextStyles.section.bold.natural
        : strong
        ? AppTextStyles.section
        : AppTextStyles.eyebrow;
    final countStyle = bold
        ? AppTextStyles.bodyMd.bold.natural
        : strongCount
        ? AppTextStyles.bodyMd.medium
        : AppTextStyles.eyebrow;
    return Padding(
      padding:
          padding ??
          (strong || bold
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                )
              : const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                )),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label, style: labelStyle),
            ),
          ),
          if (count != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: count),
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                ],
              ),
              style: countStyle,
            ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          if (actionLabel != null && onAction != null)
            _HeaderLink(label: actionLabel!, onTap: onAction!),
        ],
      ),
    );
  }
}

/// 머리말 오른쪽 글자 링크: 15 body + 4 + 16 Bold 화살표(chevron). 터치 높이 44.
class _HeaderLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HeaderLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSize.touchMin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                AppIcons.chevronRightBold,
                size: 16,
                color: AppColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
