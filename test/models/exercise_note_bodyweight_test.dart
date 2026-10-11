import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/exercise_data.dart';
import 'package:pt_solution_v2/models/workout.dart';
import 'package:pt_solution_v2/screens/member/workout_draft_models.dart';
import 'package:pt_solution_v2/screens/trainer/trainer_workout_models.dart';
import 'package:pt_solution_v2/widgets/workout_parts.dart';

void main() {
  group('종목 메모', () {
    test('메모가 있으면 저장했다가 그대로 읽는다', () {
      const exercise = Exercise(
        name: '바벨 스쿼트',
        sets: [ExerciseSet(weight: 100, reps: 5)],
        note: ' 무릎이 안으로 모임 ',
      );
      final map = exercise.toMap();
      expect(map['note'], '무릎이 안으로 모임');
      expect(Exercise.fromMap(map).note, '무릎이 안으로 모임');
    });

    test('메모가 없는 예전 기록도 읽히고, 빈 메모는 저장하지 않는다', () {
      final old = Exercise.fromMap({
        'name': '바벨 스쿼트',
        'sets': [
          {'weight': 100, 'reps': 5},
        ],
      });
      expect(old.note, isNull);
      const blank = Exercise(
        name: '바벨 스쿼트',
        sets: [ExerciseSet(weight: 100, reps: 5)],
        note: '   ',
      );
      expect(blank.toMap().containsKey('note'), isFalse);
    });

    test('회원 운동 초안의 메모가 저장할 종목에 담긴다', () {
      final draft = WorkoutExerciseDraft(
        name: '바벨 벤치프레스',
        category: WorkoutCategory.chest,
        sets: [WorkoutSetDraft(weight: '60', reps: '10', done: true)],
        note: '어깨 고정',
      );
      expect(draft.toExercise()!.note, '어깨 고정');
      // 앱을 닫았다 열어도 (임시 저장) 메모가 남는다
      expect(WorkoutExerciseDraft.fromMap(draft.toMap()).note, '어깨 고정');
    });
  });

  group('맨몸 운동', () {
    test('맨몸 운동은 무게 칸을 숨기고, 숨긴 무게는 0kg으로 저장한다', () {
      final draft = WorkoutExerciseDraft(
        name: '푸시업',
        category: WorkoutCategory.chest,
        sets: [WorkoutSetDraft(weight: '20', reps: '15', done: true)],
      );
      expect(draft.showWeight, isFalse);
      expect(draft.toExercise()!.sets.single.weight, 0);
      expect(draft.totalVolume, 0);
    });

    test('메뉴로 무게 칸을 켜면 적은 무게를 저장한다 (중량 조끼 등)', () {
      final draft = WorkoutExerciseDraft(
        name: '풀업',
        category: WorkoutCategory.back,
        sets: [WorkoutSetDraft(weight: '10', reps: '8', done: true)],
      )..showWeight = true;
      expect(draft.toExercise()!.sets.single.weight, 10);
      // 켠 상태는 임시 저장에도 남는다
      expect(WorkoutExerciseDraft.fromMap(draft.toMap()).showWeight, isTrue);
    });

    test('무게를 적어 둔 맨몸 기록을 고치러 열면 무게 칸이 보인다', () {
      final withWeight = TrainerExerciseDraft.fromExercise(
        exercise: const Exercise(
          name: '딥스',
          sets: [ExerciseSet(weight: 15, reps: 8)],
        ),
        category: WorkoutCategory.chest,
      );
      final without = TrainerExerciseDraft.fromExercise(
        exercise: const Exercise(
          name: '딥스',
          sets: [ExerciseSet(weight: 0, reps: 12)],
        ),
        category: WorkoutCategory.chest,
      );
      expect(withWeight.showWeight, isTrue);
      expect(without.showWeight, isFalse);
    });

    test('기구 운동과 유산소는 무게(지표) 칸을 늘 보인다', () {
      final bench = WorkoutExerciseDraft(
        name: '바벨 벤치프레스',
        category: WorkoutCategory.chest,
        sets: [WorkoutSetDraft()],
      );
      final run = WorkoutExerciseDraft(
        name: '러닝머신',
        category: WorkoutCategory.cardio,
        sets: [WorkoutSetDraft()],
        showWeight: false,
      );
      expect(bench.showWeight, isTrue);
      expect(run.showWeight, isTrue);
    });

    test('버티는 운동은 횟수 대신 초', () {
      expect(strengthCountLabel('플랭크'), '초');
      expect(strengthCountLabel('푸시업'), '회');
      final plank = WorkoutExerciseDraft(
        name: '플랭크',
        category: WorkoutCategory.abs,
        sets: [WorkoutSetDraft()],
      );
      expect(plank.secondaryMetricLabel, '초');
    });
  });

  group('기본 운동 목록', () {
    test('한 이름은 한 부위에만 있다', () {
      final all = ExerciseData.getAll();
      expect(all.toSet().length, all.length);
    });

    test('맨몸 · 버티기 목록의 이름은 모두 기본 목록에 있다', () {
      final all = ExerciseData.getAll().toSet();
      expect(ExerciseData.bodyweight.difference(all), isEmpty);
      expect(ExerciseData.timed.difference(all), isEmpty);
      expect(ExerciseData.timed.difference(ExerciseData.bodyweight), isEmpty);
    });

    test('예전 기록의 부위 찾기는 그대로다', () {
      expect(exerciseCategoryOf('딥스'), WorkoutCategory.chest);
      expect(exerciseCategoryOf('클로즈그립 벤치프레스'), WorkoutCategory.chest);
      expect(exerciseCategoryOf('버피'), WorkoutCategory.abs);
      expect(exerciseCategoryOf('러닝머신'), WorkoutCategory.cardio);
    });

    test('새 유산소 종목의 지표', () {
      expect(cardioPrimaryMetricLabel('야외 러닝'), '속도');
      expect(cardioPrimaryMetricLabel('인클라인 걷기'), '경사');
      expect(cardioPrimaryMetricLabel('걷기'), '속도');
      expect(cardioPrimaryMetricLabel('수영'), '거리');
      expect(cardioPrimaryMetricLabel('점핑잭'), '횟수');
    });
  });
}
