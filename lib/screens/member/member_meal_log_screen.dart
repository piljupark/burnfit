import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../models/food_guide.dart';
import '../../models/meal.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/brand_marks.dart';
import '../../widgets/feedback_sheet.dart';
import 'food_detail_sheet.dart';
import 'meal_input_sheet.dart';
import 'nutrition_guide_screen.dart';

class MemberMealLogScreen extends StatefulWidget {
  /// 처음 보여줄 날짜. 없으면 오늘.
  final DateTime? initialDate;

  const MemberMealLogScreen({super.key, this.initialDate});

  @override
  State<MemberMealLogScreen> createState() => _MemberMealLogScreenState();
}

class _MemberMealLogScreenState extends State<MemberMealLogScreen> {
  late DateTime _selectedDate = widget.initialDate ?? DateTime.now();
  List<Meal> _meals = [];
  bool _isLoading = false;

  /// 식단 id → 트레이너 피드백 (피드백 완료된 식단만).
  /// 식단별 트레이너 피드백 (담당이 바뀌면 여러 개일 수 있다, 오래된 순).
  Map<String, List<fb.Feedback>> _feedbacks = {};

  static final _keyFormat = DateFormat('yyyy-MM-dd');

  String get _dateKey => _keyFormat.format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 날짜를 빠르게 바꿀 때 늦게 도착한 이전 날짜 결과가 화면을 덮지 않게 한다.
  int _loadId = 0;

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final loadId = ++_loadId;
    setState(() => _isLoading = true);
    try {
      final list = await MealService.getMealsByDate(
        user.centerId,
        user.uid,
        _dateKey,
      );
      if (!mounted || loadId != _loadId) return;
      setState(() => _meals = list);
      _loadFeedbacks(list, user.centerId, user.uid);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 피드백 완료 식단의 트레이너 코멘트. 실패해도 상태 글자만 보인다.
  Future<void> _loadFeedbacks(
    List<Meal> meals,
    String centerId,
    String memberId,
  ) async {
    final targets = meals.where((m) => m.hasFeedback).toList();
    if (targets.isEmpty) {
      if (mounted) setState(() => _feedbacks = {});
      return;
    }
    try {
      final results = await Future.wait(
        targets.map(
          (m) => FirestoreService.getFeedbacksByTarget(
            m.id,
            centerId: centerId,
            memberId: memberId,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _feedbacks = {
          for (var i = 0; i < targets.length; i++)
            if (results[i].isNotEmpty) targets[i].id: results[i],
        };
      });
    } catch (e) {
      AppLogger.debug('[식단 피드백 조회 오류] $e');
    }
  }

  int get _totalCalories =>
      _meals.fold<int>(0, (sum, m) => sum + (m.calories ?? 0));

  /// 식단 입력 화면을 연다. 저장되면 목록을 다시 불러오고 true.
  Future<bool> _openMealInput({
    MealType? initialMealType,
    String? initialDescription,
    int? initialCalories,
  }) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealInputSheet(
          centerId: user.centerId,
          memberId: user.uid,
          memberName: user.name,
          trainerId: user.trainerId,
          selectedDate: _dateKey,
          initialMealType: initialMealType,
          initialDescription: initialDescription,
          initialCalories: initialCalories,
        ),
      ),
    );
    if (result != true) return false;
    _load();
    return true;
  }

  /// 영양 가이드. 음식 상세의 추가 버튼은 선택한 날짜의 식단 입력을 미리 채워 연다.
  void _openNutritionGuide() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dayLabel = isToday
        ? '오늘'
        : DateFormat('M월 d일', 'ko').format(_selectedDate);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NutritionGuideScreen(
          addAction: FoodAddAction(
            label: '$dayLabel 식단에 추가',
            onAdd: _addFoodToMeals,
          ),
        ),
      ),
    );
  }

  Future<void> _addFoodToMeals(FoodItem food) async {
    final saved = await _openMealInput(
      initialMealType: mealTypeForTime(DateTime.now()),
      initialDescription: food.mealDescription,
      initialCalories: food.kcal,
    );
    if (!saved || !mounted) return;
    // 가이드·목록 화면을 닫고 방금 저장한 식단이 보이는 이 화면으로 돌아온다.
    final self = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == self);
    AppFeedback.showSuccessSnackBar(context, '${food.name}을(를) 식단에 추가했어요');
  }

  Future<void> _deleteMeal(Meal meal) async {
    final photoNote = meal.imageUrls.isEmpty
        ? ''
        : ' 사진 ${meal.imageUrls.length}장도 함께 사라집니다.';
    final confirm = await showAppConfirmDialog(
      context,
      title: '식단 삭제',
      message: '${meal.mealType.label} 식단 기록을 삭제할까요?$photoNote',
      confirmLabel: '삭제',
    );
    if (confirm != true) return;
    try {
      await MealService.deleteMeal(meal.id, meal.imageUrls);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  void _moveDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _load();
  }

  /// 끼니 줄을 누르면 그 끼니의 기록(사진·트레이너 피드백·삭제)을 시트로 연다.
  /// 시트 아래 '○○ 추가' 버튼으로 이미 기록된 끼니에도 한 번 더 기록할 수 있다.
  Future<void> _openMealType(MealType type, List<Meal> meals) async {
    final action = await showAppBottomSheet<_MealSheetAction>(
      context: context,
      padded: false,
      child: _MealTypeSheet(type: type, meals: meals, feedbacks: _feedbacks),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AddMeal():
        await _openMealInput(initialMealType: type);
      case _DeleteMeal(:final meal):
        await _deleteMeal(meal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayNavHeader(
              date: _selectedDate,
              onBack: canPop ? () => Navigator.of(context).pop() : null,
              onPrev: () => _moveDay(-1),
              onNext: () => _moveDay(1),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.ink,
                backgroundColor: AppColors.canvasCard,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _IntakeCard(
                      label: isToday ? '오늘 먹은 양' : '이 날 먹은 양',
                      kcal: _isLoading ? null : _totalCalories,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                        child: Center(
                          child: AppLoader(semanticLabel: '식단 불러오는 중'),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.xl,
                          AppSpacing.screenH,
                          0,
                        ),
                        child: Column(
                          children: [
                            for (final type in _typeOrder)
                              _MealTypeRow(
                                type: type,
                                meals: _meals
                                    .where((m) => m.mealType == type)
                                    .toList(),
                                onOpen: (meals) => _openMealType(type, meals),
                                onAdd: () =>
                                    _openMealInput(initialMealType: type),
                              ),
                          ],
                        ),
                      ),
                    _GuideCard(onTap: _openNutritionGuide),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 시안 순서: 아침 · 점심 · 간식 · 저녁
  static const _typeOrder = [
    MealType.breakfast,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];
}

/// 머리 (56): 뒤로 · 가운데 '‹ 10월 8일 (목) ›' · 오른쪽 빈 칸 44 (시안 Meal).
/// 끼니 추가는 줄의 '기록하기'와 끼니 시트의 '추가' 버튼이 맡는다.
class _DayNavHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DayNavHeader({
    required this.date,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, String label, VoidCallback onTap) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 36,
            height: AppSize.touchMin,
            // 시안: 16, 선 #8B8B90
            child: Icon(icon, size: 16, color: AppColors.dots),
          ),
        ),
      );
    }

    return SizedBox(
      height: AppSize.appBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: AppSize.touchMin,
              child: onBack == null
                  ? null
                  : AppIconButton(
                      icon: AppIcons.backBold,
                      label: '뒤로',
                      iconSize: 24,
                      onPressed: onBack,
                    ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  arrow(AppIcons.chevronLeftBold, '이전 날', onPrev),
                  const SizedBox(width: 2),
                  Semantics(
                    header: true,
                    child: Text(
                      DateFormat('M월 d일 (E)', 'ko').format(date),
                      style: AppTextStyles.section.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  arrow(AppIcons.chevronRightBold, '다음 날', onNext),
                ],
              ),
            ),
            const SizedBox(width: AppSize.touchMin),
          ],
        ),
      ),
    );
  }
}

