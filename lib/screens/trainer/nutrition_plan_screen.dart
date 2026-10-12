import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/meal.dart';
import '../../models/nutrition_plan.dart';
import '../../models/user.dart';
import '../../services/nutrition_plan_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';

/// 트레이너: 회원 식단 목표 정하기 (시안 08 '식단 목표 · 정리안').
///
/// 가운데 '식단 목표' (+ 있던 목표면 ⋯ → '목표 지우기') → 회원 이름 22 →
/// '하루 목표' + '비워 두면 회원에게 안 보여요' → 선택 막대(감량 · 유지 · 증량 · 직접) →
/// 칼로리 한 줄(24/700, 쉼표) → 탄수화물 · 단백질 · 지방 3칸 → 근거 한 줄 12 →
/// '끼니별 가이드'(끼니 이름 + 한 줄 칸) → '트레이너 한마디' → 아래 '저장' 하나.
///
/// 막대에서 감량 등을 고르면 추천값이 바로 들어가고, 숫자를 고치면 '직접'으로 바뀐다.
/// 저장하면 true로 닫힌다 (회원에게 알림은 서버가 보낸다).
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
    MealType.breakfast: '달걀 2개 + 바나나',
    MealType.lunch: '단백질 손바닥 1개 + 밥 2/3',
    MealType.snack: '그릭요거트',
    MealType.dinner: '밥 반 공기, 채소 두 주먹',
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

  /// 고른 목표. null = '직접' (트레이너가 숫자를 정함).
  NutritionGoal? _goal;
  bool _saving = false;

  /// 추천값을 넣는 동안은 '직접'으로 바꾸지 않는다.
  bool _filling = false;

  static final _thousands = NumberFormat('#,##0');

  static TextEditingController _numberController(int? value) =>
      TextEditingController(
        text: value == null ? '' : _thousands.format(value),
      );

  bool get _canRecommend => _recommend(NutritionGoal.maintain) != null;

  NutritionRecommendation? _recommend(NutritionGoal goal) =>
      NutritionRecommendation.from(
        bmr: widget.bmr,
        weight: widget.weight,
        goal: goal,
      );

  @override
  void initState() {
    super.initState();
    // 새 목표이고 추천할 수 있으면 '유지' 추천값으로 시작한다. 있던 목표는 '직접'.
    if (widget.existing == null && _canRecommend) {
      _pick(NutritionGoal.maintain, haptic: false);
    }
    for (final c in [_calories, _carbs, _protein, _fat]) {
      c.addListener(_onNumberEdited);
    }
  }

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

  void _onNumberEdited() {
    if (_filling || _goal == null) return;
    setState(() => _goal = null);
  }

  void _pick(NutritionGoal? goal, {bool haptic = true}) {
    if (haptic) AppHaptics.selection();
    if (goal == null) {
      setState(() => _goal = null);
      return;
    }
    final r = _recommend(goal);
    if (r == null) return;
    _filling = true;
    _calories.text = _thousands.format(r.calories);
    _carbs.text = _thousands.format(r.carbs);
    _protein.text = _thousands.format(r.protein);
    _fat.text = _thousands.format(r.fat);
    _filling = false;
    setState(() => _goal = goal);
  }

  String get _basis {
    if (!_canRecommend) return '인바디나 신체 정보에 체중을 입력하면 추천해 드려요.';
    if (_goal == null) return '직접 정한 값이에요. 위에서 고르면 추천값으로 바뀌어요.';
    final bmr = widget.bmr;
    final base = bmr != null && bmr > 0
        ? '기초대사량 ${_thousands.format(bmr.round())} · 활동 보통'
        : '체중 ${_weightText}kg';
    return "$base 기준 추천 · 숫자를 고치면 '직접'으로 바뀌어요";
  }

  String get _weightText {
    final w = widget.weight ?? 0;
    return w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
  }

  NutritionPlan _plan() {
    int? n(TextEditingController c) =>
        int.tryParse(c.text.replaceAll(',', '').trim());
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

  Future<void> _showMore() async {
    final delete = await showAppBottomSheet<bool>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(
              title: '식단 목표',
              subtitle: '${widget.member.name}님',
              mutedSubtitle: true,
              gap: AppSpacing.md,
            ),
            AppSheetAction(
              icon: AppIcons.trash,
              label: '목표 지우기',
              destructive: true,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (delete == true && mounted) await _delete();
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

  @override
  Widget build(BuildContext context) {
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
              trailing: widget.existing == null
                  ? null
                  : AppIconButton(
                      icon: AppIcons.moreBold,
                      label: '더보기',
                      onPressed: _saving ? null : _showMore,
                    ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                children: [
                  Text('${widget.member.name}님', style: AppTextStyles.title),

                  // ── 하루 목표 ──
                  const _SectionHead(
                    title: '하루 목표',
                    caption: '비워 두면 회원에게 안 보여요',
                  ),
                  if (_canRecommend) ...[
                    const SizedBox(height: AppSpacing.md),
                    _GoalSegment(selected: _goal, onSelect: _pick),
                  ],
                  const SizedBox(height: 10),
                  _CaloriesField(controller: _calories),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroField(label: '탄수화물', controller: _carbs),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _MacroField(label: '단백질', controller: _protein),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _MacroField(label: '지방', controller: _fat),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_basis, style: AppTextStyles.captionSmall),

                  // ── 끼니별 가이드 ──
                  const _SectionHead(title: '끼니별 가이드', caption: '적은 끼니만 보여요'),
                  const SizedBox(height: 10),
                  for (final type in _mealOrder)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              type.label,
                              style: AppTextStyles.bodyMd.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _PlainField(
                              controller: _guides[type]!,
                              hint: _guideHints[type]!,
                              semanticLabel: '${type.label} 가이드',
                              maxLength: NutritionPlan.guideMaxLength,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── 한마디 ──
                  const _SectionHead(title: '트레이너 한마디'),
                  const SizedBox(height: 10),
                  _PlainField(
                    controller: _note,
                    hint: '예: 저녁 탄수화물을 줄이고, 물을 하루 2L 마셔요',
                    semanticLabel: '트레이너 한마디',
                    maxLength: NutritionPlan.noteMaxLength,
                    minLines: 3,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            AppBottomActionBar(
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

/// 섹션 머리: 제목 17/500 + 오른쪽 13 mute 안내 (위 26).
class _SectionHead extends StatelessWidget {
  final String title;
  final String? caption;

  const _SectionHead({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppTextStyles.section)),
          if (caption != null) Text(caption!, style: AppTextStyles.bodySm),
        ],
      ),
    );
  }
}

/// 선택 막대 (감량 · 유지 · 증량 · 직접): 회색 트랙 안쪽 4, 고른 칸만 흰 바탕(다크는 canvasMid) + 700.
class _GoalSegment extends StatelessWidget {
  final NutritionGoal? selected;
  final void Function(NutritionGoal?) onSelect;

  const _GoalSegment({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = <(NutritionGoal?, String)>[
      for (final g in NutritionGoal.values) (g, g.label),
      (null, '직접'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          for (final (goal, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: goal == selected,
                inMutuallyExclusiveGroup: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onSelect(goal),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: goal == selected
                          ? (AppColors.isLight
                                ? AppColors.canvas
                                : AppColors.canvasMid)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: goal == selected && AppColors.isLight
                          ? const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: goal == selected
                            ? AppColors.ink
                            : AppColors.body,
                        fontWeight: goal == selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 숫자 입력 (쉼표 넣기, 4자리까지). 빈 칸은 '–'.
List<TextInputFormatter> get _numberFormatters => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
  TextInputFormatter.withFunction((old, next) {
    if (next.text.isEmpty) return next;
    final text = NumberFormat('#,##0').format(int.parse(next.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }),
];

/// 칼로리 한 줄 (높이 60, canvasCard 반경 16): '칼로리' 15 body … 숫자 24/700 + 'kcal' 14 mute.
class _CaloriesField extends StatelessWidget {
  final TextEditingController controller;

  const _CaloriesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '칼로리',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
          ),
          SizedBox(
            width: 120,
            child: _NumberInput(
              controller: controller,
              semanticLabel: '하루 칼로리',
              style: AppTextStyles.displayMd.copyWith(
                fontSize: 24,
                height: 30 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'kcal',
            style: AppTextStyles.note.copyWith(color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}

/// 탄단지 한 칸 (canvasCard 반경 18, 안쪽 10 12): 이름 12 mute / 숫자 20/700 + 'g'.
class _MacroField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MacroField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.captionSmall),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _NumberInput(
                  controller: controller,
                  semanticLabel: '하루 $label 그램',
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('g', style: AppTextStyles.bodySm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String semanticLabel;
  final TextStyle style;

  const _NumberInput({
    required this.controller,
    required this.semanticLabel,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: _numberFormatters,
        textAlign: TextAlign.right,
        style: style.copyWith(
          color: AppColors.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        cursorColor: AppColors.ink,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: '–',
          hintStyle: style.copyWith(
            color: AppColors.faint,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// 한 줄(또는 여러 줄) 글 칸: canvasSoft 반경 14, 높이 48, 15 글자, 글자 수 표시 없음.
class _PlainField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String semanticLabel;
  final int maxLength;
  final int minLines;
  final int maxLines;

  const _PlainField({
    required this.controller,
    required this.hint,
    required this.semanticLabel,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.ink),
        cursorColor: AppColors.ink,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.canvasSoft,
          hintText: hint,
          hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.faint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            borderSide: BorderSide(color: AppColors.ink, width: 1.5),
          ),
        ),
      ),
    );
  }
}
