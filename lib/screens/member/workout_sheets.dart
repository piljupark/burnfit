import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_text_styles.dart';
import '../../core/exercise_data.dart';
import '../../models/custom_exercise.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
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

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Gap(12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '운동 추가',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(14),
                    TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyLarge,
                      cursorColor: AppColors.brand,
                      decoration: InputDecoration(
                        hintText: '운동명 검색 또는 직접 입력',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.brand,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
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
                            (category) => _PickerChip(
                              label: category.label,
                              selected: _selectedCategory == category,
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: GestureDetector(
                    onTap: _addingCustom ? null : _addCustom,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(8),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final previous = widget.previousStatsByName[item.name];

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
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
                                '지난 ${formatWeight(previous.maxWeight)}kg',
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
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand
              : AppColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.brand
                : AppColors.border,
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

class ExerciseMenuSheet extends StatelessWidget {
  final WorkoutExerciseDraft exercise;

  const ExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit = exercise.unit == WeightUnit.kg ? 'lbs' : 'kg';

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Gap(18),
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text(
                  '${exercise.category.label} · 현재 단위 ${exercise.unit.label}',
                  style: AppTextStyles.bodySmall,
                ),
                const Gap(20),
                _ExerciseMenuTile(
                  icon: Icons.swap_horiz_rounded,
                  title: '무게 단위 변경',
                  subtitle: '${exercise.unit.label} → $nextUnit',
                  onTap: () {
                    Navigator.of(context).pop(
                      const ExerciseMenuAction(
                        type: ExerciseMenuActionType.toggleUnit,
                      ),
                    );
                  },
                ),
                const Gap(10),
                _ExerciseMenuTile(
                  icon: Icons.timer_outlined,
                  title: '휴식 타이머',
                  subtitle: '${exercise.restSeconds}초',
                  onTap: () async {
                    final seconds = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          RestTimerSheet(initialSeconds: exercise.restSeconds),
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
                const Gap(10),
                _ExerciseMenuTile(
                  icon: Icons.delete_outline_rounded,
                  title: '운동 삭제',
                  subtitle: '이 운동을 기록에서 제거합니다',
                  danger: true,
                  onTap: () {
                    Navigator.of(context).pop(
                      const ExerciseMenuAction(
                        type: ExerciseMenuActionType.delete,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _ExerciseMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.destructive
        : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
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

class RestTimerSheet extends StatelessWidget {
  final int initialSeconds;

  const RestTimerSheet({super.key, required this.initialSeconds});

  @override
  Widget build(BuildContext context) {
    final options = [30, 45, 60, 90, 120, 180];

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Gap(18),
                Text(
                  '휴식 타이머',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text('운동별 기본 휴식 시간을 설정합니다.', style: AppTextStyles.bodySmall),
                const Gap(20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((seconds) {
                    final selected = seconds == initialSeconds;

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(seconds),
                      child: Container(
                        width: 96,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brand
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.brand
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '$seconds초',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: selected
                                ? AppColors.textOnAccent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