/// 먹은 양 카드 (회색, 반경 20): '오늘 먹은 양' 14 body / '1,240kcal' 30 (숫자 700).
/// 시안의 목표 열량·탄단지 막대는 아직 데이터가 없어 그리지 않는다.
class _IntakeCard extends StatelessWidget {
  final String label;
  final int? kcal;

  const _IntakeCard({required this.label, required this.kcal});

  @override
  Widget build(BuildContext context) {
    final big = AppTextStyles.displayMd.bold.copyWith(
      fontSize: 30,
      height: 36 / 30,
      letterSpacing: 30 * -0.019,
    );
    final value = kcal == null ? '–' : NumberFormat('#,##0').format(kcal);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Semantics(
        label: '$label $value 킬로칼로리',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.note),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: 'kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.mute,
                    ),
                  ),
                ],
              ),
              style: big,
            ),
          ],
        ),
      ),
    );
  }
}

/// 끼니 한 줄 (60, 아래 1px hairline): 끼니 이름(52 폭, 15/700) · 먹은 것(14 body) · kcal(15/700).
/// 기록이 없으면 오른쪽에 '기록하기' 알약(34, 13/700).
class _MealTypeRow extends StatelessWidget {
  final MealType type;
  final List<Meal> meals;
  final ValueChanged<List<Meal>> onOpen;
  final VoidCallback onAdd;

