import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/service_validator.dart';
import '../models/custom_exercise.dart';
import '../models/workout.dart';

class ExerciseService {
  ExerciseService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static Future<List<CustomExercise>> getCustomExercises(
    String memberId,
  ) async {
    ServiceValidator.requireText(memberId, '회원 ID');

    final snap = await _db
        .collection('custom_exercises')
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs.map((d) => CustomExercise.fromMap(d.data())).toList();
  }

  static Future<CustomExercise> addCustomExercise({
    required String memberId,
    required String name,
    required WorkoutCategory category,
  }) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(name, '운동명');

    final normalizedName = name.trim();
    await _requireUniqueExerciseName(
      memberId: memberId,
      name: normalizedName,
      category: category,
    );

    final id = _uuid.v4();
    final exercise = CustomExercise(
      id: id,
      memberId: memberId,
      name: normalizedName,
      category: category,
      createdAt: DateTime.now(),
    );
    await _db.collection('custom_exercises').doc(id).set(exercise.toMap());
    return exercise;
  }

  static Future<void> deleteCustomExercise(String id) async {
    ServiceValidator.requireText(id, '커스텀 운동 ID');

    await _db.collection('custom_exercises').doc(id).delete();
  }

  static Future<void> _requireUniqueExerciseName({
    required String memberId,
    required String name,
    required WorkoutCategory category,
  }) async {
    final normalizedName = name.toLowerCase();
    final snap = await _db
        .collection('custom_exercises')
        .where('memberId', isEqualTo: memberId)
        .where('category', isEqualTo: category.name)
        .get();

    final duplicated = snap.docs.any((doc) {
      final data = doc.data();
      final existingName = data['name'] as String?;
      return existingName?.trim().toLowerCase() == normalizedName;
    });

    if (duplicated) {
      throw ArgumentError('이미 등록된 운동명입니다.');
    }
  }
}
