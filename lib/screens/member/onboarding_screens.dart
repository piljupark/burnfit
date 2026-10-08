import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/gender_selector.dart';

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
    final birthError = Validators.birthDate(birth);
    if (birthError != null) {
      _showError(birthError);
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
          showCounter: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(AppSpacing.base),
            Text('성별', style: AppTextStyles.fieldLabel),
            const Gap(6),
            GenderSelector(
              value: _gender,
              onChanged: (g) => setState(() => _gender = g),
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
      final m = Validators.bodyMetrics(
        height: _heightController.text,
        weight: _weightController.text,
        muscleMass: _muscleController.text,
        bodyFat: _bodyFatController.text,
      );
      final profile = UserProfile(
        height: m.height,
        weight: m.weight,
        muscleMass: m.muscleMass,
        bodyFat: m.bodyFat,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: '키',
                    unit: 'cm',
                    strongValue: true,
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: '체중',
                    unit: 'kg',
                    strongValue: true,
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const Gap(14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: '골격근량',
                    hint: '선택',
                    unit: 'kg',
                    strongValue: true,
                    controller: _muscleController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: '체지방',
                    hint: '선택',
                    unit: 'kg',
                    strongValue: true,
                    controller: _bodyFatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(14),
            AppTextField(
              label: '목표',
              hint: '예) 체중 감량 5kg',
              controller: _goalController,
              maxLines: 3,
              minLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
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
        _LaterLink(
          onTap: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.memberHome),
        ),
      ],
    );
  }
}

// ── 공유 위젯 ─────────────────────────────────────────────────────────────

/// 온보딩 화면 틀 (시안 Com-Onboarding-*): 단계 막대(지금 칸 차오름) + 단계 글자 + 28 제목 + 16 설명
/// → 입력 묶음들 → 아래 고정 행동(위 hairline). 글자·입력 묶음은 차례로 아래 10에서 올라온다 (`up`).
class _OnboardingScaffold extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String description;

  /// 입력 묶음들. 묶음마다 하나씩 늦게 나타난다 (0.15초부터 0.05초 간격).
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

  static Widget _up(int index, Widget child) => AppEntrance(
    delay: Duration(milliseconds: 50 * index),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.sm,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OnboardingProgress(step: step, total: total),
                    const Gap(AppSpacing.xl2),
                    _up(
                      0,
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$step',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(text: ' / $total단계'),
                          ],
                        ),
                        style: AppTextStyles.eyebrow,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    _up(
                      1,
                      Semantics(
                        header: true,
                        child: Text(title, style: AppTextStyles.displayMd),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    _up(
                      2,
                      Text(
                        description,
                        style: AppTextStyles.input.copyWith(
                          color: AppColors.body,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.xl2),
                    for (var i = 0; i < fields.length; i++)
                      _up(3 + i, fields[i]),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                math.max(bottomInset, AppSpacing.lg),
              ),
              decoration: BoxDecoration(
                color: AppColors.canvas,
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

/// 단계 막대: 4 높이 알약 칸(바탕 track #E6E6EA). 지난 칸은 ink로 꽉 차 있고,
/// 지금 칸은 왼쪽부터 차오른다 (시안 `fill`: .8s, cubic-bezier(.2,.8,.2,1)).
class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;

  const _OnboardingProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    Widget fill() => Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
    return Semantics(
      label: '$total단계 중 $step단계',
      excludeSemantics: true,
      child: Row(
        children: List.generate(total, (i) {
          final done = i < step - 1;
          final current = i == step - 1;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < total - 1 ? AppSpacing.xs : 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.track,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: done
                  ? fill()
                  : current
                  ? AppGrow(
                      duration: const Duration(milliseconds: 800),
                      child: fill(),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// '나중에 입력' 글자 버튼: 44 높이, 15/400 mute (시안 Com-Onboarding-Body).
class _LaterLink extends StatelessWidget {
  final VoidCallback onTap;

  const _LaterLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: AppSize.touchMin,
          child: Center(
            child: Text(
              '나중에 입력',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
            ),
          ),
        ),
      ),
    );
  }
}
