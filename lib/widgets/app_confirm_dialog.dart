import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_button.dart';

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

/// 주황 경고 콜아웃: 다이얼로그·시트에서 특히 눈에 띄어야 하는 한 줄 경고(부수 효과, 되돌릴 수 없음 등).
class AppWarningCallout extends StatelessWidget {
  final String message;

  const AppWarningCallout(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.noticeBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.warning, size: 18, color: AppColors.noticeText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.noticeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
