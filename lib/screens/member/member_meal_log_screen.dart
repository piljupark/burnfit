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
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/brand_marks.dart';
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
  Map<String, fb.Feedback> _feedbacks = {};

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

  /// 피드백 완료 식단의 트레이너 코멘트. 실패해도 태그만 보인다.
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
          (m) => FirestoreService.getFeedbackByTarget(
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
            if (results[i] != null) targets[i].id: results[i]!,
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

  Future<void> _addMeal() => _openMealInput();

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
              onAdd: _addMeal,
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

/// 머리 (56): 뒤로 · 가운데 '‹ 10월 8일 (목) ›' · 식단 추가.
class _DayNavHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onAdd;

  const _DayNavHeader({
    required this.date,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
    required this.onAdd,
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
            child: Icon(icon, size: 16, color: AppColors.mute),
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
                      icon: AppIcons.back,
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
                      style: AppTextStyles.section,
                    ),
                  ),
                  const SizedBox(width: 2),
                  arrow(AppIcons.chevronRightBold, '다음 날', onNext),
                ],
              ),
            ),
            AppIconButton(
              icon: AppIcons.add,
              label: '식단 추가',
              iconSize: 24,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

/// 먹은 양 카드 (회색, 반경 20): '오늘 먹은 양' 14 body / '1,240kcal' 30.
/// 시안의 목표 열량·탄단지 막대는 아직 데이터가 없어 그리지 않는다.
class _IntakeCard extends StatelessWidget {
  final String label;
  final int? kcal;

  const _IntakeCard({required this.label, required this.kcal});

  @override
  Widget build(BuildContext context) {
    final big = AppTextStyles.displayMd.copyWith(
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

/// 끼니 한 줄 (60): 끼니 이름(52 폭, 15/700) · 먹은 것(14 body) · kcal(15/700).
/// 기록이 없으면 오른쪽에 '기록하기' pill.
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
    final strong = AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700);
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
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
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

/// 영양 가이드 안내 카드: 위 150 연한 주황 + 그릇 그림, 아래 흰 칸에 한 줄 팁 + '알아보기'.
class _GuideCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GuideCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.noticeLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            color: AppColors.noticeBg,
            alignment: Alignment.bottomCenter,
            child: const ExcludeSemantics(child: MealBowlIllustration()),
          ),
          Container(
            color: AppColors.canvas,
            padding: const EdgeInsets.fromLTRB(18, AppSpacing.base, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('운동 직후엔 단백질 30g', style: AppTextStyles.listTitle),
                      const SizedBox(height: 2),
                      Text('닭가슴살 한 팩이면 충분해요', style: AppTextStyles.bodySm),
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

/// 끼니 시트: 그 끼니의 기록마다 사진 · 메모 · kcal · 피드백(+ 삭제), 아래 '추가' 버튼.
class _MealTypeSheet extends StatelessWidget {
  final MealType type;
  final List<Meal> meals;
  final Map<String, fb.Feedback> feedbacks;

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
            child: AppBottomSheetHeader(title: type.label),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final meal in meals)
                  _MealEntry(
                    meal: meal,
                    feedback: feedbacks[meal.id],
                    onDelete: () =>
                        Navigator.of(context).pop(_DeleteMeal(meal)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
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

// ── 끼니 한 덩어리: 머리말(끼니 + 시각) → 사진 3열 → 캡션 줄 → 트레이너 피드백 ──
class _MealEntry extends StatelessWidget {
  final Meal meal;
  final fb.Feedback? feedback;
  final VoidCallback onDelete;

  const _MealEntry({
    required this.meal,
    required this.feedback,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = (meal.description ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMonthHeader(
          label: meal.mealType.label,
          count: meal.mealTime,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.base,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          trailing: AppIconButton(
            icon: AppIcons.trash,
            label: '${meal.mealType.label} 식단 삭제',
            color: AppColors.body,
            onPressed: onDelete,
          ),
        ),
        if (meal.imageUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: _MealPhotoGrid(
              urls: meal.imageUrls,
              mealLabel: meal.mealType.label,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description.isEmpty ? '메모 없음' : description,
                  style: description.isEmpty
                      ? AppTextStyles.bodyMd.copyWith(color: AppColors.mute)
                      : AppTextStyles.bodyMd,
                ),
              ),
              if (meal.calories != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${NumberFormat('#,###').format(meal.calories)}kcal',
                    style: AppTextStyles.counter.copyWith(
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              meal.hasFeedback
                  ? const AppTag('피드백 완료', strong: true)
                  : const AppTag('검토 대기'),
            ],
          ),
        ),
        if (feedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              0,
            ),
            child: _FeedbackQuote(feedback: feedback!),
          ),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

/// 사진 3열 격자 (간격 2, 반경 0). 3장 넘으면 마지막 칸에 +N 배지.
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
        mainAxisSpacing: AppSpacing.xxs,
        crossAxisSpacing: AppSpacing.xxs,
      ),
      itemBuilder: (_, i) {
        final isLast = i == shown.length - 1 && extra > 0;
        return Semantics(
          image: true,
          label: isLast
              ? '$mealLabel 식단 사진 ${i + 1}, 외 $extra장'
              : '$mealLabel 식단 사진 ${i + 1}',
          excludeSemantics: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.canvasSoft,
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
                Positioned(
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: AppCountBadge('+$extra'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 트레이너 코멘트 인용 카드: 작은 아바타 + 이름 + 시각 + 본문.
class _FeedbackQuote extends StatelessWidget {
  final fb.Feedback feedback;

  const _FeedbackQuote({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final name = feedback.trainerName.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? '트레이너' : '$name 트레이너',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat('HH:mm').format(feedback.createdAt),
                style: AppTextStyles.counter.copyWith(color: AppColors.body),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(feedback.content, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}
