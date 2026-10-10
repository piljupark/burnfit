import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/app_feedback.dart';
import '../models/user.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_marks.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 어느 센터가 승인하는지 알려 준다 (센터 이름이 없으면 예전 문구).
    final centerName = context.select<UserProvider, String?>(
      (p) => p.user?.centerName,
    );
    final message = centerName == null || centerName.isEmpty
        ? '관리자가 가입 신청을 검토하고 있습니다.\n승인이 완료되면 바로 서비스를 이용하실 수 있습니다.'
        : '$centerName 관리자가 가입 신청을 확인하고 있어요.\n승인되면 바로 이용할 수 있어요.';
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 시안: 위에서 96 (상태 표시줄 포함)
              Gap(
                math.max(
                  AppSpacing.xl3,
                  96 - MediaQuery.paddingOf(context).top,
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: ExcludeSemantics(child: PendingClockMark()),
              ),
              const Gap(40),
              Text('승인 대기', style: AppTextStyles.eyebrow),
              const Gap(AppSpacing.sm),
              Semantics(
                header: true,
                child: Text('가입 승인 대기 중', style: AppTextStyles.displayMd),
              ),
              const Gap(AppSpacing.md),
              Text(
                message,
                style: AppTextStyles.input.copyWith(
                  color: AppColors.body,
                  height: 1.6,
                ),
              ),
              const Spacer(),

              // 새로고침 (화면의 주 행동)
              AppButton(
                label: '새로고침',
                icon: const Icon(AppIcons.refresh),
                fullWidth: true,
                size: AppButtonSize.lg,
                // 승인·거절은 실시간으로 반영되고 화면 이동은 AccountStatusListener가 한다.
                // 여기서는 다시 읽기만 하고, 그대로 대기 중이면 안내만 띄운다.
                onPressed: () async {
                  final provider = context.read<UserProvider>();
                  final ok = await provider.refreshQuietly();
                  if (!context.mounted) return;
                  final user = provider.user;
                  if (!ok || user == null) {
                    AppFeedback.showWarning(
                      context,
                      '계정 정보를 불러오지 못했어요. 네트워크를 확인해주세요.',
                    );
                    return;
                  }
                  if (user.status == UserStatus.pending) {
                    AppFeedback.showWaiting(context, '아직 승인 대기 중이에요.');
                  }
                },
              ),

              const Gap(AppSpacing.sm),

              // 로그아웃
              AppButton(
                label: '로그아웃',
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                size: AppButtonSize.lg,
                onPressed: () async {
                  await context.read<UserProvider>().signOut();
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.memberLogin);
                },
              ),

              // 시안: 버튼 묶음 아래 34 = 안전 영역 (없는 기기는 20)
              Gap(
                math.max(MediaQuery.paddingOf(context).bottom, AppSpacing.lg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
