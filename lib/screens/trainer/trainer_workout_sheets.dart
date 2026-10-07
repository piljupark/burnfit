import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/exercise_data.dart';
import '../../models/custom_exercise.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';
import 'trainer_workout_models.dart';

// ─────────────────────────────────────────────
// Exercise Picker Sheet
// showAppBottomSheet(child: TrainerExercisePickerSheet(...))로 연다.
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
    final listHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: '운동 추가',
          subtitle: '목록에서 고르거나 이름을 직접 입력하세요.',
        ),
        AppTextField(
          label: '',
          hint: '운동명 검색 또는 직접 입력',
          controller: _searchController,
          prefix: const Icon(AppIcons.search),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(
                label: '전체',
                selected: _selectedCategory == null,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              for (final c in WorkoutCategory.values) ...[
                const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: c.label,
                  selected: _selectedCategory == c,
                  onTap: () => setState(() => _selectedCategory = c),
                ),
              ],
            ],
          ),
        ),
        if (_canAddCustom)
          _addingCustom
              ? SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const OrbLoader.inline(semanticLabel: '새 운동 추가 중'),
                      const SizedBox(width: AppSpacing.base),
                      Text('추가 중', style: AppTextStyles.bodyMd),
                    ],
                  ),
                )
              : AppSheetAction(
                  icon: AppIcons.add,
                  label: '"${_searchController.text.trim()}" 새 운동으로 추가',
                  onTap: _addCustom,
                ),
        const SizedBox(height: AppSpacing.sm),
        const AppRowDivider(),
        SizedBox(
          height: listHeight,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const AppRowDivider(),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return _PickerRow(
                      item: item,
                      previous: widget.previousStatsByName[item.name],
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  final TrainerPickedExercise item;
  final TrainerPreviousStats? previous;
  final VoidCallback onTap;

  const _PickerRow({required this.item, required this.previous, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppTextStyles.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        item.custom ? '${item.category.label} · 직접 추가' : item.category.label,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                      ),
                    ],
                  ),
                ),
                if (previous != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '지난 ${trainerFormatWeight(previous!.maxWeight)}kg',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Exercise Menu Sheet
// showAppBottomSheet<TrainerMenuAction>(child: TrainerExerciseMenuSheet(...))로 연다.
// ─────────────────────────────────────────────

class TrainerExerciseMenuSheet extends StatelessWidget {
  final TrainerExerciseDraft exercise;

  const TrainerExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit =
        exercise.unit == TrainerWeightUnit.kg ? 'lbs' : 'kg';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: exercise.name,
          subtitle: '${exercise.category.label} · 현재 단위 ${exercise.unit.label}',
        ),
        AppSheetAction(
          icon: PhosphorIconsLight.arrowsLeftRight,
          label: '무게 단위 변경 (${exercise.unit.label} → $nextUnit)',
          onTap: () => Navigator.of(context).pop(
            const TrainerMenuAction(type: TrainerMenuActionType.toggleUnit),
          ),
        ),
        const AppRowDivider(),
        AppSheetAction(
          icon: AppIcons.trash,
          label: '운동 삭제',
          destructive: true,
          onTap: () => Navigator.of(context).pop(
            const TrainerMenuAction(type: TrainerMenuActionType.delete),
          ),
        ),
      ],
    );
  }
}
