import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/meal.dart';
import '../../models/nutrition_plan.dart';
import '../../models/user.dart';
import '../../services/nutrition_plan_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';

/// 트레이너: 회원 식단 목표 정하기 (회원 상세 → 식단 탭 카드 · 더보기에서 연다).
///
/// 가운데 '식단 목표' → 회원 이름 → 추천(감량 · 유지 · 증량 + 근거 한 줄 + '추천값 채우기') →
/// 하루 권장(칼로리 · 탄수 · 단백질 · 지방, 2×2) → 끼니별 가이드 4칸 → 한마디 →
/// 아래 고정 '저장' (있던 목표면 '지우기'도). 저장하면 true로 닫힌다 (회원에게 알림은 서버가 보낸다).
class NutritionPlanScreen extends StatefulWidget {
  final AppUser member;
  final AppUser trainer;
  final NutritionPlan? existing;

  /// 추천 계산 재료: 최근 인바디 기초대사량 · 최근 체중 (없으면 null)
  final double? bmr;
  final double? weight;

  const NutritionPlanScreen({
    super.key,
    required this.member,
    required this.trainer,
    required this.existing,
    this.bmr,
    this.weight,
  });

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  static const _mealOrder = [
    MealType.breakfast,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];

  static const _guideHints = {
    MealType.breakfast: '예: 달걀 2개 + 바나나 1개',
    MealType.lunch: '예: 단백질 손바닥 1개 + 밥 2/3 공기',
    MealType.snack: '예: 그릭요거트 또는 단백질 음료',
    MealType.dinner: '예: 밥 반 공기, 채소 두 주먹',
  };

  late final _calories = _numberController(widget.existing?.calories);
  late final _carbs = _numberController(widget.existing?.carbs);
  late final _protein = _numberController(widget.existing?.protein);
  late final _fat = _numberController(widget.existing?.fat);
  late final Map<MealType, TextEditingController> _guides = {
    for (final type in _mealOrder)
      type: TextEditingController(text: widget.existing?.mealGuides[type]),
  };
  late final _note = TextEditingController(text: widget.existing?.note);

  NutritionGoal _goal = NutritionGoal.maintain;
  bool _saving = false;

  static TextEditingController _numberController(int? value) =>
      TextEditingController(text: value?.toString());

  NutritionRecommendation? get _recommendation => NutritionRecommendation.from(
    bmr: widget.bmr,
    weight: widget.weight,
    goal: _goal,
  );

  @override
  void dispose() {
    for (final c in [_calories, _carbs, _protein, _fat, _note]) {
      c.dispose();
    }
    for (final c in _guides.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillRecommendation() {
    final r = _recommendation;
    if (r == null) return;
    setState(() {
      _calories.text = '${r.calories}';
      _carbs.text = '${r.carbs}';
      _protein.text = '${r.protein}';
      _fat.text = '${r.fat}';
    });
  }

  NutritionPlan _plan() {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    return NutritionPlan(
      memberId: widget.member.uid,
      centerId: widget.member.centerId,
      trainerId: widget.trainer.uid,
      trainerName: widget.trainer.name,
      calories: n(_calories),
      carbs: n(_carbs),
      protein: n(_protein),
      fat: n(_fat),
      mealGuides: {
        for (final e in _guides.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      },
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final plan = _plan();
    final problem = plan.validate();
    if (problem != null) {
      AppFeedback.showWarning(context, problem);
      return;
    }
    setState(() => _saving = true);
    try {
      await NutritionPlanService.save(plan);
      if (!mounted) return;
      AppFeedback.showSuccessSnackBar(
        context,
        '${widget.member.name}님에게 식단 목표를 보냈어요',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await showAppConfirmDialog(
      context,
      title: '식단 목표 지우기',
      message: '${widget.member.name}님의 식단 화면에서 목표가 사라집니다.',
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await NutritionPlanService.delete(widget.member.uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Widget _numberField(
    String label,
    TextEditingController controller,
    String unit,
  ) => AppTextField(
    label: label,
    hint: '비워 둘 수 있어요',
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    unit: unit,
    strongValue: true,
    textInputAction: TextInputAction.next,
  );

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '식단 목표',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.base,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                children: [
                  Text('${widget.member.name}님', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '정한 목표는 회원의 식단 화면 맨 위에 보이고, 저장하면 알림이 가요.',
                    style: AppTextStyles.bodySm,
                  ),

                  // ── 추천 ──
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.canvasCard,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('추천으로 시작하기', style: AppTextStyles.bodyMd.bold),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            for (final goal in NutritionGoal.values) ...[
                              if (goal != NutritionGoal.values.first)
                                const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppChip(
                                  label: goal.label,
                                  selected: _goal == goal,
                                  cell: true,
                                  onTap: () => setState(() => _goal = goal),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          recommendation == null
                              ? '인바디나 신체 정보에 체중을 먼저 입력하면 추천해 드려요.'
                              : '${recommendation.basis}\n'
                                    '→ ${recommendation.calories}kcal · 탄수 ${recommendation.carbs}g · '
                                    '단백질 ${recommendation.protein}g · 지방 ${recommendation.fat}g',
                          style: AppTextStyles.bodySm.copyWith(height: 1.5),
                        ),
                        if (recommendation != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            label: '추천값 채우기',
                            variant: AppButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: _fillRecommendation,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── 하루 권장 ──
                  const SizedBox(height: AppSpacing.xl),
                  Text('하루 권장', style: AppTextStyles.section),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _numberField('칼로리', _calories, 'kcal')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _numberField('탄수화물', _carbs, 'g')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _numberField('단백질', _protein, 'g')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _numberField('지방', _fat, 'g')),
                    ],
                  ),

                  // ── 끼니별 가이드 ──
                  const SizedBox(height: AppSpacing.xl),
                  Text('끼니별 가이드', style: AppTextStyles.section),
                  const SizedBox(height: AppSpacing.xs),
                  Text('적은 끼니만 회원에게 보여요.', style: AppTextStyles.bodySm),
                  for (final type in _mealOrder) ...[
                    const SizedBox(height: AppSpacing.base),
                    AppTextField(
                      label: type.label,
                      hint: _guideHints[type],
                      controller: _guides[type],
                      maxLines: 2,
                      maxLength: NutritionPlan.guideMaxLength,
                      textInputAction: TextInputAction.next,
                    ),
                  ],

                  // ── 한마디 ──
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: '트레이너 한마디',
                    hint: '예: 저녁 탄수화물을 줄이고, 물을 하루 2L 마셔요',
                    controller: _note,
                    minLines: 3,
                    maxLines: 4,
                    maxLength: NutritionPlan.noteMaxLength,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
            AppBottomActionBar(
              secondaryLabel: widget.existing == null ? null : '지우기',
              onSecondary: _saving ? null : _delete,
              primaryLabel: _saving ? '저장 중' : '저장',
              loading: _saving,
              onPrimary: _saving ? null : _save,
              primaryVariant: AppButtonVariant.dark,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}
