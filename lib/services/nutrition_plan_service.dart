import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/service_validator.dart';
import '../models/nutrition_plan.dart';

/// 회원 식단 목표 읽기 · 쓰기 (`nutrition_plans/{memberId}`).
/// 쓰기는 담당 트레이너만 된다 (규칙). 바뀌면 서버 함수가 회원에게 알린다.
class NutritionPlanService {
  NutritionPlanService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _doc(String memberId) {
    ServiceValidator.requireText(memberId, '회원 ID');
    return _db.collection('nutrition_plans').doc(memberId);
  }

  /// 목표가 없으면 null.
  static Future<NutritionPlan?> get(String memberId) async {
    final snap = await _doc(memberId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return NutritionPlan.fromMap(data);
  }

  static Future<void> save(NutritionPlan plan) async {
    final problem = plan.validate();
    if (problem != null) throw ArgumentError(problem);
    await _doc(plan.memberId).set(plan.toMap());
  }

  static Future<void> delete(String memberId) => _doc(memberId).delete();
}
