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
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_text_field.dart';
import 'workout_draft_models.dart';

class ExercisePickerSheet extends StatefulWidget {
  final String memberId;
  final WorkoutCategory defaultCategory;
  final List<CustomExercise> customExercises;
  final Map<String, PreviousExerciseStats> previousStatsByName;
  final void Function(CustomExercise exercise) onCustomAdded;

  const ExercisePickerSheet({
    super.key,
    required this.memberId,
    required this.defaultCategory,
    required this.customExercises,
    required this.previousStatsByName,
    required this.onCustomAdded,
  });

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
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

  List<PickedExercise> get _items {
    final query = _searchController.text.trim().toLowerCase();

    final defaults = <PickedExercise>[];

    for (final entry in ExerciseData.exercises.entries) {
      if (_selectedCategory != null && entry.key != _selectedCategory) continue;

      for (final name in entry.value) {
        defaults.add(PickedExercise(name: name, category: entry.key));
      }
    }

    final customs = widget.customExercises
        .where((exercise) {
          if (_selectedCategory != null &&
              exercise.category != _selectedCategory) {
            return false;
          }
          return true;
        })
        .map(
          (exercise) => PickedExercise(
            name: exercise.name,
            category: exercise.category,
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

    final exact = _items.any((item) => item.name == query);
    return !exact;
  }

  Future<void> _addCustom() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    setState(() => _addingCustom = true);

    try {
      final exercise = await ExerciseService.addCustomExercise(
        memberId: widget.memberId,
        name: name,
        category: _selectedCategory ?? widget.defaultCategory,
      );

      widget.onCustomAdded(exercise);

      if (!mounted) return;

      Navigator.of(context).pop(
        PickedExercise(
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
    final categories = WorkoutCategory.values;
    final selectedChip = _selectedCategory == null
        ? 0
        : categories.indexOf(_selectedCategory!) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppBottomSheetHeader(title: '운동 추가'),
              AppTextField(
                label: '',
                hint: '운동명 검색 또는 직접 입력',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        AppScrollableChips(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          labels: ['전체', ...categories.map((category) => category.label)],
          selectedIndex: selectedChip,
          onSelected: (index) => setState(() {
            _selectedCategory = index == 0 ? null : categories[index - 1];
          }),
        ),
        if (_canAddCustom)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              0,
            ),
            child: AppButton(
              label: '"${_searchController.text.trim()}" 새 운동으로 추가',
              variant: AppButtonVariant.secondary,
              icon: const Icon(AppIcons.add),
              fullWidth: true,
              isLoading: _addingCustom,
              onPressed: _addingCustom ? null : _addCustom,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        const AppRowDivider(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
              bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppColors.hairline,
              indent: AppSpacing.xl,
              endIndent: AppSpacing.xl,
            ),
            itemBuilder: (_, index) {
              final item = items[index];
              final previous = widget.previousStatsByName[item.name];

              return _PickerRow(
                item: item,
                previous: previous,
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
  final PickedExercise item;
  final PreviousExerciseStats? previous;
  final VoidCallback onTap;

  const _PickerRow({
    required this.item,
    required this.previous,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg,
                      ),
                      Text(
                        item.custom
                            ? '${item.category.label} · 직접 추가'
                            : item.category.label,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                if (previous != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '지난 ${formatWeight(previous!.maxWeight)}kg',
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

class ExerciseMenuSheet extends StatelessWidget {
  final WorkoutExerciseDraft exercise;

  const ExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit = exercise.unit == WeightUnit.kg ? 'lbs' : 'kg';

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
          label: '무게 단위 변경',
          value: '${exercise.unit.label} → $nextUnit',
          onTap: () {
            Navigator.of(context).pop(
              const ExerciseMenuAction(type: ExerciseMenuActionType.toggleUnit),
            );
          },
        ),
        const AppRowDivider(),
        AppSheetAction(
          icon: AppIcons.timer,
          label: '휴식 타이머',
          value: '${exercise.restSeconds}초',
          onTap: () async {
            final seconds = await showAppBottomSheet<int>(
              context: context,
              child: RestTimerSheet(initialSeconds: exercise.restSeconds),
            );

            if (seconds == null || !context.mounted) return;

            Navigator.of(context).pop(
              ExerciseMenuAction(
                type: ExerciseMenuActionType.restTimer,
                restSeconds: seconds,
              ),
            );
          },
        ),
        const AppRowDivider(),
        AppSheetAction(
          icon: AppIcons.trash,
          label: '운동 삭제',
          value: null,
          destructive: true,
          onTap: () {
            Navigator.of(context).pop(
              const ExerciseMenuAction(type: ExerciseMenuActionType.delete),
            );
          },
        ),
      ],
    );
  }
}

/// 시트 행동 줄 (높이 52): 아이콘 + 라벨 + 오른쪽 현재 값. 파괴적 행은 danger 글자.

class RestTimerSheet extends StatelessWidget {
  final int initialSeconds;

  const RestTimerSheet({super.key, required this.initialSeconds});

  @override
  Widget build(BuildContext context) {
    final options = [30, 45, 60, 90, 120, 180];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(
          title: '휴식 타이머',
          subtitle: '운동별 기본 휴식 시간을 설정합니다.',
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.4,
          children: [
            for (final seconds in options)
              _RestOption(
                label: '$seconds초',
                selected: seconds == initialSeconds,
                onTap: () => Navigator.of(context).pop(seconds),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// 휴식 시간 선택 pill (높이 44). 선택 = 흰 채움, 나머지 = 외곽선.
class _RestOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RestOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.outline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.buttonLabel.copyWith(
                color: selected ? AppColors.canvas : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
