import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/notice_widgets.dart';

/// 공지 상세 (회원·트레이너 공용, 읽기 전용, 시안 Nt-Detail):
/// 뒤로 줄만 있는 머리 → 본문(위 4) → 아래 고정 '목록으로'(56, 반경 18, 회색, 16/500).
class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;
  final String centerName;
  const NoticeDetailScreen({
    super.key,
    required this.notice,
    this.centerName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: '',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: NoticeArticle(notice: notice, centerName: centerName),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: AppButton(
                label: '목록으로',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.lg,
                labelSize: 16,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
