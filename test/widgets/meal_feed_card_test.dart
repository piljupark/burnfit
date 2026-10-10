import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:pt_solution_v2/services/meal_feed_service.dart';
import 'package:pt_solution_v2/widgets/meal_feed.dart';

void main() {
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
}
