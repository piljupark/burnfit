import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/set_input.dart';
import 'workout_draft_models.dart';

/// 세트 표 치수 (디자인 시스템 "세트 입력" 패턴).
const double _setRowHeight = 48;
const double _setNumberWidth = 32;

/// 부위 → 모노 태그용 영문 코드 (한글은 모노로 쓰지 않는다).
String workoutCategoryCode(WorkoutCategory category) {
  return switch (category) {
    WorkoutCategory.shoulder => 'SHOULDER',
    WorkoutCategory.chest => 'CHEST',
    WorkoutCategory.back => 'BACK',
    WorkoutCategory.lower => 'LEGS',
    WorkoutCategory.arms => 'ARMS',
    WorkoutCategory.abs => 'CORE',
    WorkoutCategory.cardio => 'CARDIO',
  };
}

/// 진행 중인 운동 한 덩어리: 이름 + 부위 태그 + 메뉴, 지난 기록 캡션,
/// 모노 머리 세트 표(48 높이 줄), "세트 추가" ghost 버튼.
/// 카드로 감싸지 않고 화면 폭에 바로 놓는다 (좌우 16).
class ExerciseInputCard extends StatelessWidget {
  final int order;
  final WorkoutExerciseDraft exercise;
  final ExerciseComparison comparison;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;
  final VoidCallback onMenuTap;
  final void Function(int setIndex) onRemoveSet;
  final void Function(int setIndex) onToggleSetDone;

  const ExerciseInputCard({
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

  String get _comparisonCaption {
    return switch (comparison.tone) {
      ComparisonTone.up || ComparisonTone.down => '지난 기록 대비 ${comparison.label}',
      ComparisonTone.same => '지난 기록과 동일',
      ComparisonTone.muted => comparison.label,
    };
  }

  /// 표 머리: 영문 단위는 모노 대문자, 한글 지표(속도·경사 등)는 sans.
  String _headerLabel(String label) {
    return switch (label) {
      '회' => 'REPS',
      '시간' => 'MIN',
      _ => label,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 진행 중 줄 = 아직 완료하지 않은 첫 세트
    final currentIndex = exercise.sets.indexWhere((set) => !set.done);

    return Semantics(
      container: true,
      label: '$order번째 운동 ${exercise.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.base, AppSpacing.screenH, AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppTag(workoutCategoryCode(exercise.category)),
                    const Spacer(),
                    Transform.translate(
                      offset: const Offset(12, 0),
                      child: AppIconButton(
                        icon: AppIcons.more,
                        label: '${exercise.name} 메뉴',
                        onPressed: onMenuTap,
                      ),
                    ),
                  ],
                ),
                Text(_comparisonCaption, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      const SizedBox(width: _setNumberWidth, child: _HeaderText('SET', align: TextAlign.start)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _HeaderText(_headerLabel(exercise.primaryMetricLabel))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _HeaderText(_headerLabel(exercise.secondaryMetricLabel))),
                      const SizedBox(width: AppSpacing.sm),
                      const SizedBox(width: AppSize.touchMin),
                    ],
                  ),
                ),
                for (var i = 0; i < exercise.sets.length; i++)
                  _WorkoutSetRow(
                    number: i + 1,
                    set: exercise.sets[i],
                    current: i == currentIndex,
                    primaryLabel: exercise.primaryMetricLabel,
                    secondaryLabel: exercise.secondaryMetricLabel,
                    onChanged: onChanged,
                    onRemove: () => onRemoveSet(i),
                    onToggleDone: () => onToggleSetDone(i),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-AppSpacing.md, 0),
                      child: AppButton(
                        label: '세트 추가',
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        icon: const Icon(AppIcons.add),
                        onPressed: onAddSet,
                      ),
                    ),
                    const Spacer(),
                    if (exercise.sets.length > 1)
                      Transform.translate(
                        offset: const Offset(AppSpacing.md, 0),
                        child: AppButton(
                          label: '마지막 세트 삭제',
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          icon: const Icon(AppIcons.remove),
                          onPressed: () => onRemoveSet(exercise.sets.length - 1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _HeaderText(this.label, {this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Text(
      monoCase(label),
      textAlign: align,
      style: monoOrSans(label, mono: AppTextStyles.counter, sans: AppTextStyles.captionSmall),
    );
  }
}

/// 세트 한 줄 (높이 48): 모노 세트 번호 · 값 상자 2개 · 완료 원.
/// 완료 = 흰 채운 원 + 굵은 체크, 진행 중 = 흰 테두리 원 + 값 상자 흰 테두리, 대기 = 외곽선 원.
class _WorkoutSetRow extends StatelessWidget {
  final int number;
  final WorkoutSetDraft set;
  final bool current;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onToggleDone;

  const _WorkoutSetRow({
    required this.number,
    required this.set,
    required this.current,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onChanged,
    required this.onRemove,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final done = set.done;
    final valueColor = done ? AppColors.body : AppColors.ink;

    return SizedBox(
      height: _setRowHeight,
      child: Row(
        children: [
          Semantics(
            label: '$number세트. 길게 눌러 삭제',
            onLongPress: onRemove,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onRemove,
              child: SizedBox(
                width: _setNumberWidth,
                height: _setRowHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    number.toString().padLeft(2, '0'),
                    style: AppTextStyles.counter.copyWith(
                      fontSize: 12,
                      color: done ? AppColors.mute : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SetValueField(
              controller: set.weightController,
              decimal: true,
              highlighted: current,
              textColor: valueColor,
              semanticLabel: '$number세트 $primaryLabel',
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SetValueField(
              controller: set.repsController,
              decimal: false,
              highlighted: current,
              textColor: valueColor,
              semanticLabel: '$number세트 $secondaryLabel',
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SetDoneButton(number: number, done: done, current: current, onTap: onToggleDone),
        ],
      ),
    );
  }
}

