import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/models/nutrition_plan.dart';
import 'package:pt_solution_v2/widgets/nutrition_plan_card.dart';

NutritionPlan _plan({
  int? calories = 2100,
  int? protein = 140,
  Map<MealType, String> guides = const {MealType.lunch: '밥 2/3 공기'},
  String? note,
}) => NutritionPlan(
  memberId: 'm1',
  centerId: 'c1',
  trainerId: 't1',
  trainerName: '박코치',
  calories: calories,
  protein: protein,
  mealGuides: guides,
  note: note,
);

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  group('검사', () {
    test('비어 있으면 저장하지 않는다', () {
      expect(
        _plan(calories: null, protein: null, guides: const {}).validate(),
        isNotNull,
      );
    });

    test('끼니 가이드만 있어도 된다', () {
      expect(_plan(calories: null, protein: null).validate(), isNull);
    });

    test('범위 밖 숫자는 조사까지 맞는 문구로 막는다', () {
      expect(_plan(calories: 100).validate(), '칼로리는 500~6000kcal 사이로 적어 주세요.');
      expect(_plan(protein: 900).validate(), '단백질은 0~500g 사이로 적어 주세요.');
    });
  });

  test('저장 형식: 빈 가이드는 빼고, 읽으면 같은 값', () {
    final map = _plan(
      guides: const {MealType.lunch: '밥 2/3 공기', MealType.snack: '  '},
      note: ' 물 2L ',
    ).toMap();
    expect(map['mealGuides'], {'lunch': '밥 2/3 공기'});
    expect(map['note'], '물 2L');
    expect(map['updatedAt'], isA<FieldValue>());

    final read = NutritionPlan.fromMap({
      ...map,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 12)),
    });
    expect(read.calories, 2100);
    expect(read.carbs, isNull);
    expect(read.mealGuides, {MealType.lunch: '밥 2/3 공기'});
    expect(read.note, '물 2L');
  });

  group('추천', () {
    test('기초대사량 × 1.55 − 500, 단백질 체중 × 2, 지방 25%, 탄수 나머지', () {
      final r = NutritionRecommendation.from(
        bmr: 1600,
        weight: 70,
        goal: NutritionGoal.lose,
      )!;
      // 1600 × 1.55 = 2480 − 500 = 1980 → 2000 (50 단위)
      expect(r.calories, 2000);
      expect(r.protein, 140);
      expect(r.fat, 55); // 2000 × 0.25 / 9 = 55.6 → 55
      expect(r.carbs, 235); // (2000 − 560 − 495) / 4 = 236.25 → 235
      expect(r.basis, contains('기초대사량 1600'));
    });

    test('감량해도 기초대사량 아래로는 내리지 않는다', () {
      final r = NutritionRecommendation.from(
        // 800 × 1.55 − 500 = 740 → 기초대사량 800에서 멈춘다
        bmr: 800,
        weight: 40,
        goal: NutritionGoal.lose,
      )!;
      expect(r.calories, 800);
    });

    test('기초대사량이 없으면 체중 × 30, 둘 다 없으면 추천 없음', () {
      final r = NutritionRecommendation.from(
        weight: 60,
        goal: NutritionGoal.maintain,
      )!;
      expect(r.calories, 1800);
      expect(r.protein, 95); // 60 × 1.6 = 96 → 95
      expect(NutritionRecommendation.from(goal: NutritionGoal.gain), isNull);
    });
  });

  group('카드', () {
    Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListView(children: [card])),
      ),
    );

    testWidgets('숫자 · 빈 칸 · 한마디 · 끼니 가이드', (tester) async {
      await pump(
        tester,
        NutritionPlanCard(
          plan: _plan(note: '물 2L'),
          emptyMessage: '없음',
        ),
      );
      expect(find.text('식단 목표'), findsOneWidget);
      expect(find.textContaining('박코치 트레이너'), findsOneWidget);
      expect(find.text('–'), findsNWidgets(2)); // 탄수 · 지방은 비어 있다
      expect(find.text('물 2L'), findsOneWidget);
      expect(find.text('점심'), findsOneWidget);
      expect(find.text('밥 2/3 공기'), findsOneWidget);
      expect(find.text('고치기'), findsNothing); // 회원 화면
    });

    testWidgets('목표가 없으면 안내, 트레이너는 정하기', (tester) async {
      var tapped = false;
      await pump(
        tester,
        NutritionPlanCard(
          plan: null,
          emptyMessage: '아직 식단 목표가 없어요.',
          onEdit: () => tapped = true,
        ),
      );
      expect(find.text('아직 식단 목표가 없어요.'), findsOneWidget);
      await tester.tap(find.text('정하기'));
      expect(tapped, isTrue);
    });
  });
}
