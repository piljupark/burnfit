import '../../core/app_logger.dart';
import '../../core/workout_timing.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/workout_draft_service.dart';
import '../../services/workout_reminder.dart';
import '../../services/workout_service.dart';
import 'workout_draft_models.dart';

/// 임시저장 하나를 저장할 내용으로 바꾼 것.
class AutoSavePlan {
  final WorkoutCategory category;
  final List<Exercise> exercises;
  final String? note;
  final int durationSeconds;

  const AutoSavePlan({
    required this.category,
    required this.exercises,
    required this.note,
    required this.durationSeconds,
  });

  /// 끝난 운동으로 볼 만큼 오래된 임시저장이면 완료한 세트만 담아 돌려준다.
  /// 저장할 것이 없거나(완료 세트 없음) 아직 진행 중일 수 있으면 null.
  static AutoSavePlan? fromDraft(Map<String, dynamic> draft, DateTime now) {
    if (!shouldAutoSaveDraft(draft, now)) return null;

    final drafts = <WorkoutExerciseDraft>[];
    final raw = draft['exercises'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          drafts.add(
            WorkoutExerciseDraft.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    try {
      final exercises = <Exercise>[];
      WorkoutCategory? category;
      for (final d in drafts) {
        final exercise = d.toExercise(doneOnly: true);
        if (exercise == null) continue;
        exercises.add(exercise);
        category ??= d.category;
      }
      if (exercises.isEmpty || category == null) return null;

      final lastSetAt = draftTime(draft, draftLastSetAtKey)!;
      final startedAt = draftTime(draft, draftStartedAtKey) ?? lastSetAt;
      final note = (draft['note'] as String? ?? '').trim();
      return AutoSavePlan(
        category: category,
        exercises: exercises,
        note: note.isEmpty ? null : note,
        // 앱을 닫고 나간 시간은 빼고, 마지막 세트를 완료한 때까지만 센다.
        durationSeconds: workoutDurationSeconds(startedAt, lastSetAt),
      );
    } finally {
      for (final d in drafts) {
        d.dispose();
      }
    }
  }
}

/// 앱을 닫아 '운동 마치기'를 못 누른 개인 운동을 다음에 앱을 열 때 저장한다.
///
/// 회원 운동 화면이 임시저장을 되살리기 전에 부른다 (같은 운동이 두 번 저장되지 않게,
/// 저장한 임시저장은 바로 지운다). 저장한 운동 수와 마지막 운동 시간을 돌려준다.
class WorkoutAutoSave {
  WorkoutAutoSave._();

  static Future<({int count, int lastDurationSeconds})> run(
    AppUser member,
  ) async {
    var count = 0;
    var lastDuration = 0;
    final drafts = await WorkoutDraftService.loadAllFor(
      memberId: member.uid,
      workoutType: WorkoutType.personal.name,
    );
    final now = DateTime.now();
    for (final entry in drafts.entries) {
      final plan = AutoSavePlan.fromDraft(entry.value, now);
      if (plan == null) continue;
      try {
        await WorkoutService.saveWorkout(
          centerId: member.centerId,
          memberId: member.uid,
          memberName: member.name,
          trainerId: member.trainerId,
          workoutType: WorkoutType.personal,
          createdById: member.uid,
          createdByRole: WorkoutCreatedByRole.member,
          workoutDate: entry.key,
          category: plan.category,
          exercises: plan.exercises,
          note: plan.note,
          durationSeconds: plan.durationSeconds,
        );
        await WorkoutDraftService.clearDraft(
          memberId: member.uid,
          workoutDate: entry.key,
          workoutType: WorkoutType.personal.name,
        );
        count++;
        lastDuration = plan.durationSeconds;
      } catch (e) {
        // 저장하지 못하면 임시저장을 그대로 두고 다음에 다시 시도한다.
        AppLogger.debug('[WorkoutAutoSave] ${entry.key} 저장 실패: $e');
      }
    }
    if (count > 0) await WorkoutReminder.cancel();
    return (count: count, lastDurationSeconds: lastDuration);
  }
}
