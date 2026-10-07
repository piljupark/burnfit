import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _showError(String msg) => AppFeedback.showWarning(context, msg);

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 1,
      total: 2,
      title: '기본 정보',
      description: '서비스 이용을 위해 기본 정보를 입력해주세요.',
      fields: [
        AppTextField(
          label: '생년월일 (8자리)',
          hint: '19900101',
          controller: _birthController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
        ),
        const Gap(AppSpacing.xl),
        Text('성별', style: AppTextStyles.bodySm.copyWith(color: AppColors.body)),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                label: '남성',
                selected: _gender == Gender.male,
                onTap: () => setState(() => _gender = Gender.male),
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: _GenderOption(
                label: '여성',
                selected: _gender == Gender.female,
                onTap: () => setState(() => _gender = Gender.female),
              ),
            ),
          ],
        ),
      ],
      actions: [
        AppButton(
          label: '다음',
          onPressed: _next,
          isLoading: _isSaving,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
      ],
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
    return _OnboardingScaffold(
      step: 2,
      total: 2,
      title: '신체 정보',
      description: '나중에 프로필에서 수정할 수 있습니다.',
      fields: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: '키 (cm)',
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체중 (kg)',
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: '골격근량 (kg)',
                hint: '선택',
                controller: _muscleController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체지방 (kg)',
                hint: '선택',
                controller: _bodyFatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.base),
        AppTextField(
          label: '목표',
          hint: '예) 체중 감량 5kg',
          controller: _goalController,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
      actions: [
        AppButton(
          label: '시작하기',
          onPressed: _done,
          isLoading: _isSaving,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
        const Gap(AppSpacing.xs),
        AppButton(
          label: '나중에 입력',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutes.memberHome),
          fullWidth: true,
        ),
      ],
    );
  }
}

// ── 공유 위젯 ─────────────────────────────────────────────────────────────

/// 온보딩 화면 틀: 단계 막대 + 모노 단계 표시 + 28 제목 + 설명 → 스크롤 입력 → 아래 고정 행동.
class _OnboardingScaffold extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String description;
  final List<Widget> fields;
  final List<Widget> actions;

  const _OnboardingScaffold({
    required this.step,
    required this.total,
    required this.title,
    required this.description,
    required this.fields,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OnboardingProgress(step: step, total: total),
                    const Gap(AppSpacing.xl2),
                    Text('STEP $step / $total', style: AppTextStyles.eyebrow),
                    const Gap(AppSpacing.sm),
                    Semantics(
                      header: true,
                      child: Text(title, style: AppTextStyles.displayMd),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.body)),
                    const Gap(AppSpacing.xl2),
                    ...fields,
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.base,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 단계 막대: 4px pill 트랙(canvasMid) + ink 채움.
class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;

  const _OnboardingProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 $step단계',
      excludeSemantics: true,
      child: Row(
        children: List.generate(total, (i) {
          final active = i < step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < total - 1 ? AppSpacing.xs : 0),
              decoration: BoxDecoration(
                color: active ? AppColors.ink : AppColors.canvasMid,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 성별 선택 pill (선택 = 흰 채움, 아니면 외곽선). 높이 48.
class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMd.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
