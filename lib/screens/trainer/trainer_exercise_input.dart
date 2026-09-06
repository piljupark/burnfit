import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import 'trainer_workout_models.dart';

class TrainerExerciseInputCard extends StatelessWidget {
  final int order;
  final TrainerExerciseDraft exercise;
  final TrainerExerciseComparison comparison;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;
  final VoidCallback onMenuTap;
  final void Function(int) onRemoveSet;
  final void Function(int) onToggleSetDone;

  const TrainerExerciseInputCard({
    super.key,
    required this.order,
    required this.exercise,
    required this.comparison,
    required this.onChanged,
    required this.onAddSet,
    required this.onMenuTap,
    required this.onRemoveSet,
    required this.onToggleSetDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$order',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.brand,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${exercise.category.label} | ${exercise.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ComparisonPill(comparison: comparison),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onMenuTap,
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(16),
          Container(height: 1, color: AppColors.border),
          const Gap(14),
          Row(
            children: [
              const Expanded(child: _HeaderCell(label: '회차')),
              const SizedBox(width: trainerCellGap),
              Expanded(child: _HeaderCell(label: exercise.primaryMetricLabel)),
              const SizedBox(width: trainerCellGap),
              Expanded(
                child: _HeaderCell(label: exercise.secondaryMetricLabel),
              ),
              const SizedBox(width: trainerCellGap),
              const Expanded(child: _HeaderCell(label: '완료')),
            ],
          ),
          const Gap(10),
          ...exercise.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SetRow(
                number: index + 1,
                set: set,
                onChanged: onChanged,
                onRemove: () => onRemoveSet(index),
                onToggleDone: () => onToggleSetDone(index),
              ),
            );
          }),
          const Gap(6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: exercise.sets.length > 1
                      ? () => onRemoveSet(exercise.sets.length - 1)
                      : null,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '— 세트삭제',
                      style: AppTextStyles.body.copyWith(
                        color: exercise.sets.length > 1
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: onAddSet,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '+ 세트추가',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int number;
  final TrainerSetDraft set;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onToggleDone;

  const _SetRow({
    required this.number,
    required this.set,
    required this.onChanged,
    required this.onRemove,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: trainerCellHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: onRemove,
              child: _InputBox(
                child: Text(
                  '$number',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 25,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: trainerCellGap),
          Expanded(
            child: _NumberField(
              controller: set.weightController,
              decimal: true,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: trainerCellGap),
          Expanded(
            child: _NumberField(
              controller: set.repsController,
              decimal: false,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: trainerCellGap),
          Expanded(
            child: GestureDetector(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: set.done ? AppColors.brand : AppColors.bg,
                  borderRadius: BorderRadius.circular(trainerCellRadius),
                  border: Border.all(
                    color: set.done ? AppColors.brand : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: set.done ? AppColors.bg : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final Widget child;

  const _InputBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: trainerCellHeight,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(trainerCellRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool decimal;
  final VoidCallback onChanged;

  const _NumberField({
    required this.controller,
    required this.decimal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _InputBox(
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: Center(
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d*'),
                ),
              ],
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: AppTextStyles.h2.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.0,
              ),
              strutStyle: const StrutStyle(
                fontSize: 25,
                height: 1.0,
                forceStrutHeight: true,
              ),
              cursorColor: AppColors.brand,
              cursorHeight: 25,
              decoration: const InputDecoration(
                filled: false,
                isCollapsed: true,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonPill extends StatelessWidget {
  final TrainerExerciseComparison comparison;

  const _ComparisonPill({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final color = switch (comparison.tone) {
      TrainerComparisonTone.up => AppColors.workout,
      TrainerComparisonTone.down => AppColors.destructive,
      TrainerComparisonTone.same => AppColors.brand,
      TrainerComparisonTone.muted => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        comparison.label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
