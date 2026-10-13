import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/models/feedback.dart' as fb;
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/models/nutrition_plan.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:pt_solution_v2/services/meal_feed_service.dart';
import 'package:pt_solution_v2/widgets/meal_feed.dart';
import 'package:pt_solution_v2/widgets/nutrition_plan_card.dart';

void main() {
  // 앱은 main()에서 초기화한다. 피드백 시각이 오늘이 아니면 '어제' 같은 한국어 날짜를 쓴다.
  setUpAll(() => initializeDateFormatting('ko'));

  final now = DateTime.now();
  final member = AppUser(
    uid: 'm1',
    email: 'm1@burnfit.kr',
    name: '김민지',
    role: UserRole.member,
    status: UserStatus.approved,
    centerId: 'c1',
    centerName: '버닝짐 강남점',
    createdAt: now,
    updatedAt: now,
  );
  final item = MealFeedItem(
    member: member,
    feedbacks: const [],
    meal: Meal(
      id: 'a',
      centerId: 'c1',
      memberId: 'm1',
      memberName: '김민지',
      mealType: MealType.lunch,
      mealDate: '2026-10-10',
      mealTime: '12:40',
      imageUrls: const [],
      description: '닭가슴살 덮밥 반 공기',
      calories: 620,
      createdAt: now,
      updatedAt: now,
    ),
  );

  testWidgets('글자를 넣어야 보내지고, 보내면 입력이 비워진다', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealFeedCard(
              item: item,
              trainerId: 't1',
              isNew: true,
              onSend: (content) async {
                sent.add(content);
                return true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('점심 · 12:40'), findsOneWidget);
    expect(find.text('피드백 전'), findsOneWidget);
    expect(find.text('닭가슴살 덮밥 반 공기'), findsOneWidget);

    final send = find.bySemanticsLabel('김민지 점심 식단에 피드백 보내기');
    await tester.tap(send);
    await tester.pump();
    expect(sent, isEmpty);

    // 자주 쓰는 말로 채우고 이어 쓰기
    await tester.tap(find.text('단백질 좋아요'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '단백질 좋아요 내일도 이렇게');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(sent, ['단백질 좋아요 내일도 이렇게']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('식단 목표가 있으면 칼로리 없이 끼니 가이드와 목표 기준 자주 쓰는 말', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealFeedCard(
              item: item,
              trainerId: 't1',
              guide: '단백질 손바닥 1개 + 밥 2/3',
              quickPhrases: MealFeedCard.goalPhrases,
              onSend: (_) async => true,
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('점심 가이드'), findsOneWidget);
    expect(find.textContaining('단백질 손바닥 1개'), findsOneWidget);
    expect(find.text('가이드대로 잘 드셨어요'), findsOneWidget);
    expect(find.text('단백질 좋아요'), findsNothing);
    expect(find.textContaining('620'), findsNothing); // 예전 칼로리는 보이지 않는다
  });

  group('식단 탭 목표 줄', () {
    NutritionPlan plan({
      int? kcal,
      int? carbs,
      int? protein,
      int? fat,
      Map<MealType, String> guides = const {},
    }) => NutritionPlan(
      memberId: 'm1',
      centerId: 'c1',
      trainerId: 't1',
      trainerName: '박코치',
      calories: kcal,
      carbs: carbs,
      protein: protein,
      fat: fat,
      mealGuides: guides,
    );

    Future<void> pump(WidgetTester tester, NutritionPlan? p) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NutritionGoalStrip(plan: p, onEdit: () {}),
            ),
          ),
        );

    String macros(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .join();

    testWidgets('칼로리 + 탄단지: 첫째 줄 칼로리, 둘째 줄 탄단지', (tester) async {
      await pump(tester, plan(kcal: 2450, carbs: 325, protein: 130, fat: 65));
      expect(find.text('하루 2,450kcal'), findsOneWidget);
      expect(macros(tester), '탄수화물 325g · 단백질 130g · 지방 65g');
    });

    testWidgets("탄단지만: 머리 '하루 목표' + 탄단지 줄, 칼로리 자리 없음", (tester) async {
      await pump(tester, plan(carbs: 230, protein: 140, fat: 60));
      expect(find.text('하루 목표'), findsOneWidget);
      expect(find.textContaining('kcal'), findsNothing);
      expect(macros(tester), '탄수화물 230g · 단백질 140g · 지방 60g');
    });

    testWidgets('칼로리 + 단백질: 정한 것만', (tester) async {
      await pump(tester, plan(kcal: 1900, protein: 150));
      expect(find.text('하루 1,900kcal'), findsOneWidget);
      expect(macros(tester), '단백질 150g');
    });

    testWidgets("끼니 가이드만: 머리 '끼니 가이드', 숫자 줄 없음", (tester) async {
      await pump(tester, plan(guides: const {MealType.lunch: '밥은 반 공기만'}));
      expect(find.text('끼니 가이드'), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      expect(find.textContaining('밥은 반 공기만'), findsOneWidget);
    });

    testWidgets('목표 없음: 정하기', (tester) async {
      await pump(tester, null);
      expect(find.text('식단 목표가 없어요'), findsOneWidget);
      expect(find.text('정하기'), findsOneWidget);
    });
  });

  group('내 피드백 고치기 · 지우기', () {
    fb.Feedback feedback(
      String id,
      String trainerId,
      String content, {
      DateTime? updated,
      DateTime? read,
    }) => fb.Feedback(
      id: id,
      centerId: 'c1',
      trainerId: trainerId,
      trainerName: trainerId == 't1' ? '박코치' : '이코치',
      memberId: 'm1',
      memberName: '김민지',
      targetType: fb.FeedbackTargetType.meal,
      targetId: 'a',
      content: content,
      createdAt: DateTime(2026, 10, 13, 9),
      updatedAt: updated ?? DateTime(2026, 10, 13, 9),
      readAt: read,
    );

    test('수정됨: 보낸 지 1분 넘게 지나 내용을 고쳤을 때만 (예전 읽음 처리는 제외)', () {
      expect(feedback('x', 't1', 'a').isEdited, isFalse);
      expect(
        feedback('x', 't1', 'a', updated: DateTime(2026, 10, 13, 10)).isEdited,
        isTrue,
      );
      // 예전에는 읽음 처리가 updatedAt을 바꿨다 → 읽은 시각과 같으면 고친 것이 아니다
      expect(
        feedback(
          'x',
          't1',
          'a',
          updated: DateTime(2026, 10, 13, 10),
          read: DateTime(2026, 10, 13, 10),
        ).isEdited,
        isFalse,
      );
    });

    testWidgets('내 말풍선에만 ⋯, 고치기를 누르면 입력에 채워지고 보내면 고친 내용으로', (tester) async {
      final mine = feedback('f1', 't1', '단백질 좋아요');
      final other = feedback('f2', 't2', '물 많이 드세요');
      final card = MealFeedItem(
        member: item.member,
        meal: item.meal,
        feedbacks: [other, mine],
      );
      final edits = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealFeedCard(
                item: card,
                trainerId: 't1',
                onSend: (_) async => true,
                onEditFeedback: (f, content) async {
                  edits.add('${f.id}:$content');
                  return true;
                },
                onDeleteFeedback: (_) async => true,
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('내 피드백 고치기 · 지우기'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('내 피드백 고치기 · 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('고치기'));
      await tester.pumpAndSettle();
      expect(find.text('피드백 고치는 중'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '단백질 아주 좋아요');
      await tester.tap(find.bySemanticsLabel('고친 피드백 저장'));
      await tester.pumpAndSettle();
      expect(edits, ['f1:단백질 아주 좋아요']);
      expect(find.text('피드백 고치는 중'), findsNothing);
    });
  });

  test('식단 항목: 고친 피드백 바꾸기 · 지운 피드백 빼기', () {
    final a = fb.Feedback(
      id: 'a1',
      centerId: 'c1',
      trainerId: 't1',
      trainerName: '',
      memberId: 'm1',
      memberName: '',
      targetType: fb.FeedbackTargetType.meal,
      content: '처음',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final withA = item.withFeedback(a);
    expect(
      withA.withReplaced(a.copyWith(content: '고침')).feedbacks.single.content,
      '고침',
    );
    expect(withA.withoutFeedback('a1').feedbacks, isEmpty);
  });
}
