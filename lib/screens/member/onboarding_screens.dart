import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

// ── 온보딩 Step 1: 기본 정보 ──────────────────────────────────────────────
class OnboardingBasicScreen extends StatefulWidget {
  const OnboardingBasicScreen({super.key});

  @override
  State<OnboardingBasicScreen> createState() => _OnboardingBasicScreenState();
}

class _OnboardingBasicScreenState extends State<OnboardingBasicScreen> {
  final _birthController = TextEditingController();
  Gender? _gender;
  bool _isSaving = false;

  @override
  void dispose() {
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isSaving) return;
    final birth = _birthController.text.trim();
    if (birth.length != 8) {
      _showError('생년월일을 8자리로 입력해주세요. (예: 19900101)');
      return;
    }
    if (_gender == null) {
      _showError('성별을 선택해주세요.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;
      await FirestoreService.updateUser(user.uid, {
        'birthDate': birth,
        'gender': _gender!.name,
      });
      if (!mounted) return;
      context.read<UserProvider>().updateUserLocally(
        user.copyWith(birthDate: birth, gender: _gender),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingBody);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
        backgroundColor: AppColors.textNeutral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(AppSpacing.xl2),
              // 프로그레스
              _OnboardingProgress(
                step: 1,
                total: 2,
              ).animate().fadeIn(duration: 300.ms),
              const Gap(AppSpacing.xl),
              Text('기본 정보', style: AppTextStyles.h2)
                  .animate()
                  .fadeIn(delay: 50.ms, duration: 400.ms)
                  .slideY(begin: 0.08),
              const Gap(AppSpacing.xs),
              Text(
                '서비스 이용을 위해 기본 정보를 입력해주세요.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const Gap(AppSpacing.xl),
              AppTextField(
                label: '생년월일 (8자리)',
                hint: '19900101',
                controller: _birthController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const Gap(AppSpacing.xl),
              Text(
                '성별',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _GenderOption(
                      label: '남성',
                      icon: Icons.male_rounded,
                      selected: _gender == Gender.male,
                      onTap: () => setState(() => _gender = Gender.male),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: _GenderOption(
                      label: '여성',
                      icon: Icons.female_rounded,
                      selected: _gender == Gender.female,
                      onTap: () => setState(() => _gender = Gender.female),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
              const Spacer(),
              AppButton(
                label: '다음',
                onPressed: _next,
                isLoading: _isSaving,
                fullWidth: true,
                size: AppButtonSize.lg,
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Gap(AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 온보딩 Step 2: 신체 정보 ──────────────────────────────────────────────
class OnboardingBodyScreen extends StatefulWidget {
  const OnboardingBodyScreen({super.key});

  @override
  State<OnboardingBodyScreen> createState() => _OnboardingBodyScreenState();
}

class _OnboardingBodyScreenState extends State<OnboardingBodyScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _muscleController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _goalController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _muscleController.dispose();
    _bodyFatController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;
      final profile = UserProfile(
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        muscleMass: double.tryParse(_muscleController.text),
        bodyFat: double.tryParse(_bodyFatController.text),
        goal: _goalController.text.trim().isEmpty
            ? null
            : _goalController.text.trim(),
      );
      await FirestoreService.updateUser(user.uid, {'profile': profile.toMap()});
      if (!mounted) return;
      context.read<UserProvider>().updateUserLocally(
        user.copyWith(profile: profile),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.memberHome);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xl2,
                AppSpacing.screenH,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OnboardingProgress(
                    step: 2,
                    total: 2,
                  ).animate().fadeIn(duration: 300.ms),
                  const Gap(AppSpacing.xl),
                  Text('신체 정보', style: AppTextStyles.h2)
                      .animate()
                      .fadeIn(delay: 50.ms, duration: 400.ms)
                      .slideY(begin: 0.08),
                  const Gap(AppSpacing.xs),
                  Text(
                    '나중에 프로필에서 수정할 수 있습니다.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: '키 (cm)',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Expanded(
                          child: AppTextField(
                            label: '체중 (kg)',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    const Gap(AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: '골격근량 (kg)',
                            hint: '선택',
                            controller: _muscleController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Expanded(
                          child: AppTextField(
                            label: '체지방 (kg)',
                            hint: '선택',
                            controller: _bodyFatController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    const Gap(AppSpacing.sm),
                    AppTextField(
                      label: '목표',
                      hint: '예) 체중 감량 5kg',
                      controller: _goalController,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                    const Gap(AppSpacing.xl),
                    AppButton(
                      label: '시작하기',
                      onPressed: _done,
                      isLoading: _isSaving,
                      fullWidth: true,
                      size: AppButtonSize.lg,
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    const Gap(AppSpacing.sm),
                    AppButton(
                      label: '나중에 입력',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.memberHome),
                      fullWidth: true,
                    ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공유 위젯 ─────────────────────────────────────────────────────────────
class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;

  const _OnboardingProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brand
                  : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        );
      }),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 72,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: selected
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 6),
              )
            else
              const BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const Gap(AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
