import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';
import 'meal.dart';

/// 회원 식단 목표 — 담당 트레이너가 정한다 (`nutrition_plans/{memberId}`, 회원별 하나, 이력 없음).
///
/// 회원이 칼로리를 직접 적던 방식을 대신한다. 숫자는 모두 비울 수 있고(끼니 가이드만 줄 수도 있다),
/// 범위는 저장 규칙(`firestore.rules` hasValidNutritionPlan)과 같다.
class NutritionPlan {
  final String memberId;
  final String centerId;
  final String trainerId;
  final String trainerName;

  /// 하루 권장 칼로리 (kcal)
  final int? calories;

  /// 하루 권장 탄수화물 · 단백질 · 지방 (g)
  final int? carbs;
  final int? protein;
  final int? fat;

  /// 끼니별 가이드 ('단백질 손바닥 1개 + 밥 반 공기'). 빈 끼니는 없다.
  final Map<MealType, String> mealGuides;

  /// 트레이너 한마디
  final String? note;
  final DateTime? updatedAt;

  const NutritionPlan({
    required this.memberId,
    required this.centerId,
    required this.trainerId,
    required this.trainerName,
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.mealGuides = const {},
    this.note,
    this.updatedAt,
  });

  static const caloriesRange = (500, 6000);
  static const carbsRange = (0, 1000);
  static const proteinRange = (0, 500);
  static const fatRange = (0, 400);
  static const guideMaxLength = 200;
  static const noteMaxLength = 500;

  /// 보일 것이 하나도 없는 목표인지 (저장하지 않는다).
  bool get isEmpty =>
      calories == null &&
      carbs == null &&
      protein == null &&
      fat == null &&
      mealGuides.values.every((g) => g.trim().isEmpty) &&
      (note ?? '').trim().isEmpty;

  bool get hasNumbers =>
      calories != null || carbs != null || protein != null || fat != null;

  /// 저장 전 검사. 문제가 있으면 사용자에게 보일 문구, 없으면 null.
  String? validate() {
    // [subject]는 조사까지 ('칼로리는', '단백질은').
    String? range(int? v, (int, int) r, String subject, String unit) {
      if (v == null || (v >= r.$1 && v <= r.$2)) return null;
      return '$subject ${r.$1}~${r.$2}$unit 사이로 적어 주세요.';
    }

    if (isEmpty) return '숫자나 끼니 가이드 중 하나는 적어 주세요.';
    if (mealGuides.values.any((g) => g.length > guideMaxLength)) {
      return '끼니 가이드는 $guideMaxLength자까지 적을 수 있어요.';
    }
    if ((note ?? '').length > noteMaxLength) {
      return '한마디는 $noteMaxLength자까지 적을 수 있어요.';
    }
    return range(calories, caloriesRange, '칼로리는', 'kcal') ??
        range(carbs, carbsRange, '탄수화물은', 'g') ??
        range(protein, proteinRange, '단백질은', 'g') ??
        range(fat, fatRange, '지방은', 'g');
  }

  /// [updatedAt]은 저장할 때 서버 시각으로 넣는다 (규칙이 확인한다).
  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'centerId': centerId,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'calories': calories,
    'carbs': carbs,
    'protein': protein,
    'fat': fat,
    'mealGuides': {
      for (final e in mealGuides.entries)
        if (e.value.trim().isNotEmpty) e.key.name: e.value.trim(),
    },
    'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory NutritionPlan.fromMap(Map<String, dynamic> map) {
    int? number(String key) {
      final v = map[key];
      return v is num ? v.round() : null;
    }

    final rawGuides = map['mealGuides'];
    final guides = <MealType, String>{};
    if (rawGuides is Map) {
      for (final type in MealType.values) {
        final v = rawGuides[type.name];
        if (v is String && v.trim().isNotEmpty) guides[type] = v.trim();
      }
    }
    final note = map['note'];
    return NutritionPlan(
      memberId: map['memberId'] as String? ?? '',
      centerId: map['centerId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      trainerName: map['trainerName'] as String? ?? '',
      calories: number('calories'),
      carbs: number('carbs'),
      protein: number('protein'),
      fat: number('fat'),
      mealGuides: guides,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
      updatedAt: map['updatedAt'] == null
          ? null
          : FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }
}

/// 추천 계산의 목표 (트레이너가 고른다).
enum NutritionGoal {
  lose('감량'),
  maintain('유지'),
  gain('증량');

  final String label;

  const NutritionGoal(this.label);
}

/// 식단 목표 추천 — 트레이너가 고칠 출발점 (정밀한 처방이 아니다).
///
/// - 하루 소비 = 기초대사량(인바디) × 1.55 (주 3~5회 운동). 기초대사량이 없으면 체중 × 30.
/// - 감량 −500 (기초대사량 아래로는 내리지 않음) · 유지 그대로 · 증량 +300, 50 단위.
/// - 단백질 = 체중 × 2.0 (감량) / 1.6 (유지) / 1.8 (증량), 지방 = 칼로리의 25%, 탄수화물 = 나머지.
class NutritionRecommendation {
  final int calories;
  final int carbs;
  final int protein;
  final int fat;

  /// 화면에 보일 근거 한 줄
  final String basis;

  const NutritionRecommendation({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.basis,
  });

  static const activityFactor = 1.55;

  static int _round(double v, int step) => (v / step).round() * step;

  /// 체중도 기초대사량도 없으면 추천할 수 없다 (null).
  static NutritionRecommendation? from({
    double? bmr,
    double? weight,
    required NutritionGoal goal,
  }) {
    if ((bmr == null || bmr <= 0) && (weight == null || weight <= 0)) {
      return null;
    }
    final hasBmr = bmr != null && bmr > 0;
    final tdee = hasBmr ? bmr * activityFactor : weight! * 30;
    final adjusted = switch (goal) {
      NutritionGoal.lose => tdee - 500,
      NutritionGoal.maintain => tdee,
      NutritionGoal.gain => tdee + 300,
    };
    final floor = hasBmr ? bmr : 1200.0;
    final calories = _round(adjusted < floor ? floor : adjusted, 50);
    final proteinPerKg = switch (goal) {
      NutritionGoal.lose => 2.0,
      NutritionGoal.maintain => 1.6,
      NutritionGoal.gain => 1.8,
    };
    final protein = weight != null && weight > 0
        ? _round(weight * proteinPerKg, 5)
        : _round(calories * 0.25 / 4, 5);
    final fat = _round(calories * 0.25 / 9, 5);
    final carbsRaw = (calories - protein * 4 - fat * 9) / 4;
    final carbs = _round(carbsRaw < 0 ? 0 : carbsRaw, 5);

    final base = hasBmr
        ? '기초대사량 ${bmr.round()} × 활동 $activityFactor'
        : '체중 ${weight!.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}kg × 30';
    final adjust = switch (goal) {
      NutritionGoal.lose => ' − 500',
      NutritionGoal.maintain => '',
      NutritionGoal.gain => ' + 300',
    };
    return NutritionRecommendation(
      calories: calories,
      carbs: carbs,
      protein: protein,
      fat: fat,
      basis: '$base$adjust (${goal.label})',
    );
  }
}
