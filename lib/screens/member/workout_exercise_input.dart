import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../widgets/set_input.dart';
import 'workout_draft_models.dart';

/// 세트 표 치수 (시안 Main 계열 Workout: 열 40 | 1fr | 1fr | 48, 줄 52).
const double _setRowHeight = 52;
const double _setNumberWidth = 40;
const double _setCheckColumn = 48;

/// 진행 중인 운동 카드 (시안 Workout): 회색 카드(반경 20, 좌우 20 여백) 안에
/// 이름(17/700) + 메뉴, 지난 기록 비교 한 줄, 세트 표(흰 값 상자 · 36 완료 원), '+ 세트 추가'.
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

  /// 부위 · 지난 기록 비교 한 줄 (시안 MemA-Workout-Recording: 13 mute, 위 3).
  /// 늘었으면 비교 부분만 강조색 500.
  Widget _comparisonLine() {
    final text = switch (comparison.tone) {
      ComparisonTone.up ||
      ComparisonTone.down => '지난 기록 대비 ${comparison.label}',
      ComparisonTone.same => '지난 기록과 동일',
      ComparisonTone.muted => comparison.label,
    };
    final up = comparison.tone == ComparisonTone.up;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${exercise.category.label} · '),
          TextSpan(
            text: text,
            style: up
                ? TextStyle(
                    color: AppColors.noticeText,
                    fontWeight: FontWeight.w500,
                  )
                : null,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySm,
    );
  }

  /// 표 머리: 단위만 있는 칸은 그대로(kg·lbs·회), 유산소 시간은 '분'.
  String _headerLabel(String label) => label == '시간' ? '분' : label;

  @override
  Widget build(BuildContext context) {
    // 진행 중 줄 = 아직 완료하지 않은 첫 세트
    final currentIndex = exercise.sets.indexWhere((set) => !set.done);
    final header = AppTextStyles.captionSmall.copyWith(
      color: AppColors.caption,
    );

    return Semantics(
      container: true,
      label: '$order번째 운동 ${exercise.name}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          18,
          AppSpacing.base,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이름 줄 높이 32 (시안: 메뉴 단추 44×32)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.section.bold,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: '${exercise.name} 메뉴',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: onMenuTap,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: AppSize.touchMin,
                          height: 32,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              AppIcons.moreBold,
                              size: AppSize.icon,
                              color: AppColors.dots,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                3,
                AppSpacing.xs,
                0,
              ),
              child: _comparisonLine(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                10,
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
                      _headerLabel(exercise.primaryMetricLabel),
                      textAlign: TextAlign.center,
                      style: header,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _headerLabel(exercise.secondaryMetricLabel),
                      textAlign: TextAlign.center,
                      style: header,
                    ),
                  ),
                  const SizedBox(width: _setCheckColumn),
                ],
              ),
            ),
            for (var i = 0; i < exercise.sets.length; i++)
              _WorkoutSetRow(
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
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              button: true,
              label: '세트 추가',
              excludeSemantics: true,
              child: InkWell(
                onTap: onAddSet,
                borderRadius: BorderRadius.circular(AppRadius.field),
                highlightColor: AppColors.canvasSoft,
                splashFactory: NoSplash.splashFactory,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 시안 선 2/24 → 16에서 1.33: Bold(1.5)가 가깝다
                      Icon(
                        AppIcons.bold(AppIcons.add),
                        size: 16,
                        color: AppColors.body,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '세트 추가',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
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

/// 세트 한 줄 (52): 세트 번호(15/700 body) · 흰 값 상자 2개 · 36 완료 원.
/// 세트 번호를 길게 누르면 그 세트를 지운다.
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
                behavior: HitTestBehavior.opaque,
                onLongPress: onRemove,
                child: SizedBox(
                  width: _setNumberWidth,
                  height: _setRowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$number',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SetValueField(
                  controller: set.weightController,
                  decimal: true,
                  highlighted: current,
                  card: true,
                  semanticLabel: '$number세트 $primaryLabel',
                  onChanged: onChanged,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SetValueField(
                  controller: set.repsController,
                  decimal: false,
                  highlighted: current,
                  card: true,
                  semanticLabel: '$number세트 $secondaryLabel',
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: _setCheckColumn,
              child: Align(
                alignment: Alignment.centerRight,
                child: SetDoneButton(
                  number: number,
                  done: set.done,
                  current: false,
                  size: 36,
                  animate: true,
                  onTap: onToggleDone,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
