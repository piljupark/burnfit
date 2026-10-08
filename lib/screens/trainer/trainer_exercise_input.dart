import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/set_input.dart';
import '../../widgets/workout_parts.dart';
import 'trainer_workout_models.dart';

/// 세트 표 치수 (시안 Tr-PtRecord: 열 40 | 1fr | 1fr | 48, 줄 52, 값 상자 좌우 6).
const double _setRowHeight = 52;
const double _setNumberWidth = 40;
const double _setCheckColumn = 48;
const double _valueGap = 6;

/// 펼쳐진(현재) 운동 카드 (시안 Tr-PtRecord · Tr-PtRecord-Cardio).
/// 회색 카드(반경 20, 좌우 20 바깥 여백, 안쪽 16 16 6) 안에 이름(17/500) + 메뉴(점 셋 20),
/// '부위 · 지난 PT 비교' 한 줄(13 mute, 비교 값은 ink 500), 세트 표(흰 값 상자 40 · 완료 원 36),
/// 아래 '+ 세트 추가' · '− 세트 삭제'(15 body).
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

  /// 부위 · 지난 PT 비교 (시안: '하체 · 지난 PT 대비 최고 +5kg', 값만 ink 500).
  Widget _comparisonLine() {
    final List<InlineSpan> tail = switch (comparison.tone) {
      TrainerComparisonTone.up || TrainerComparisonTone.down => [
        const TextSpan(text: '지난 PT 대비 최고 '),
        TextSpan(
          text: comparison.label,
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w500),
        ),
      ],
      TrainerComparisonTone.same => [const TextSpan(text: '지난 PT 최고와 동일')],
      TrainerComparisonTone.muted => [
        TextSpan(
          text: comparison.label.startsWith('지난')
              ? comparison.label.replaceFirst('지난', '지난 PT')
              : comparison.label,
        ),
      ],
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${exercise.category.label} · '),
          ...tail,
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySm,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 진행 중 줄 = 아직 완료하지 않은 첫 세트
    final currentIndex = exercise.sets.indexWhere((s) => !s.done);
    final canRemove = exercise.sets.length > 1;
    final header = AppTextStyles.captionSmall;

    return Semantics(
      container: true,
      label: '$order번째 운동 ${exercise.name}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          6,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 운동 머리 (좌우 4) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.section,
                        ),
                        const SizedBox(height: 3),
                        _comparisonLine(),
                      ],
                    ),
                  ),
                  // 메뉴: 터치 44 단추. 점 셋은 시안처럼 카드 안쪽 오른쪽 끝(margin-right −4)에 맞추고
                  // 예전 44×36 칸의 가운데 높이(18)를 지킨다.
                  Transform.translate(
                    offset: const Offset(
                      AppSpacing.xs + (AppSize.touchMin - AppSize.icon) / 2,
                      -(AppSize.touchMin - 36) / 2,
                    ),
                    child: AppIconButton(
                      icon: AppIcons.moreBold,
                      label: '${exercise.name} 메뉴',
                      color: AppColors.dots,
                      onPressed: onMenuTap,
                    ),
                  ),
                ],
              ),
            ),

            // ── 표 머리 (12 mute, 위 12 아래 6) ──
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                  6,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _setNumberWidth,
                      child: Text('세트', style: header),
                    ),
                    Expanded(
                      child: Text(
                        exercise.primaryMetricLabel,
                        textAlign: TextAlign.center,
                        style: header,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        exercise.secondaryMetricLabel,
                        textAlign: TextAlign.center,
                        style: header,
                      ),
                    ),
                    const SizedBox(width: _setCheckColumn),
                  ],
                ),
              ),
            ),

            for (var i = 0; i < exercise.sets.length; i++)
              _SetRow(
                // 중간 세트를 지워도 아래 세트의 상태(완료 원 움직임·입력 칸)가 밀리지 않게
                key: ObjectKey(exercise.sets[i]),
                number: i + 1,
                set: exercise.sets[i],
                current: i == currentIndex,
                primaryLabel: exercise.primaryMetricLabel,
                secondaryLabel: exercise.secondaryMetricLabel,
                onChanged: onChanged,
                onRemove: () => onRemoveSet(i),
                onToggleDone: () => onToggleSetDone(i),
              ),

            // ── 세트 추가 · 세트 삭제 (위 2) ──
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SetTextButton(
                  icon: AppIcons.bold(AppIcons.add),
                  label: '세트 추가',
                  onTap: onAddSet,
                ),
                _SetTextButton(
                  icon: AppIcons.bold(AppIcons.remove),
                  label: '세트 삭제',
                  onTap: canRemove
                      ? () => onRemoveSet(exercise.sets.length - 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 아래 글자 단추: 높이 44 · 좌우 6 · 아이콘 16 + 6 + 15 body.
class _SetTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SetTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.field),
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            height: AppSize.touchMin,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 시안 선 2/24 → 16에서 1.33: Bold(1.5)가 가깝다
                Icon(icon, size: 16, color: AppColors.body),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 세트 한 줄 (52, 좌우 4): 번호 '01'(15/500, 진행 중 ink · 그 외 mute) · 흰 값 상자 2개
/// (진행 중 줄은 1.5 ink 테두리, 완료 줄 글자 body) · 36 완료 원.
/// 세트 번호를 길게 누르면 그 세트를 지운다.
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
    super.key,
    required this.number,
    required this.set,
    required this.current,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onChanged,
    required this.onRemove,
    required this.onToggleDone,
  });

  Widget _value(TextEditingController controller, bool decimal, String label) {
    final field = SetValueField(
      controller: controller,
      decimal: decimal,
      highlighted: current,
      card: true,
      bold: false,
      outlineHighlighted: true,
      textColor: set.done ? AppColors.body : AppColors.ink,
      semanticLabel: '$number세트 $label',
      onChanged: onChanged,
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _valueGap),
        child: field,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _setRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Semantics(
              label: '$number세트. 길게 눌러 삭제',
              onLongPress: onRemove,
              excludeSemantics: true,
              child: GestureDetector(
                onLongPress: onRemove,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: _setNumberWidth,
                  height: _setRowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: AppTextStyles.bodyMd.medium.copyWith(
                        color: current ? AppColors.ink : AppColors.mute,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _value(set.weightController, true, primaryLabel),
            _value(set.repsController, false, secondaryLabel),
            SizedBox(
              width: _setCheckColumn,
              child: Align(
                alignment: Alignment.centerRight,
                // 터치 칸(44) 안 36 원을 열 오른쪽 끝에 붙인다 (시안 justify-content:flex-end)
                child: Transform.translate(
                  offset: const Offset(4, 0),
                  child: SetDoneButton(
                    number: number,
                    done: set.done,
                    current: current,
                    size: 36,
                    animate: true,
                    onTap: onToggleDone,
                  ),
                ),
              ),
            ),
          ],
        ),
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
    parts.add('${formatMetricValue(max)}${exercise.primaryMetricSuffix}');
  }
  return parts.join(' · ');
}
