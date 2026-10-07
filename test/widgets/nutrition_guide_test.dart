import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/food_guide.dart';
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/screens/member/food_detail_sheet.dart';
import 'package:pt_solution_v2/screens/member/meal_input_sheet.dart';
import 'package:pt_solution_v2/screens/member/nutrition_guide_screen.dart';
import 'package:pt_solution_v2/widgets/app_tag.dart';

/// 폰 폭에 목록·시트가 한 화면에 다 보이는 높이 (MediaQuery까지 바뀌도록 view 크기를 정한다).
void _tallPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('가이드 → 영양소 목록 → 필터 → 상세 시트 → 추가 버튼이 고른 음식을 넘긴다', (tester) async {
    _tallPhone(tester);
    FoodItem? added;
    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGuideScreen(
          addAction: FoodAddAction(
            label: '오늘 식단에 추가',
            onAdd: (food) async => added = food,
          ),
        ),
      ),
    );

    expect(find.text('운동 직후'), findsOneWidget);
    await tester.tap(find.text('단백질'));
    await tester.pumpAndSettle();

    expect(find.text('닭가슴살'), findsOneWidget);
    expect(find.text('고등어'), findsOneWidget);

    // 식물성 필터: 두부·두유만 남는다
    await tester.tap(find.widgetWithText(AppChip, '식물성'));
    await tester.pumpAndSettle();
    expect(find.text('고등어'), findsNothing);
    expect(find.text('두부'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppChip, '전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닭가슴살'));
    await tester.pumpAndSettle();
    expect(find.text('먹는 법'), findsOneWidget);
    expect(find.text('100g · 109kcal'), findsOneWidget);

    // 짝 음식 칩 → 그 음식 시트로 바뀐다
    await tester.tap(find.widgetWithText(AppChip, '고구마'));
    await tester.pumpAndSettle();
    expect(find.text('1개 150g · 195kcal'), findsOneWidget);

    await tester.tap(find.text('오늘 식단에 추가'));
    await tester.pumpAndSettle();
    expect(added?.id, 'sweet_potato');
    expect(find.text('먹는 법'), findsNothing);
  });

  testWidgets('추가 동작이 없으면 시트에 추가 버튼이 없다', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(const MaterialApp(home: NutritionGuideScreen()));
    await tester.tap(find.text('편의점 · 외식할 때'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('김밥'));
    await tester.pumpAndSettle();
    expect(find.text('먹는 법'), findsOneWidget);
    expect(find.textContaining('식단에 추가'), findsNothing);
  });

  testWidgets('식단 입력 화면은 넘겨받은 끼니·메모·칼로리로 미리 채워진다', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: MealInputSheet(
          centerId: 'c1',
          memberId: 'm1',
          memberName: '회원',
          selectedDate: '2026-10-07',
          initialMealType: MealType.dinner,
          initialDescription: '닭가슴살 100g',
          initialCalories: 109,
        ),
      ),
    );
    expect(find.text('닭가슴살 100g'), findsOneWidget);
    expect(find.text('109'), findsOneWidget);
    final dinner = tester.widget<AppChip>(find.widgetWithText(AppChip, '저녁'));
    final lunch = tester.widget<AppChip>(find.widgetWithText(AppChip, '점심'));
    expect(dinner.selected, isTrue);
    expect(lunch.selected, isFalse);
  });
}
