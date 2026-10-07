import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/orb_loader.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(AppSpacing.xl3),
              const Align(
                alignment: Alignment.centerLeft,
                child: ExcludeSemantics(child: OrbLoader(size: 96)),
              ),
              const Gap(AppSpacing.xl2),
              Text('승인 대기', style: AppTextStyles.bodySm),
              const Gap(AppSpacing.sm),
              Semantics(
                header: true,
                child: Text('가입 승인 대기 중', style: AppTextStyles.displayMd),
              ),
              const Gap(AppSpacing.md),
              Text(
                '관리자가 가입 신청을 검토하고 있습니다.\n승인이 완료되면 바로 서비스를 이용하실 수 있습니다.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
              const Spacer(),

              // 새로고침 (화면의 주 행동)
              AppButton(
                label: '새로고침',
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
