import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              // 아이콘
              Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.separator,
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.labelSecondary,
                      size: 28,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.85, 0.85)),
              const Gap(AppSpacing.xl),
              Text(
                '승인 대기 중',
                style: AppTextStyles.h2,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const Gap(AppSpacing.sm),
              Text(
                '관리자가 가입 신청을 검토하고 있습니다.\n승인이 완료되면 바로 서비스를 이용하실 수 있습니다.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.labelSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const Spacer(flex: 3),
              AppButton(
                label: '새로고침',
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                size: AppButtonSize.lg,
                onPressed: () {
                  context.read<UserProvider>().loadUser().then((_) {
                    if (!context.mounted) return;
                    final user = context.read<UserProvider>().user;
                    if (user == null) return;
                    if (user.status.name == 'approved') {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(_routeForRole(user.role.name));
                    }
                  });
                },
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const Gap(AppSpacing.sm),
              AppButton(
                label: '로그아웃',
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                onPressed: () async {
                  await context.read<UserProvider>().signOut();
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.memberLogin);
                },
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
              const Gap(AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'admin':
        return AppRoutes.adminHome;
      case 'trainer':
        return AppRoutes.trainerHome;
      default:
        return AppRoutes.memberHome;
    }
  }
}
