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
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            10,
            AppSpacing.screenH,
            _canAddCustom ? 0 : 10,
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: labels[i],
                  selected: i == selectedChip,
                  large: true,
                  onTap: () => setState(() {
                    _selectedCategory = i == 0 ? null : categories[i - 1];
                  }),
                ),
              ],
            ],
          ),
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

/// '"케이블 킥백" 새 운동으로 추가' (시안 Tr-ExercisePicker-Custom): 높이 60,
/// 40 연한 주황 상자(+ 18 noticeText) + 14 + 16/500 글자.
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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.noticeBg,
                  borderRadius: BorderRadius.circular(AppRadius.iconBox),
                ),
                child: loading
                    ? const AppLoader.inline(color: AppColors.noticeText)
                    : const Icon(
                        PhosphorIconsBold.plus,
                        size: 18,
                        color: AppColors.noticeText,
                      ),
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

/// 고르기 목록 한 줄 (시안 Tr-ExercisePicker): 좌우 20 안쪽, 최소 64, 아래 hairline.
/// 이름 16/500 + 부위 13 mute(위 2), 오른쪽 '지난 75kg' 14 body.
class _PickerRow extends StatelessWidget {
  final TrainerPickedExercise item;
  final TrainerPreviousStats? previous;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.listTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.custom
                            ? '${item.category.label} · 직접 추가'
                            : item.category.label,
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                if (previous != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '지난 ${trainerFormatWeight(previous!.maxWeight)}kg',
                    style: AppTextStyles.fieldLabel.copyWith(
                      color: AppColors.body,
                    ),
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
// Exercise Menu Sheet (시안 Tr-ExerciseMenu)
// showAppBottomSheet<TrainerMenuAction>(child: TrainerExerciseMenuSheet(...))로 연다.
// 머리(제목 22 + '하체 · 현재 단위 kg' 14 mute, 아래 12) → 60 행동 줄 둘(파괴적 줄은 맨 아래).
// ─────────────────────────────────────────────

class TrainerExerciseMenuSheet extends StatelessWidget {
  final TrainerExerciseDraft exercise;

  const TrainerExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit = exercise.unit == TrainerWeightUnit.kg ? 'lbs' : 'kg';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: exercise.name,
          subtitle: '${exercise.category.label} · 현재 단위 ${exercise.unit.label}',
          mutedSubtitle: true,
          gap: AppSpacing.md,
        ),
        AppSheetAction(
          icon: PhosphorIconsRegular.arrowsLeftRight,
          label: '무게 단위 변경',
          value: '${exercise.unit.label} → $nextUnit',
          onTap: () => Navigator.of(context).pop(
            const TrainerMenuAction(type: TrainerMenuActionType.toggleUnit),
          ),
        ),
        const AppRowDivider(),
        AppSheetAction(
          icon: AppIcons.trash,
          label: '운동 삭제',
          destructive: true,
          onTap: () => Navigator.of(
            context,
          ).pop(const TrainerMenuAction(type: TrainerMenuActionType.delete)),
        ),
      ],
    );
  }
}
