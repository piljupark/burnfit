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
import 'trainer_workout_models.dart';

/// 펼쳐진(현재) 운동 블록: 이름(17) + 부위 태그 + 메뉴 → 지난 PT 캡션 → 세트 표.
///
/// 카드로 감싸지 않는다. 위아래 구분은 화면 쪽 hairline이 맡는다.
/// 세트 표: 줄 높이 48, 세트 번호 모노, 값 상자 canvasSoft 36,
/// 완료 = 흰 채운 원 + 굵은 체크, 진행 중 줄 = 흰 테두리, 미완료 = 외곽선 원.
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

  String get _caption => switch (comparison.tone) {
    TrainerComparisonTone.up ||
    TrainerComparisonTone.down => '지난 PT 대비 최고 ${comparison.label}',
    TrainerComparisonTone.same => '지난 PT 최고와 동일',
    TrainerComparisonTone.muted =>
      comparison.label.startsWith('지난')
          ? comparison.label.replaceFirst('지난', '지난 PT')
          : comparison.label,
  };

  @override
  Widget build(BuildContext context) {
    final currentIndex = exercise.sets.indexWhere((s) => !s.done);
    final canRemove = exercise.sets.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 운동 머리 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.base,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
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
                  AppTag(exercise.category.label),
                  if (exercise.unit == TrainerWeightUnit.lbs &&
                      !exercise.isCardio) ...[
                    const SizedBox(width: AppSpacing.xs),
                    AppTag(exercise.unit.label, muted: true),
                  ],
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
              Text(_caption, style: AppTextStyles.bodySm),
            ],
          ),
        ),

        // ── 세트 표 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(
                primary: exercise.primaryMetricLabel,
                secondary: exercise.isCardio
                    ? exercise.secondaryMetricLabel
                    : '회',
              ),
              for (var i = 0; i < exercise.sets.length; i++)
                _SetRow(
                  number: i + 1,
                  set: exercise.sets[i],
                  current: i == currentIndex,
                  primaryLabel: exercise.primaryMetricLabel,
                  secondaryLabel: exercise.secondaryMetricLabel,
                  onChanged: onChanged,
                  onRemove: () => onRemoveSet(i),
                  onToggleDone: () => onToggleSetDone(i),
                ),
              Row(
                children: [
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: AppButton(
                      label: '세트 추가',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      icon: const Icon(AppIcons.add),
                      onPressed: onAddSet,
                    ),
                  ),
                  const Spacer(),
                  Transform.translate(
                    offset: const Offset(12, 0),
                    child: AppButton(
                      label: '세트 삭제',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      icon: const Icon(AppIcons.remove),
                      onPressed: canRemove
                          ? () => onRemoveSet(exercise.sets.length - 1)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const double _setNumberWidth = 32;
const double _doneCellWidth = AppSize.touchMin;

class _HeaderRow extends StatelessWidget {
  final String primary;
  final String secondary;

  const _HeaderRow({required this.primary, required this.secondary});

  Widget _label(String text, {TextAlign align = TextAlign.center}) {
    return Text(
      monoCase(text),
      textAlign: align,
      style: monoOrSans(
        text,
        mono: AppTextStyles.counter,
        sans: AppTextStyles.bodySm.copyWith(fontSize: 11, height: 14 / 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            SizedBox(
              width: _setNumberWidth,
              child: _label('세트', align: TextAlign.start),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _label(primary)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _label(secondary)),
            const SizedBox(width: AppSpacing.sm),
            const SizedBox(width: _doneCellWidth),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int number;
  final TrainerSetDraft set;
  final bool current;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onToggleDone;

  const _SetRow({
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
    final textColor = set.done ? AppColors.body : AppColors.ink;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // 세트 번호: 길게 누르면 이 세트 삭제
          Semantics(
            label: '$number세트',
            onLongPressHint: '이 세트 삭제',
            child: GestureDetector(
              onLongPress: onRemove,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: _setNumberWidth,
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ExcludeSemantics(
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: AppTextStyles.eyebrow.copyWith(
                        letterSpacing: 12 * 0.06,
                        color: current ? AppColors.ink : AppColors.mute,
                      ),
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
              textColor: textColor,
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
              textColor: textColor,
              semanticLabel: '$number세트 $secondaryLabel',
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SetDoneButton(
            number: number,
            done: set.done,
            current: current,
            onTap: onToggleDone,
          ),
        ],
      ),
    );
  }
}

/// 접힌 운동 한 줄의 보조 줄: "4세트 · 완료 2/4 · 40kg".
String trainerExerciseRowSummary(TrainerExerciseDraft exercise) {
  final done = exercise.sets.where((s) => s.done).length;
  final parts = <String>[
    '${exercise.sets.length}세트',
    '완료 $done/${exercise.sets.length}',
  ];
  final max = exercise.maxWeight;
  if (max != null) {
    parts.add(
      '${trainerFormatMetricValue(max)}${exercise.primaryMetricSuffix}',
    );
  }
  return parts.join(' · ');
}
