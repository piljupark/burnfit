import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_button.dart';

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
          title,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.ink),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(count!, style: AppTextStyles.eyebrow),
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

  /// 행동 버튼 종류·크기 (기본 주황 md, 시안 Tr-Member-Profile-Empty '첫 기록 입력'은 검정)
  final AppButtonVariant actionVariant;
  final AppButtonSize actionSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionVariant = AppButtonVariant.primary,
    this.actionSize = AppButtonSize.md,
    this.card = false,
    this.illustration,
    this.margin,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    this.artGap = 18,
  });

  /// 카드 안쪽 여백 (기본 40 28, 시안 MemB-FeedbackEmpty는 36 24)
  final EdgeInsetsGeometry cardPadding;

  /// 그림과 제목 사이 (카드형 기본 18)
  final double artGap;

  /// 회색 카드 안에 그린다 (시안 MemB-FeedbackEmpty·MemA-*-Empty·Com-Notifications-Empty):
  /// 반경 20, 안쪽 40 28, 제목 16~17/500, 설명 14 mute 줄 높이 1.5.
  final bool card;

  /// 기본 원·상자 그림 대신 쓸 그림 (화면마다 다름)
  final Widget? illustration;

  /// 카드 바깥 여백 (기본 좌우 20, 위 24)
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: illustration ?? const _EmptyArt()),
        SizedBox(height: card ? artGap : AppSpacing.xl),
        Text(
          message,
          style: card ? AppTextStyles.section : AppTextStyles.title,
          textAlign: TextAlign.center,
        ),
        if (description != null) ...[
          SizedBox(height: card ? 6 : AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              description!,
              style: card
                  ? AppTextStyles.note.copyWith(
                      color: AppColors.mute,
                      height: 1.5,
                    )
                  : AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: card ? AppSpacing.base : AppSpacing.xl),
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: actionVariant,
            size: actionSize,
          ),
        ],
      ],
    );
    if (card) {
      return Container(
        width: double.infinity,
        margin:
            margin ??
            const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              0,
            ),
        padding: cardPadding,
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: column,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl3,
      ),
      child: column,
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

/// 목록 자리의 짧은 빈 상태 한 줄 ("이 날의 기록이 없습니다"): 52 높이, 14 mute.
/// 그림이 필요한 큰 빈 화면은 [AppEmptyState].
/// [inset]이 true면 화면 좌우 여백(20)을 스스로 둔다 (시트 안처럼 이미 여백이 있으면 false).
class AppEmptyLine extends StatelessWidget {
  final String message;
  final bool inset;

  const AppEmptyLine(this.message, {super.key, this.inset = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(
        horizontal: inset ? AppSpacing.screenH : 0,
      ),
      child: Text(
        message,
        style: AppTextStyles.note.copyWith(color: AppColors.mute),
      ),
    );
  }
}