  const _MealTypeRow({
    required this.type,
    required this.meals,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final strong = AppTextStyles.bodyMd.bold;
    final descriptions = meals
        .map((m) => (m.description ?? '').trim())
        .where((d) => d.isNotEmpty)
        .join(', ');
    final photoCount = meals.fold<int>(0, (n, m) => n + m.imageUrls.length);
    final hasKcal = meals.any((m) => m.calories != null);
    final kcal = meals.fold<int>(0, (sum, m) => sum + (m.calories ?? 0));
    final empty = meals.isEmpty;
    final summary = empty
        ? ''
        : descriptions.isNotEmpty
        ? descriptions
        : photoCount > 0
        ? '사진 $photoCount장'
        : '메모 없음';

    final row = Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(type.label, style: strong)),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.note,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (empty)
            Semantics(
              button: true,
              label: '${type.label} 기록하기',
              excludeSemantics: true,
              child: Material(
                color: AppColors.canvasSoft,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  splashFactory: NoSplash.splashFactory,
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '기록하기',
                      style: AppTextStyles.bodySm.bold.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (hasKcal)
            Text('${NumberFormat('#,##0').format(kcal)}kcal', style: strong),
        ],
      ),
    );
    if (empty) return row;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => onOpen(meals),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: row,
      ),
    );
  }
}

