import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/widgets/app_inputs.dart';

void main() {
  /// 스테퍼를 띄우고 가운데 숫자를 눌러 직접 입력 시트를 연다. 바뀐 값은 [changed]에 담긴다.
  Future<List<int>> openInput(WidgetTester tester) async {
    final changed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppStepper(
              value: 0,
              max: 999,
              unit: '회',
              semanticLabel: '총 횟수',
              onChanged: changed.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('총 횟수 직접 입력'));
    await tester.pumpAndSettle();
    return changed;
  }

  testWidgets('숫자를 누르면 직접 입력해 한 번에 바꿀 수 있다', (tester) async {
    final changed = await openInput(tester);

    await tester.enterText(find.byType(TextField), '30');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(changed, [30]);
  });

  testWidgets('범위를 넘는 값은 안내가 뜨고 확인할 수 없다', (tester) async {
    final changed = await openInput(tester);

    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    expect(find.text('0~999 사이로 입력해주세요.'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(changed, isEmpty);
  });
}
