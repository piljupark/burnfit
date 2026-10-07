import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';

class WorkoutDraftService {
  WorkoutDraftService._();

  static String _key({
    required String memberId,
    required String workoutDate,
    required String workoutType,
  }) {
    return 'workout_draft_${memberId}_${workoutType}_$workoutDate';
  }

  /// 이 기기에 남은 해당 사용자의 임시 저장 운동을 모두 지운다 (탈퇴 시).
  static Future<void> clearAllFor(String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'workout_draft_${memberId}_';
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> saveDraft({
    required String memberId,
    required String workoutDate,
    required String workoutType,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {...data, 'savedAt': DateTime.now().toIso8601String()};

    await prefs.setString(
      _key(
        memberId: memberId,
        workoutDate: workoutDate,
        workoutType: workoutType,
      ),
      jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>?> loadDraft({
    required String memberId,
    required String workoutDate,
    required String workoutType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _key(
        memberId: memberId,
        workoutDate: workoutDate,
        workoutType: workoutType,
      ),
    );

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      AppLogger.debug('[WorkoutDraft] 임시저장 데이터 파싱 실패: $e');
      return null;
    }
  }

  static Future<void> clearDraft({
    required String memberId,
    required String workoutDate,
    required String workoutType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      _key(
        memberId: memberId,
        workoutDate: workoutDate,
        workoutType: workoutType,
      ),
    );
  }
}
