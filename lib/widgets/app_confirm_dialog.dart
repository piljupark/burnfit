import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_button.dart';
import 'app_motion.dart';

/// 확인 다이얼로그 (앱 전체 공통): 제목 + 한 문단 설명 + (선택) 경고 콜아웃 + 2열 전체폭 [취소 · 확정] 버튼.
/// 설명에는 무엇이 몇 개 사라지는지 적는다. [warning]은 부수 효과(예: 잔여 횟수 복구)처럼
/// 특히 눈에 띄어야 하는 한 줄에만 쓴다 — 주황 콜아웃 박스로 그려진다.
/// [destructive]면 확정 버튼이 검정 채움+흰 글자.
/// 확정을 누르면 true, 그 밖(취소·바깥 탭·뒤로)은 false.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '취소',
  bool destructive = true,
  String? warning,
}) async {
  // 시안 Com-ConfirmDialog: 흰 면 · 반경 20 · 좌우 20 · 안쪽 24 20 20,
  // 제목 20/500, 설명 15 body 줄 높이 1.55, 2칸 버튼(52 · 반경 14 · 16/500).
  // 나타날 때 .92 → 1 커지며 나타남(300ms), 뒤 덮개 40%.
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: AppColors.backdrop,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Material(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: AppTextStyles.title.medium),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.body,
                      height: 1.55,
                    ),
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppWarningCallout(warning),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: cancelLabel,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.dialog,
                          fullWidth: true,
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: confirmLabel,
                          variant: destructive
                              ? AppButtonVariant.dark
                              : AppButtonVariant.primary,
                          size: AppButtonSize.dialog,
                          fullWidth: true,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, animation, _, child) {
      if (AppMotion.reduced(ctx)) return child;
      final pop = CurvedAnimation(parent: animation, curve: AppMotion.dialog);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(pop),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

/// 주황 경고 콜아웃 (시안 Com-DeleteAccount): 연한 주황 면 · 반경 14 · 안쪽 12 14,
/// 경고 원 18 + 14/500 noticeText, 세로 가운데 정렬.
class AppWarningCallout extends StatelessWidget {
  final String message;

  const AppWarningCallout(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.noticeBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: 18, color: AppColors.noticeText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.buttonLabel.medium.copyWith(
                color: AppColors.noticeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
