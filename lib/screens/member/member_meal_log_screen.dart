import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/meal.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_section.dart';
import 'meal_input_sheet.dart';

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

  static const _filterLabels = ['전체', '아침', '점심', '저녁', '간식'];

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await MealService.getMealsByDate(
        user.centerId,
        user.uid,
        _dateKey,
      );
      if (!mounted) return;
      setState(() => _meals = list);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
  int get _feedbackDoneCount => _meals.where((e) => e.hasFeedback).length;
  int get _feedbackPendingCount => _meals.where((e) => !e.hasFeedback).length;

  Future<void> _addMeal() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealInputSheet(
          centerId: user.centerId,
          memberId: user.uid,
          memberName: user.name,
          trainerId: user.trainerId,
          selectedDate: _dateKey,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteMeal(Meal meal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        title: Text('식단 삭제', style: AppTextStyles.h4),
        content: Text('이 식단 기록을 삭제할까요?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '취소',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '삭제',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.diet,
        backgroundColor: AppColors.card,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.lg,
                    AppSpacing.screenH,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('식단 기록', style: AppTextStyles.h1),
                                const Gap(AppSpacing.xxs),
                                Text(
                                  DateFormat(
                                    'M월 d일 (E)',
                                    'ko',
                                  ).format(_selectedDate),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _addMeal,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.diet,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: AppColors.textOnAccent,
                                  ),
                                  const Gap(4),
                                  Text(
                                    '추가',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textOnAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.lg),
                      // 주간 캘린더
                      _WeekStrip(
                        selected: _selectedDate,
                        onSelect: (d) {
                          setState(() => _selectedDate = d);
                          _load();
                        },
                      ),
                      const Gap(AppSpacing.md),
                      // 요약 카드
                      _SummaryRow(
                        totalMeals: _meals.length,
                        totalCalories: _totalCalories,
                        feedbackDone: _feedbackDoneCount,
                        feedbackPending: _feedbackPendingCount,
                      ),
                      const Gap(AppSpacing.md),
                      // 필터
                      _FilterBar(
                        labels: _filterLabels,
                        selected: _filterIndex,
                        onSelected: (i) => setState(() => _filterIndex = i),
                      ),
                      const Gap(AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
            // 식단 목록
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: AppSpacing.xl2,
                  ),
                  child: AppEmptyState(
                    icon: Icons.restaurant_outlined,
                    message: '기록된 식단이 없습니다.\n상단 추가 버튼으로 식단을 기록하세요.',
                    actionLabel: '식단 추가',
                    onAction: _addMeal,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  0,
                  AppSpacing.screenH,
                  120,
                ),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (_, i) => _MealCard(
                    meal: _filtered[i],
                    onDelete: () => _deleteMeal(_filtered[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 주간 스트립 (홈 탭과 동일 스타일) ────────────────────────────────────
class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({required this.selected, required this.onSelect});

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: days.map((day) {
          final isSel =
              day.year == selected.year &&
              day.month == selected.month &&
              day.day == selected.day;
          final isToday =
              day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.diet : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdays[day.weekday - 1],
                      style: AppTextStyles.captionSmall.copyWith(
                        color: isSel
                            ? AppColors.textOnAccent.withValues(alpha: 0.7)
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '${day.day}',
                      style: AppTextStyles.body.copyWith(
                        color: isSel
                            ? AppColors.textOnAccent
                            : isToday
                            ? AppColors.diet
                            : AppColors.textPrimary,
                        fontWeight: isSel || isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    if (isToday && !isSel) ...[
                      const Gap(3),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.diet,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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

// ── 요약 행 ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final int totalMeals;
  final int totalCalories;
  final int feedbackDone;
  final int feedbackPending;

  const _SummaryRow({
    required this.totalMeals,
    required this.totalCalories,
    required this.feedbackDone,
    required this.feedbackPending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          icon: Icons.restaurant_outlined,
          label: '식사',
          value: '$totalMeals',
          unit: '건',
        ),
        const Gap(AppSpacing.xs),
        _Chip(
          icon: Icons.local_fire_department_outlined,
          label: '칼로리',
          value: totalCalories > 0 ? '$totalCalories' : '-',
          unit: totalCalories > 0 ? 'kcal' : '',
        ),
        const Gap(AppSpacing.xs),
        _Chip(
          icon: feedbackDone > 0
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_empty_rounded,
          label: '피드백',
          value: feedbackDone > 0 ? '$feedbackDone' : '$feedbackPending',
          unit: feedbackDone > 0 ? '완료' : '대기',
          active: feedbackDone > 0,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool active;

  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? AppColors.diet.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.diet : AppColors.textTertiary,
            ),
            const Gap(6),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: active ? AppColors.diet : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              unit.isNotEmpty ? unit : label,
              style: AppTextStyles.captionSmall.copyWith(
                color: active
                    ? AppColors.diet.withValues(alpha: 0.7)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 필터 바 ───────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const _FilterBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xxs),
        itemBuilder: (_, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.card : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: active
                      ? AppColors.diet.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: AppTextStyles.label.copyWith(
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 식단 카드 ─────────────────────────────────────────────────────────────
class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onDelete;

  const _MealCard({required this.meal, required this.onDelete});

  IconData get _typeIcon => switch (meal.mealType) {
    MealType.breakfast => Icons.wb_sunny_outlined,
    MealType.lunch => Icons.lunch_dining_outlined,
    MealType.dinner => Icons.dinner_dining_outlined,
    MealType.snack => Icons.local_cafe_outlined,
  };

  Color get _typeColor => switch (meal.mealType) {
    MealType.breakfast => const Color(0xFFFF9500),
    MealType.lunch => AppColors.brand,
    MealType.dinner => AppColors.workout,
    MealType.snack => AppColors.diet,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _typeColor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 색상 바
            Container(width: 4, color: accent),
            // 카드 본문
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카드 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Icon(_typeIcon, size: 18, color: accent),
                        ),
                        const Gap(AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.mealType.label,
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              if (meal.mealTime != null)
                                Text(
                                  meal.mealTime!,
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (meal.hasFeedback)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              '피드백 완료',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              '검토 대기',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        const Gap(AppSpacing.xs),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 이미지
                  if (meal.imageUrls.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: meal.imageUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.xs),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: Image.network(
                              meal.imageUrls[i],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // 설명 + 칼로리
                  if ((meal.description ?? '').trim().isNotEmpty ||
                      meal.calories != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Divider(
                        height: AppSpacing.sm,
                        thickness: 0.5,
                        color: AppColors.border,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((meal.description ?? '').trim().isNotEmpty)
                            Text(
                              meal.description!.trim(),
                              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                            ),
                          if (meal.calories != null) ...[
                            if ((meal.description ?? '').trim().isNotEmpty)
                              const Gap(AppSpacing.xxs),
                            Text(
                              '${meal.calories} kcal',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.diet,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else
                    const Gap(AppSpacing.sm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

