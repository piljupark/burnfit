import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/exercise_data.dart';
import '../../models/custom_exercise.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import 'trainer_workout_models.dart';

// ─────────────────────────────────────────────
// Exercise Picker Sheet
// ─────────────────────────────────────────────

class TrainerExercisePickerSheet extends StatefulWidget {
  final String trainerId;
  final WorkoutCategory defaultCategory;
  final List<CustomExercise> customExercises;
  final Map<String, TrainerPreviousStats> previousStatsByName;
  final void Function(CustomExercise) onCustomAdded;

  const TrainerExercisePickerSheet({
    super.key,
    required this.trainerId,
    required this.defaultCategory,
    required this.customExercises,
    required this.previousStatsByName,
    required this.onCustomAdded,
  });

  @override
  State<TrainerExercisePickerSheet> createState() =>
      _TrainerExercisePickerSheetState();
}

class _TrainerExercisePickerSheetState
    extends State<TrainerExercisePickerSheet> {
  final _searchController = TextEditingController();
  WorkoutCategory? _selectedCategory;
  bool _addingCustom = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.defaultCategory;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrainerPickedExercise> get _items {
    final query = _searchController.text.trim().toLowerCase();
    final defaults = <TrainerPickedExercise>[];

    for (final entry in ExerciseData.exercises.entries) {
      if (_selectedCategory != null && entry.key != _selectedCategory) continue;
      for (final name in entry.value) {
        defaults.add(TrainerPickedExercise(name: name, category: entry.key));
      }
    }

    final customs = widget.customExercises
        .where(
          (e) => _selectedCategory == null || e.category == _selectedCategory,
        )
        .map(
          (e) => TrainerPickedExercise(
            name: e.name,
            category: e.category,
            custom: true,
          ),
        );

    final all = [...defaults, ...customs];
    if (query.isEmpty) return all;
    return all
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  bool get _canAddCustom {
    final query = _searchController.text.trim();
    if (query.isEmpty) return false;
    return !_items.any((item) => item.name == query);
  }

  Future<void> _addCustom() async {
    if (_addingCustom) return;

    final name = _searchController.text.trim();
    if (name.isEmpty) return;
    setState(() => _addingCustom = true);
    try {
      final exercise = await ExerciseService.addCustomExercise(
        memberId: widget.trainerId,
        name: name,
        category: _selectedCategory ?? widget.defaultCategory,
      );
      widget.onCustomAdded(exercise);
      if (!mounted) return;
      Navigator.of(context).pop(
        TrainerPickedExercise(
          name: exercise.name,
          category: exercise.category,
          custom: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _addingCustom = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xs),
          ),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Gap(AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('운동 추가', style: AppTextStyles.h3),
                    const Gap(AppSpacing.md),
                    TextField(
                      controller: _searchController,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.brand,
                      decoration: InputDecoration(
                        hintText: '운동명 검색 또는 직접 입력',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.itemV,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          borderSide: const BorderSide(
                            color: AppColors.brand,
                            width: 1,
                          ),
                        ),
                        hintStyle: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PickerChip(
                            label: '전체',
                            selected: _selectedCategory == null,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          ...WorkoutCategory.values.map(
                            (c) => _PickerChip(
                              label: c.label,
                              selected: _selectedCategory == c,
                              onTap: () =>
                                  setState(() => _selectedCategory = c),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_canAddCustom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.sm,
                  ),
                  child: GestureDetector(
                    onTap: _addingCustom ? null : _addCustom,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.itemV,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        _addingCustom
                            ? '추가 중...'
                            : '"${_searchController.text.trim()}" 새 운동으로 추가',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final previous = widget.previousStatsByName[item.name];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.itemV,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    item.custom
                                        ? '${item.category.label} · 직접 추가'
                                        : item.category.label,
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (previous != null)
                              Text(
                                '지난 ${trainerFormatWeight(previous.maxWeight)}kg',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected
                ? AppColors.textOnAccent
                : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Exercise Menu Sheet
// ─────────────────────────────────────────────

class TrainerExerciseMenuSheet extends StatelessWidget {
  final TrainerExerciseDraft exercise;

  const TrainerExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit =
        exercise.unit == TrainerWeightUnit.kg ? 'lbs' : 'kg';

    return FractionallySizedBox(
      heightFactor: 0.4,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xs),
          ),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const Gap(AppSpacing.lg),
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  '${exercise.category.label} · 현재 단위 ${exercise.unit.label}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap(AppSpacing.lg),
                _MenuTile(
                  icon: Icons.swap_horiz_rounded,
                  title: '무게 단위 변경',
                  subtitle: '${exercise.unit.label} → $nextUnit',
                  onTap: () => Navigator.of(context).pop(
                    const TrainerMenuAction(
                      type: TrainerMenuActionType.toggleUnit,
                    ),
                  ),
                ),
                const Gap(AppSpacing.sm),
                _MenuTile(
                  icon: Icons.delete_outline_rounded,
                  title: '운동 삭제',
                  subtitle: '이 운동을 기록에서 제거합니다',
                  danger: true,
                  onTap: () => Navigator.of(context).pop(
                    const TrainerMenuAction(
                      type: TrainerMenuActionType.delete,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.destructive : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.itemV,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const Gap(AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(4),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
