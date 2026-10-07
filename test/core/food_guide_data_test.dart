import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/food_guide_data.dart';
import 'package:pt_solution_v2/models/food_guide.dart';
import 'package:pt_solution_v2/models/meal.dart';

void main() {
  group('FoodGuideData', () {
    test('id가 겹치지 않는다', () {
      final ids = FoodGuideData.foods.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('영양소 분류마다 10~15개, 설명이 하나씩 있다', () {
      for (final category in NutrientCategory.values) {
        final count = FoodGuideData.byCategory(category).length;
        expect(count, inInclusiveRange(10, 15), reason: category.label);
      }
      expect(
        FoodGuideData.categories.map((c) => c.category).toSet(),
        NutrientCategory.values.toSet(),
      );
    });

    test('상황 4개, 상황·짝 음식의 id는 모두 실제 음식을 가리킨다', () {
      expect(FoodGuideData.situations, hasLength(4));
      for (final s in FoodGuideData.situations) {
        expect(s.foodIds, isNotEmpty, reason: s.id);
        for (final id in s.foodIds) {
          expect(FoodGuideData.byId(id), isNotNull, reason: '${s.id} → $id');
        }
      }
      for (final food in FoodGuideData.foods) {
        for (final id in food.pairsWith) {
          expect(FoodGuideData.byId(id), isNotNull, reason: '${food.id} → $id');
          expect(id, isNot(food.id), reason: '${food.id}는 자기 자신과 짝이 될 수 없다');
        }
      }
    });

    test('음식마다 분량·먹는 법·짝 음식이 있고 수치가 말이 된다', () {
      for (final f in FoodGuideData.foods) {
        expect(f.name.trim(), isNotEmpty);
        expect(f.serving.trim(), isNotEmpty, reason: f.id);
        expect(f.howToEat, isNotEmpty, reason: f.id);
        expect(f.pairsWith, isNotEmpty, reason: f.id);
        expect(f.kcal, greaterThan(0), reason: f.id);
        for (final g in [f.protein, f.carbs, f.fat]) {
          expect(g, greaterThanOrEqualTo(0), reason: f.id);
        }
        // 탄·단·지 열량 합이 표시 kcal과 크게 어긋나지 않는다 (대략값 검증, ±35%)
        final energy = f.protein * 4 + f.carbs * 4 + f.fat * 9;
        expect(
          energy,
          inInclusiveRange(f.kcal * 0.65, f.kcal * 1.35),
          reason: '${f.id}: $energy vs ${f.kcal}',
        );
      }
    });

    test('resolve는 없는 id를 건너뛴다', () {
      final foods = FoodGuideData.resolve(['egg', 'nope', 'banana']);
      expect(foods.map((f) => f.id), ['egg', 'banana']);
    });
  });

  test('formatGrams: 정수는 소수점 없이, 아니면 한 자리', () {
    expect(formatGrams(23), '23');
    expect(formatGrams(1.2), '1.2');
    expect(formatGrams(6.25), '6.3');
    expect(formatGrams(0), '0');
  });

  test('mealDescription은 이름과 분량', () {
    expect(FoodGuideData.byId('chicken_breast')!.mealDescription, '닭가슴살 100g');
  });

  test('mealTypeForTime: 시각으로 끼니를 짐작한다', () {
    MealType at(int h) => mealTypeForTime(DateTime(2026, 10, 7, h, 30));
    expect(at(7), MealType.breakfast);
    expect(at(10), MealType.breakfast);
    expect(at(11), MealType.lunch);
    expect(at(14), MealType.lunch);
    expect(at(16), MealType.snack);
    expect(at(18), MealType.dinner);
    expect(at(22), MealType.snack);
    expect(at(2), MealType.snack);
  });
}
