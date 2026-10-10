import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/screens/member/member_workout_done_screen.dart';

void main() {
  Future<void> pumpDone(
    WidgetTester tester, {
    int durationSeconds = 0,
    Future<bool> Function(int)? onChange,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberWorkoutDoneScreen(
          totalVolumeKg: 1200,
          exerciseCount: 2,
          setCount: 6,
          durationSeconds: durationSeconds,
          onChangeDuration: onChange,
        ),
      ),
    );
    // 바벨 그림이 계속 움직여 settle하지 않으므로 시간만 흘린다
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('운동 시간이 요약 줄에 붙고, 고칠 수 있으면 링크가 보인다', (tester) async {
    await pumpDone(
      tester,
      durationSeconds: 48 * 60,
      onChange: (_) async => true,
    );
    expect(find.text('2종목 · 6세트 · 48분'), findsOneWidget);
    expect(find.text('운동 시간 고치기'), findsOneWidget);
  });

  testWidgets('시간을 재지 않았으면 요약 줄에 없고, 고칠 수 없으면 링크도 없다', (tester) async {
    await pumpDone(tester);
    expect(find.text('2종목 · 6세트'), findsOneWidget);
    expect(find.text('운동 시간 고치기'), findsNothing);
  });
}
