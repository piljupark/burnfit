import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/workout.dart';

Map<String, dynamic> _workoutMap({
  Object? workoutType = 'personal',
  Object? createdByRole = 'member',
  String? trainerId,
}) {
  final now = Timestamp.fromDate(DateTime(2026, 7, 20, 12));
  return {
    'id': 'workout-1',
    'centerId': 'center-1',
    'memberId': 'member-1',
    'memberName': '회원',
    'trainerId': trainerId,
    'workoutType': workoutType,
    'createdById': 'member-1',
    'createdByRole': createdByRole,
    'workoutDate': '2026-07-20',
    'category': 'chest',
    'exercises': [
      {
        'name': '벤치프레스',
        'sets': [
          {'weight': 60, 'reps': 10},
        ],
      },
    ],
    'createdAt': now,
    'updatedAt': now,
  };
}

void main() {
  group('Workout.fromMap', () {
    test('workoutType이 누락된 과거 데이터는 개인 운동으로 읽는다', () {
      final data = _workoutMap()..remove('workoutType');

      final workout = Workout.fromMap(data);

      expect(workout.workoutType, WorkoutType.personal);
    });

    test('workoutType 대소문자와 공백을 정규화한다', () {
      final workout = Workout.fromMap(_workoutMap(workoutType: ' PT '));

      expect(workout.workoutType, WorkoutType.pt);
    });

    test('과거 workoutType alias를 제한적으로 허용한다', () {
      final memberWorkout = Workout.fromMap(_workoutMap(workoutType: 'member'));
      final trainerWorkout = Workout.fromMap(
        _workoutMap(workoutType: 'trainer'),
      );

      expect(memberWorkout.workoutType, WorkoutType.personal);
      expect(trainerWorkout.workoutType, WorkoutType.pt);
    });

    test('createdByRole이 누락된 과거 데이터는 회원 작성으로 읽는다', () {
      final data = _workoutMap()..remove('createdByRole');

      final workout = Workout.fromMap(data);

      expect(workout.createdByRole, WorkoutCreatedByRole.member);
    });

    test('createdById가 누락된 회원 운동 과거 데이터는 memberId로 읽는다', () {
      final data = _workoutMap()..remove('createdById');

      final workout = Workout.fromMap(data);

      expect(workout.createdById, 'member-1');
    });

    test('createdById가 누락된 트레이너 운동 과거 데이터는 trainerId로 읽는다', () {
      final data = _workoutMap(
        workoutType: 'pt',
        createdByRole: 'trainer',
        trainerId: 'trainer-1',
      )..remove('createdById');

      final workout = Workout.fromMap(data);

      expect(workout.createdById, 'trainer-1');
    });
  });
}
