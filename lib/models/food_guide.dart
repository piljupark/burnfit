import 'package:flutter/widgets.dart';

/// 영양 가이드의 영양소 분류. 음식 하나는 분류 하나에만 속한다.
enum NutrientCategory { protein, carb, fat, vegFruit }

extension NutrientCategoryLabel on NutrientCategory {
  String get label => switch (this) {
    NutrientCategory.protein => '단백질',
    NutrientCategory.carb => '탄수화물',
    NutrientCategory.fat => '지방',
    NutrientCategory.vegFruit => '채소 · 과일',
  };
}

/// 목록 필터 칩에 쓰는 음식 특성.
enum FoodTag { convenience, noCook, plant }

extension FoodTagLabel on FoodTag {
  String get label => switch (this) {
    FoodTag.convenience => '편의점',
    FoodTag.noCook => '조리 없이',
    FoodTag.plant => '식물성',
  };
}

/// 추천 음식 한 가지. 수치는 1회 분량 기준 대략값이다.
class FoodItem {
  final String id;
  final String name;
  final NutrientCategory category;

  /// 1회 분량 (예: '1토막 100g')
  final String serving;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final Set<FoodTag> tags;
  final List<String> howToEat;

  /// 같이 먹으면 좋은 음식의 [id]
  final List<String> pairsWith;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.serving,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.tags = const {},
    this.howToEat = const [],
    this.pairsWith = const [],
  });

  /// 식단 메모에 넣을 한 줄 (예: '닭가슴살 100g').
  String get mealDescription => '$name $serving';
}

/// 영양소 분류 화면의 머리 설명.
class NutrientCategoryInfo {
  final NutrientCategory category;
  final IconData icon;

  /// 2×2 칸의 짧은 설명 (예: '근육 회복')
  final String tagline;

  /// 목록 화면 위 설명 문장
  final String description;

  const NutrientCategoryInfo({
    required this.category,
    required this.icon,
    required this.tagline,
    required this.description,
  });
}

/// '이럴 땐 이렇게' 상황 하나와 그때 고를 만한 음식들.
class FoodSituation {
  final String id;
  final String title;
  final IconData icon;
  final String description;
  final List<String> foodIds;

  const FoodSituation({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.foodIds,
  });
}

/// 그램 표시: 정수면 소수점 없이, 아니면 한 자리 (23 → '23', 1.2 → '1.2').
String formatGrams(double grams) {
  final rounded = (grams * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}
