import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/custom_exercise.dart';
import '../../models/workout.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/workout_parts.dart';

/// 저장된 PT 기록 한 건 (시안 Tr-PtRecord-Saved): 좌우 20 안쪽 블록 + 아래 hairline(카드 없음).
/// 위 4 아래 12. 머리: '하체'(14 ink 500) · '총 볼륨 7,520kg · 8세트'(14 mute) + 수정·삭제(44, 아이콘 20 body)
/// → 운동 줄(15/500 이름 · 13 mute '4세트 · 최고 120kg', 위아래 6).
/// 기록에는 부위가 하나만 저장되므로 유산소 여부·볼륨·부위 이름은 종목 이름으로 종목마다 가린다.
class TrainerSavedWorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 직접 추가한 운동 (부위 찾기용)
  final List<CustomExercise> customExercises;

  const TrainerSavedWorkoutCard({
    super.key,
    required this.workout,
    required this.onEdit,
    required this.onDelete,
    this.customExercises = const [],
  });

  bool _isCardio(Exercise exercise) => isCardioExercise(
    exercise.name,
    workout.category,
    customExercises: customExercises,
  );

  @override
  Widget build(BuildContext context) {
    final allCardio =
        workout.exercises.isNotEmpty && workout.exercises.every(_isCardio);
    final volume = workoutStrengthVolumeKg(
      workout,
      customExercises: customExercises,
    );
    final summary = [
      if (!allCardio) '총 볼륨 ${NumberFormat('#,##0').format(volume.round())}kg',
      '${workout.totalSets}세트',
    ].join(' · ');
    final categoryLabel = workout.exercises
        .map(
          (e) =>
              (exerciseCategoryOf(e.name, customExercises: customExercises) ??
                      workout.category)
                  .label,
        )
        .toSet()
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: categoryLabel.isEmpty
                              ? workout.category.label
                              : categoryLabel,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(text: ' · $summary'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.fieldLabel,
                  ),
                ),
                AppIconButton(
                  icon: AppIcons.edit,
                  label: '기록 수정',
                  onPressed: onEdit,
                  color: AppColors.body,
                ),
                // 시안 margin-right −12: 아이콘을 화면 오른쪽 20 선에 맞춘다
                Transform.translate(
                  offset: const Offset(AppSpacing.md, 0),
                  child: AppIconButton(
                    icon: AppIcons.trash,
                    label: '기록 삭제',
                    onPressed: onDelete,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
            for (final exercise in workout.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: WorkoutSavedExerciseRow(
                  exercise: exercise,
                  isCardio: _isCardio(exercise),
                  nameStyle: AppTextStyles.bodyMd.medium.natural,
                  gap: AppSpacing.md,
                  showMax: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
