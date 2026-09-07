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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // 아이콘
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.textPrimary,
                  size: 32,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.85, 0.85)),

              const Gap(AppSpacing.xl),

              Text(
                '가입 승인 대기 중',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const Gap(AppSpacing.sm),

              Text(
                '관리자가 가입 신청을 검토하고 있습니다.\n승인이 완료되면 바로 서비스를 이용하실 수 있습니다.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 160.ms, duration: 400.ms),

              const Spacer(flex: 3),

              // 새로고침 버튼
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
              ).animate().fadeIn(delay: 220.ms, duration: 400.ms),

              const Gap(AppSpacing.sm),

              // 로그아웃 버튼
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
              ).animate().fadeIn(delay: 270.ms, duration: 400.ms),

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
