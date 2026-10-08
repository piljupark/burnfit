import 'package:flutter/material.dart';

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
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_icon_box.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/workout_parts.dart';
import 'trainer_workout_models.dart';

// ─────────────────────────────────────────────
// Exercise Picker Sheet (시안 Tr-ExercisePicker · Tr-ExercisePicker-Custom)
// showAppBottomSheet(heightFactor: 0.91, padded: false, child: TrainerExercisePickerSheet(...))로 연다.
// 머리(22 제목 + 14 mute 보조 줄) · 검색창 · 큰 칩 줄(위아래 12) · 시트 폭 구분선 · 목록.
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

  /// 같은 이름(대소문자 무시)이 기본 운동·직접 추가한 운동의 어느 부위에도 없을 때만 새로 추가한다.
  bool get _canAddCustom {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return false;
    final defaults = ExerciseData.exercises.values.expand((names) => names);
    final customs = widget.customExercises.map((e) => e.name);
    return ![
      ...defaults,
      ...customs,
    ].any((name) => name.trim().toLowerCase() == query);
  }

  Future<void> _addCustom() async {
    if (_addingCustom) return;

    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    // '전체'에서는 어느 부위로 넣을지 알 수 없으므로 부위를 먼저 고르게 한다.
    final category = _selectedCategory;
    if (category == null) {
      AppFeedback.showWarning(context, '부위를 먼저 고른 뒤 새 운동으로 추가하세요.');
      return;
    }

    setState(() => _addingCustom = true);
    try {
      final exercise = await ExerciseService.addCustomExercise(
        memberId: widget.trainerId,
        name: name,
        category: category,
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
    final categories = WorkoutCategory.values;
    final selectedChip = _selectedCategory == null
        ? 0
        : categories.indexOf(_selectedCategory!) + 1;
    final labels = ['전체', ...categories.map((c) => c.label)];
    final hasQuery = _searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppBottomSheetHeader(
                title: '운동 추가',
                subtitle: '목록에서 고르거나 이름을 직접 입력하세요.',
                mutedSubtitle: true,
                gap: 14,
              ),
              AppTextField(
                label: '',
                hint: '운동명 검색 또는 직접 입력',
                controller: _searchController,
                prefix: Icon(
                  AppIcons.search,
                  color: hasQuery ? AppColors.ink : AppColors.mute,
                ),
                textInputAction: TextInputAction.search,
              ),
            ],
          ),
        ),
        // 칩 줄: 위아래 12 (큰 칩은 위아래 2 터치 여백을 스스로 둔다)
        AppScrollableChips(
          labels: labels,
          selectedIndex: selectedChip,
          large: true,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            10,
            AppSpacing.screenH,
            _canAddCustom ? 0 : 10,
          ),
          onSelected: (i) => setState(() {
            _selectedCategory = i == 0 ? null : categories[i - 1];
          }),
        ),
        if (_canAddCustom)
          // 시안 `drop`: 위 6에서 내려오며 나타남 (.3s)
          AppEntrance(
            key: const ValueKey('custom-add'),
            offset: const Offset(0, -6),
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: _CustomAddRow(
                label: '"${_searchController.text.trim()}" 새 운동으로 추가',
                loading: _addingCustom,
                onTap: _addingCustom ? null : _addCustom,
              ),
            ),
          ),
        const AppRowDivider(),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  // 시안: 남은 칸 가운데에서 위로 (아래 120)
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Center(
                    child: Text(
                      '검색 결과가 없습니다.',
                      style: AppTextStyles.fieldLabel.copyWith(
                        color: AppColors.body,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    bottom:
                        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final previous = widget.previousStatsByName[item.name];
                    return WorkoutPickerRow(
                      name: item.name,
                      category: item.category,
                      custom: item.custom,
                      previous: previous == null
                          ? null
                          : previousRecordLabel(
                              name: item.name,
                              isCardio: item.category == WorkoutCategory.cardio,
                              maxValue: previous.maxWeight,
                            ),
                      onTap: () => Navigator.of(context).pop(item),
                      minHeight: 64,
                      subtitleColor: AppColors.mute,
                      previousStyle: AppTextStyles.fieldLabel.copyWith(
                        color: AppColors.body,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// '"케이블 킥백" 새 운동으로 추가' (시안 Tr-ExercisePicker-Custom): 높이 60,
/// 40 연한 주황 아이콘 상자(+ noticeText) + 14 + 16/500 글자.
class _CustomAddRow extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _CustomAddRow({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: loading ? '새 운동 추가 중' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              if (loading)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.noticeBg,
                    borderRadius: BorderRadius.circular(AppRadius.iconBox),
                  ),
                  child: const AppLoader.inline(color: AppColors.noticeText),
                )
              else
                const AppIconBox(
                  icon: AppIcons.add,
                  background: AppColors.noticeBg,
                  iconColor: AppColors.noticeText,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.listTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Exercise Menu Sheet (시안 Tr-ExerciseMenu)
// showAppBottomSheet<TrainerMenuAction>(child: TrainerExerciseMenuSheet(...))로 연다.
// 머리(제목 22 + '하체 · 현재 단위 kg' 14 mute, 아래 12) → 60 행동 줄 둘(파괴적 줄은 맨 아래).
// 유산소 종목은 '무게 단위 변경'을 두지 않는다. 모양은 [WorkoutExerciseMenuSheet].
// ─────────────────────────────────────────────

class TrainerExerciseMenuSheet extends StatelessWidget {
  final TrainerExerciseDraft exercise;

  const TrainerExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return WorkoutExerciseMenuSheet(
      name: exercise.name,
      category: exercise.category,
      isCardio: exercise.isCardio,
      unitLabel: exercise.unit.label,
      nextUnitLabel: exercise.unit == TrainerWeightUnit.kg ? 'lbs' : 'kg',
      onToggleUnit: () => Navigator.of(
        context,
      ).pop(const TrainerMenuAction(type: TrainerMenuActionType.toggleUnit)),
      onDelete: () => Navigator.of(
        context,
      ).pop(const TrainerMenuAction(type: TrainerMenuActionType.delete)),
    );
  }
}
