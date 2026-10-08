import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_button.dart';

/// 확인 다이얼로그 (앱 전체 공통): 제목 + 한 문단 설명 + 2열 전체폭 [취소 · 확정] 버튼.
/// 설명에는 무엇이 몇 개 사라지는지 적는다. [destructive]면 확정 버튼이 검정 채움+흰 글자.
/// 확정을 누르면 true, 그 밖(취소·바깥 탭·뒤로)은 false.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '취소',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.backdrop,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.canvasCard,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.lg,
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
                    size: AppButtonSize.lg,
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
  );
  return result ?? false;
}