/// 영양 가이드 안내 카드 (시안 Meal): 위 150 연한 주황(#FFF3EA) + 그릇 그림,
/// 아래 흰 칸(테두리 #F3E4D8, 위쪽 선 없음, 아래 모서리 20)에 한 줄 팁 + '알아보기'.
class _GuideCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GuideCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const bottomRadius = BorderRadius.vertical(
      bottom: Radius.circular(AppRadius.card),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            color: AppColors.noticeSoft,
            alignment: Alignment.bottomCenter,
            child: const ExcludeSemantics(child: MealBowlIllustration()),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, AppSpacing.base, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: bottomRadius,
              border: const Border(
                left: BorderSide(color: AppColors.noticeLine),
                right: BorderSide(color: AppColors.noticeLine),
                bottom: BorderSide(color: AppColors.noticeLine),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '운동 직후엔 단백질 30g',
                        style: AppTextStyles.listTitle.bold,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '닭가슴살 한 팩이면 충분해요',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Semantics(
                  button: true,
                  label: '영양 가이드 알아보기',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    shape: StadiumBorder(
                      side: BorderSide(color: AppColors.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      splashFactory: NoSplash.splashFactory,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '알아보기',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 끼니 시트가 돌려주는 행동.
sealed class _MealSheetAction {
  const _MealSheetAction();
}

class _AddMeal extends _MealSheetAction {
  const _AddMeal();
}

class _DeleteMeal extends _MealSheetAction {
  final Meal meal;

  const _DeleteMeal(this.meal);
}

/// 끼니 시트: 그 끼니의 기록마다 덩어리(시안 MemB-MealLog) + 아래 '○○ 추가' 버튼.
/// 기록이 여럿이면 덩어리 사이에 1px 선(위 20)을 긋는다.
class _MealTypeSheet extends StatelessWidget {
  final MealType type;
  final List<Meal> meals;
  final Map<String, List<fb.Feedback>> feedbacks;

  const _MealTypeSheet({
    required this.type,
    required this.meals,
    required this.feedbacks,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: AppBottomSheetHeader(title: type.label, gap: 0),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              // 시트 안 목록: 안전 영역 여백이 저절로 붙지 않게 0으로 둔다
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < meals.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const AppRowDivider(),
                  ],
                  AppEntrance(
                    delay: Duration(milliseconds: 80 * i),
                    child: _MealEntry(
                      meal: meals[i],
                      feedbacks: feedbacks[meals[i].id] ?? const [],
                      onDelete: () =>
                          Navigator.of(context).pop(_DeleteMeal(meals[i])),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              0,
            ),
            child: AppButton(
              label: '${type.label} 추가',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(const _AddMeal()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 끼니 한 덩어리 (시안 MemB-MealLog): 머리(끼니 17/500 + 시각 14 mute, 삭제)
//    → 사진 3열(간격 6, 반경 14) → 메모 16 + kcal(15/500 + 'kcal' mute) → 상태 13 → 피드백 상자 ──
class _MealEntry extends StatelessWidget {
  final Meal meal;
  final List<fb.Feedback> feedbacks;
  final VoidCallback onDelete;

  const _MealEntry({
    required this.meal,
    required this.feedbacks,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = (meal.description ?? '').trim();
    final hasPhotos = meal.imageUrls.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(meal.mealType.label, style: AppTextStyles.section),
                    if (meal.mealTime != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        meal.mealTime!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppIconButton(
                icon: AppIcons.trash,
                label: '${meal.mealType.label} 식단 삭제',
                color: AppColors.mute,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
        if (hasPhotos)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              6,
              AppSpacing.screenH,
              0,
            ),
            child: _MealPhotoGrid(
              urls: meal.imageUrls,
              mealLabel: meal.mealType.label,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            hasPhotos ? AppSpacing.md : 6,
            AppSpacing.screenH,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  description.isEmpty ? '메모 없음' : description,
                  style: description.isEmpty
                      ? AppTextStyles.input.copyWith(color: AppColors.faint)
                      : AppTextStyles.input,
                ),
              ),
              if (meal.calories != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: NumberFormat('#,##0').format(meal.calories),
                      ),
                      TextSpan(
                        text: 'kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                  style: AppTextStyles.bodyMd.medium,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            0,
          ),
          child: meal.hasFeedback
              ? Text(
                  '피드백 완료',
                  style: AppTextStyles.bodySm.medium.copyWith(
                    color: AppColors.ink,
                  ),
                )
              : Text('검토 대기', style: AppTextStyles.bodySm),
        ),
        for (final feedback in feedbacks)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              0,
            ),
            child: FeedbackQuote(feedback: feedback),
          ),
      ],
    );
  }
}

/// 사진 3열 격자 (간격 6, 반경 14). 3장 넘으면 마지막 칸 전체를 덮개 + '+N'(20/500 흰 글자).
class _MealPhotoGrid extends StatelessWidget {
  final List<String> urls;
  final String mealLabel;

  const _MealPhotoGrid({required this.urls, required this.mealLabel});

  @override
  Widget build(BuildContext context) {
    const maxTiles = 3;
    final shown = urls.take(maxTiles).toList();
    final extra = urls.length - shown.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: shown.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (_, i) {
        final isLast = i == shown.length - 1 && extra > 0;
        return Semantics(
          image: true,
          label: isLast
              ? '$mealLabel 식단 사진 ${i + 1}, 외 $extra장'
              : '$mealLabel 식단 사진 ${i + 1}',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.track,
                  child: Image.network(
                    shown[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        AppIcons.image,
                        size: AppSize.icon,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ),
                if (isLast)
                  ColoredBox(
                    color: const Color(0x8C191919),
                    child: Center(
                      child: Text(
                        '+$extra',
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
