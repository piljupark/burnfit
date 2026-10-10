import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../models/workout.dart';
import '../models/workout_stats.dart';

class WorkoutService {
  WorkoutService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static Future<Workout> saveWorkout({
    required String centerId,
    required String memberId,
    required String memberName,
    String? trainerId,
    required WorkoutType workoutType,
    required String createdById,
    required WorkoutCreatedByRole createdByRole,
    String? ptSessionId,
    required String workoutDate,
    required WorkoutCategory category,
    required List<Exercise> exercises,
    String? note,
    int durationSeconds = 0,
  }) async {
    _validateWorkout(
      centerId: centerId,
      memberId: memberId,
      memberName: memberName,
      createdById: createdById,
      workoutDate: workoutDate,
      exercises: exercises,
      durationSeconds: durationSeconds,
    );

    final id = _uuid.v4();
    final now = DateTime.now();

    final workout = Workout(
      id: id,
      centerId: centerId,
      memberId: memberId,
      memberName: memberName,
      trainerId: trainerId,
      workoutType: workoutType,
      createdById: createdById,
      createdByRole: createdByRole,
      ptSessionId: ptSessionId,
      workoutDate: workoutDate,
      category: category,
      exercises: exercises,
      note: note,
      createdAt: now,
      updatedAt: now,
      durationSeconds: durationSeconds,
    );

    await _db.collection('workouts').doc(id).set(workout.toMap());
    return workout;
  }

  static Future<void> updateWorkout({
    required String workoutId,
    required WorkoutCategory category,
    required List<Exercise> exercises,
    String? note,
    int? durationSeconds,
  }) async {
    ServiceValidator.requireText(workoutId, '운동 ID');
    _validateExercises(exercises);
    if (durationSeconds != null) {
      ServiceValidator.requireNonNegativeInt(durationSeconds, '운동 시간');
    }

    await _db.collection('workouts').doc(workoutId).update({
      'category': category.name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'note': note,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      // 운동 시간은 더 이상 입력받지 않는다. 넘기지 않으면 기존 기록의 값을 그대로 둔다.
      'durationSeconds': ?durationSeconds,
    });
  }

  static Future<List<Workout>> getWorkoutsByDateRange(
    String centerId,
    String memberId,
    String startDate,
    String endDate, {
    WorkoutType? workoutType,
    String? ptTrainerId,
  }) async {
    _validateDateRangeQuery(
      centerId: centerId,
      memberId: memberId,
      startDate: startDate,
      endDate: endDate,
      fieldName: '운동 날짜',
    );

    final snap =
        await _ptScoped(
              _db
                  .collection('workouts')
                  .where('centerId', isEqualTo: centerId)
                  .where('memberId', isEqualTo: memberId),
              ptTrainerId,
            )
            .where('workoutDate', isGreaterThanOrEqualTo: startDate)
            .where('workoutDate', isLessThanOrEqualTo: endDate)
            .get();

    final list = _parseWorkoutDocs(snap.docs)
        .where((w) => workoutType == null || w.workoutType == workoutType)
        .toList();
    list.sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    return list;
  }

