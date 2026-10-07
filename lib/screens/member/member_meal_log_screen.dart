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
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/orb_loader.dart';
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
  int _filterIndex = 0;

  /// 이번 주에 기록이 있는 날짜(yyyy-MM-dd) — 주간 스트립 점 표시용.
  Set<String> _weekRecordDates = {};

  /// 식단 id → 트레이너 피드백 (피드백 완료된 식단만).
  Map<String, fb.Feedback> _feedbacks = {};

  static const _filterLabels = ['전체', '아침', '점심', '저녁', '간식'];
  static final _keyFormat = DateFormat('yyyy-MM-dd');

  String get _dateKey => _keyFormat.format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    _loadWeekMarkers(user.centerId, user.uid);
    try {
      final list = await MealService.getMealsByDate(
        user.centerId,
        user.uid,
        _dateKey,
      );
      if (!mounted) return;
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

  /// 주간 스트립의 기록 점. 실패해도 화면은 그대로 둔다.
  Future<void> _loadWeekMarkers(String centerId, String memberId) async {
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    try {
      final meals = await MealService.getMealsByDateRange(
        centerId,
        memberId,
        _keyFormat.format(monday),
        _keyFormat.format(sunday),
      );
      if (!mounted) return;
      setState(() => _weekRecordDates = meals.map((m) => m.mealDate).toSet());
    } catch (e) {
      AppLogger.debug('[식단 주간 표시 오류] $e');
    }
  }

  /// 피드백 완료 식단의 트레이너 코멘트. 실패해도 태그만 보인다.
  Future<void> _loadFeedbacks(List<Meal> meals, String centerId, String memberId) async {
    final targets = meals.where((m) => m.hasFeedback).toList();
    if (targets.isEmpty) {
      if (mounted) setState(() => _feedbacks = {});
      return;
    }
    try {
      final results = await Future.wait(
        targets.map(
          (m) => FirestoreService.getFeedbackByTarget(m.id, centerId: centerId, memberId: memberId),
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

  List<Meal> get _filtered {
    if (_filterIndex == 0) return _meals;
    final types = [
      null,
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    return _meals.where((m) => m.mealType == types[_filterIndex]).toList();
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
    final dayLabel = isToday ? '오늘' : DateFormat('M월 d일', 'ko').format(_selectedDate);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NutritionGuideScreen(
          addAction: FoodAddAction(label: '$dayLabel 식단에 추가', onAdd: _addFoodToMeals),
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
    final photoNote = meal.imageUrls.isEmpty ? '' : ' 사진 ${meal.imageUrls.length}장도 함께 사라집니다.';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('식단 삭제'),
        content: Text(
          '${meal.mealType.label} 식단 기록을 삭제할까요?$photoNote',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
        ),
        actions: [
          AppButton(
            label: '취소',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: '삭제',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
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

  void _selectDate(DateTime d) {
    setState(() => _selectedDate = d);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final canPop = Navigator.of(context).canPop();
    final kcal = NumberFormat('#,###').format(_totalCalories);
    final mealCount = _meals.length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.screenH, right: AppSpacing.xs),
              child: AppScreenHeader(
                title: '식단 기록',
                onBack: canPop ? () => Navigator.of(context).pop() : null,
                trailing: AppIconButton(
                  icon: AppIcons.add,
                  label: '식단 추가',
                  onPressed: _addMeal,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.ink,
                backgroundColor: AppColors.canvasCard,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _WeekStrip(
                        selected: _selectedDate,
                        recordDates: _weekRecordDates,
                        onSelect: _selectDate,
                      ),
                    ),
                    const SliverToBoxAdapter(child: AppRowDivider()),
                    SliverToBoxAdapter(
                      child: AppScrollableChips(
                        labels: _filterLabels,
                        selectedIndex: _filterIndex,
                        onSelected: (i) => setState(() => _filterIndex = i),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.sm,
                          AppSpacing.screenH,
                          0,
                        ),
                      ),
                    ),
                    if (!_isLoading && mealCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            AppSpacing.sm,
                            AppSpacing.screenH,
                            0,
                          ),
                          child: Semantics(
                            label: '총 $kcal 킬로칼로리, $mealCount끼',
                            excludeSemantics: true,
                            child: Text(
                              '${kcal}kcal · $mealCount끼',
                              style: AppTextStyles.bodySm,
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.md,
                          AppSpacing.screenH,
                          0,
                        ),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: AppActionRow(
                            icon: AppIcons.meal,
                            label: '뭐 먹을지 고민될 때',
                            subtitle: '상황별 · 영양소별 추천 음식 보기',
                            onTap: _openNutritionGuide,
                          ),
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl4),
                          child: Center(child: OrbLoader(semanticLabel: '식단 불러오는 중')),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: AppEmptyState(
                          icon: AppIcons.meal,
                          message: '기록된 식단이 없습니다',
                          description: '먹은 음식을 사진과 함께 남기면 트레이너가 피드백을 드려요.',
                          actionLabel: '식단 추가',
                          onAction: _addMeal,
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _MealEntry(
                          meal: filtered[i],
                          feedback: _feedbacks[filtered[i].id],
                          onDelete: () => _deleteMeal(filtered[i]),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
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

// ── 주간 스트립: 요일 캡션 + 날짜 원. 선택 = 흰 원, 오늘 = 외곽선 원, 기록 있음 = 점 ──
class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final Set<String> recordDates;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({
    required this.selected,
    required this.recordDates,
    required this.onSelect,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateUtils.dateOnly(DateTime.now());
    final keyFormat = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: days.map((day) {
          final isSel = DateUtils.isSameDay(day, selected);
          final isToday = DateUtils.isSameDay(day, today);
          final isFuture = DateUtils.dateOnly(day).isAfter(today);
          final hasRecord = recordDates.contains(keyFormat.format(day));
          final weekday = _weekdays[day.weekday - 1];

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSel,
              label: '${day.month}월 ${day.day}일 $weekday요일${hasRecord ? ', 기록 있음' : ''}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(day),
                child: Column(
                  children: [
                    Text(weekday, style: AppTextStyles.bodySm),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: AppSize.touchMin,
                      height: AppSize.touchMin,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? AppColors.primary : Colors.transparent,
                        border: isToday && !isSel ? Border.all(color: AppColors.outline) : null,
                      ),
                      child: Text(
                        '${day.day}',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: isSel
                              ? AppColors.onPrimary
                              : isFuture
                                  ? AppColors.mute
                                  : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasRecord ? AppColors.ink : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 끼니 한 덩어리: 머리말(끼니 + 시각) → 사진 3열 → 캡션 줄 → 트레이너 피드백 ──
class _MealEntry extends StatelessWidget {
  final Meal meal;
  final fb.Feedback? feedback;
  final VoidCallback onDelete;

  const _MealEntry({required this.meal, required this.feedback, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final description = (meal.description ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMonthHeader(
          label: meal.mealType.label,
          count: meal.mealTime,
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.base, AppSpacing.xs, AppSpacing.xs),
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
            child: _MealPhotoGrid(urls: meal.imageUrls, mealLabel: meal.mealType.label),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
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
                    style: AppTextStyles.counter.copyWith(color: AppColors.body),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              meal.hasFeedback ? const AppTag('피드백 완료', strong: true) : const AppTag('검토 대기'),
            ],
          ),
        ),
        if (feedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
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
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(AppIcons.image, size: AppSize.icon, color: AppColors.mute),
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
              AppAvatar(name: name.isEmpty ? '트레이너' : name, seed: feedback.trainerId, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name.isEmpty ? '트레이너' : '$name 트레이너',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(DateFormat('HH:mm').format(feedback.createdAt), style: AppTextStyles.counter.copyWith(color: AppColors.body)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(feedback.content, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}
