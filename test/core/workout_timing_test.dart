import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/workout_timing.dart';
import 'package:pt_solution_v2/models/workout.dart';
import 'package:pt_solution_v2/screens/member/workout_auto_save.dart';

Map<String, dynamic> _draft({
  DateTime? startedAt,
  DateTime? lastSetAt,
  String? editingWorkoutId,
  List<Map<String, dynamic>>? exercises,
  String note = '',
}) => {
  'editingWorkoutId': editingWorkoutId,
  'note': note,
  'exercises':
      exercises ??
      [
        {
          'name': '사이드 레터럴 레이즈',
          'category': 'shoulder',
          'unit': 'kg',
          'sets': [
            {'weight': '10', 'reps': '12', 'done': true},
            {'weight': '10', 'reps': '10', 'done': true},
            {'weight': '10', 'reps': '8', 'done': false},
          ],
        },
        {
          'name': '덤벨 숄더프레스',
          'category': 'shoulder',
          'unit': 'kg',
          'sets': [
            {'weight': '16', 'reps': '10', 'done': false},
          ],
        },
      ],
  draftStartedAtKey: startedAt?.toIso8601String(),
  draftLastSetAtKey: lastSetAt?.toIso8601String(),
};

void main() {
  final start = DateTime(2026, 10, 10, 19, 0);

  group('운동 시간 계산', () {
    test('두 시각 사이 초, 거꾸로면 0, 10시간 넘으면 10시간', () {
      expect(
        workoutDurationSeconds(start, start.add(const Duration(minutes: 48))),
        48 * 60,
      );
      expect(workoutDurationSeconds(start, start), 0);
      expect(
        workoutDurationSeconds(start, start.subtract(const Duration(hours: 1))),
        0,
      );
      expect(
        workoutDurationSeconds(start, start.add(const Duration(hours: 30))),
        workoutDurationMaxMinutes * 60,
      );
    });

    test('표시: 0이면 없음, 1분 미만, 분, 시간', () {
      expect(formatWorkoutDuration(0), isNull);
      expect(formatWorkoutDuration(40), '1분 미만');
      expect(formatWorkoutDuration(48 * 60 + 30), '48분');
      expect(formatWorkoutDuration(60 * 60), '1시간');
      expect(formatWorkoutDuration(72 * 60), '1시간 12분');
    });
  });

  group('앱을 열 때 자동 저장', () {
    final lastSet = start.add(const Duration(minutes: 40));

    test('마지막 세트 뒤 60분이 지나야 저장한다', () {
      final draft = _draft(startedAt: start, lastSetAt: lastSet);
      expect(
        shouldAutoSaveDraft(draft, lastSet.add(const Duration(minutes: 59))),
        isFalse,
      );
      expect(
        shouldAutoSaveDraft(draft, lastSet.add(const Duration(minutes: 60))),
        isTrue,
      );
    });

    test('세트를 완료한 적이 없거나 저장한 기록을 고치던 중이면 저장하지 않는다', () {
      final later = lastSet.add(const Duration(hours: 3));
      expect(shouldAutoSaveDraft(_draft(startedAt: start), later), isFalse);
      expect(
        shouldAutoSaveDraft(
          _draft(startedAt: start, lastSetAt: lastSet, editingWorkoutId: 'w1'),
          later,
        ),
        isFalse,
      );
    });

    test('완료한 세트만 담고, 시간은 시작 → 마지막 세트 완료까지', () {
      final plan = AutoSavePlan.fromDraft(
        _draft(startedAt: start, lastSetAt: lastSet, note: ' 어깨 좋았음 '),
        lastSet.add(const Duration(hours: 5)),
      );
      expect(plan, isNotNull);
      expect(plan!.exercises, hasLength(1));
      expect(plan.exercises.single.name, '사이드 레터럴 레이즈');
      expect(plan.exercises.single.sets.map((s) => s.reps), [12, 10]);
      expect(plan.category, WorkoutCategory.shoulder);
      expect(plan.note, '어깨 좋았음');
      // 앱을 닫고 지난 5시간은 세지 않는다
      expect(plan.durationSeconds, 40 * 60);
    });

    test('완료한 세트가 하나도 없으면 저장할 것이 없다', () {
      final plan = AutoSavePlan.fromDraft(
        _draft(
          startedAt: start,
          lastSetAt: lastSet,
          exercises: [
            {
              'name': '덤벨 숄더프레스',
              'category': 'shoulder',
              'sets': [
                {'weight': '16', 'reps': '10', 'done': false},
              ],
            },
          ],
        ),
        lastSet.add(const Duration(hours: 2)),
      );
      expect(plan, isNull);
    });
  });
}
