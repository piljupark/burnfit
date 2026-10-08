import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_button.dart';
import 'app_tag.dart';

/// 섹션 머리말 (패딩 없는 버전 — 이미 여백이 있는 열 안에서 쓴다).
/// 라벨 + hairline + (선택) 오른쪽 글자 행동. 화면 폭 머리말은 AppMonthHeader.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final String? count;

  /// 기존 호출부 호환용 — 색으로 구분하지 않으므로 무시된다.
  final Color? accentColor;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.accentColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          monoCase(title),
          style: monoOrSans(
            title,
            mono: AppTextStyles.eyebrow.copyWith(color: AppColors.ink),
            sans: AppTextStyles.bodySm.copyWith(color: AppColors.ink),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(monoCase(count!), style: AppTextStyles.eyebrow),
        ],
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(height: 1, color: AppColors.hairline)),
        if (trailing != null)
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                ),
                child: Text(
                  trailing!,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 빈 상태: 사진 타일과 pill을 본뜬 단색 도형 + 한 줄 제목 + (선택) 주 행동 하나.
/// 아이콘·캐릭터 그림은 쓰지 않는다. [icon]은 기존 호출부 호환용이며 그리지 않는다.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _EmptyArt(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message,
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                description!,
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// 빈 상태 그림: 회색 원 안에 흐린 상자 아이콘. 색은 무채색만 쓴다.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.archive, size: 32, color: AppColors.mute),
      ),
    );
  }
}

/// 목록 자리의 짧은 빈 상태 한 줄 ("이 날의 기록이 없습니다"). 그림이 필요한 큰 빈 화면은 [AppEmptyState].
/// [inset]이 true면 화면 좌우 여백(16)을 스스로 둔다 (시트 안처럼 이미 여백이 있으면 false).
class AppEmptyLine extends StatelessWidget {
  final String message;
  final bool inset;

  const AppEmptyLine(this.message, {super.key, this.inset = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: inset ? AppSpacing.screenH : 0,
        vertical: AppSpacing.xl,
      ),
      child: Text(message, style: AppTextStyles.bodySm),
    );
  }
}