  static Future<List<Workout>> getWorkoutsByDate(
    String centerId,
    String memberId,
    String date, {
    WorkoutType? workoutType,
    String? ptTrainerId,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(date, '운동 날짜');

    final snap = await _ptScoped(
      _db
          .collection('workouts')
          .where('centerId', isEqualTo: centerId)
          .where('memberId', isEqualTo: memberId),
      ptTrainerId,
    ).where('workoutDate', isEqualTo: date).get();

    final list = _parseWorkoutDocs(snap.docs)
        .where((w) => workoutType == null || w.workoutType == workoutType)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  static Future<List<Workout>> getPreviousWorkouts({
    required String centerId,
    required String memberId,
    required String beforeDate,
    WorkoutType? workoutType,
    String? ptTrainerId,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(beforeDate, '운동 날짜');

    final snap = await _ptScoped(
      _db
          .collection('workouts')
          .where('centerId', isEqualTo: centerId)
          .where('memberId', isEqualTo: memberId),
      ptTrainerId,
    ).where('workoutDate', isLessThan: beforeDate).get();

    final list = _parseWorkoutDocs(snap.docs)
        .where((w) => workoutType == null || w.workoutType == workoutType)
        .toList();
    list.sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    return list;
  }

  /// 트레이너가 자기 PT 기록만 읽을 때: 회원의 운동 공유 설정과 관계없이 규칙이 허용하도록
  /// 조회 조건에 PT 유형과 작성 트레이너를 넣는다 (규칙은 필터가 아니다).
  static Query<Map<String, dynamic>> _ptScoped(
    Query<Map<String, dynamic>> query,
    String? ptTrainerId,
  ) {
    if (ptTrainerId == null) return query;
    return query
        .where('workoutType', isEqualTo: WorkoutType.pt.name)
        .where('trainerId', isEqualTo: ptTrainerId);
  }

  static Future<void> deleteWorkout(String workoutId) async {
    ServiceValidator.requireText(workoutId, '운동 ID');

    await _db.collection('workouts').doc(workoutId).delete();
  }

  static Future<void> linkFeedback(String workoutId, String feedbackId) async {
    ServiceValidator.requireText(workoutId, '운동 ID');
    ServiceValidator.requireText(feedbackId, '피드백 ID');

    await _db.collection('workouts').doc(workoutId).update({
      'hasFeedback': true,
      'feedbackId': feedbackId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<WorkoutStats> getWorkoutStats(
    String centerId,
    String memberId, {
    required String startDate,
    required String endDate,
  }) async {
    _validateDateRangeQuery(
      centerId: centerId,
      memberId: memberId,
      startDate: startDate,
      endDate: endDate,
      fieldName: '운동 날짜',
    );

    final snap = await _db
        .collection('workouts')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .where('workoutDate', isGreaterThanOrEqualTo: startDate)
        .where('workoutDate', isLessThanOrEqualTo: endDate)
        .get();

    final workouts = _parseWorkoutDocs(snap.docs);
    return WorkoutStats.fromWorkouts(
      workouts,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static List<Workout> _parseWorkoutDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final workouts = <Workout>[];
    for (final doc in docs) {
      try {
        workouts.add(Workout.fromMap(doc.data()));
      } catch (e) {
        AppLogger.debug('[WorkoutService] 운동 문서 파싱 실패(${doc.id}): $e');
      }
    }
    return workouts;
  }

  static void _validateWorkout({
    required String centerId,
    required String memberId,
    required String memberName,
    required String createdById,
    required String workoutDate,
    required List<Exercise> exercises,
    required int durationSeconds,
  }) {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(memberName, '회원 이름');
    ServiceValidator.requireText(createdById, '작성자 ID');
    ServiceValidator.requireDateKey(workoutDate, '운동 날짜');
    ServiceValidator.requireNonNegativeInt(durationSeconds, '운동 시간');
    _validateExercises(exercises);
  }

  static void _validateExercises(List<Exercise> exercises) {
    if (exercises.isEmpty) {
      throw ArgumentError('운동 종목이 비어 있습니다.');
    }
    for (final exercise in exercises) {
      ServiceValidator.requireText(exercise.name, '운동명');
      if (exercise.sets.isEmpty) {
        throw ArgumentError('운동 세트가 비어 있습니다.');
      }
      for (final set in exercise.sets) {
        ServiceValidator.requireNonNegativeDouble(set.weight, '무게');
        ServiceValidator.requirePositiveInt(set.reps, '횟수');
      }
    }
  }

  static void _validateDateRangeQuery({
    required String centerId,
    required String memberId,
    required String startDate,
    required String endDate,
    required String fieldName,
  }) {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(startDate, '$fieldName 시작일');
    ServiceValidator.requireDateKey(endDate, '$fieldName 종료일');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('$fieldName 시작일은 종료일보다 늦을 수 없습니다.');
    }
  }
}
