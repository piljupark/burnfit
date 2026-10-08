import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/app_spacing.dart';
import 'package:pt_solution_v2/widgets/app_toast.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: Scaffold(
          bottomNavigationBar: const SizedBox(height: 80),
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('토스트는 화면 위쪽에, 좌우 16 여백의 같은 폭으로 뜬다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ctx = await pumpHost(tester);

    for (final message in [
      '짧음',
      '아주 긴 안내 문구가 여러 줄로 넘어가더라도 토스트의 폭은 화면 폭에서 좌우 여백만 뺀 값으로 같아야 합니다.',
    ]) {
      AppToast.show(ctx, message: message);
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find
            .ancestor(of: find.text(message), matching: find.byType(Container))
            .first,
      );
      expect(rect.width, 390 - AppSpacing.base * 2, reason: message);
      expect(rect.top, lessThan(844 / 3), reason: '위쪽에 뜬다');
    }
    // 새 토스트가 이전 것을 바꾼다 (하나만 남는다)
    expect(find.text('짧음'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('아주 긴 안내'),
      findsNothing,
      reason: '3초 뒤 저절로 닫힌다',
    );
  });

  testWidgets('context 없이도(푸시 알림) 앱 Navigator 위에 뜨고, 행동 버튼을 누르면 닫힌다', (
    tester,
  ) async {
    await pumpHost(tester);
    var tapped = false;
    AppToast.show(
      null,
      title: '새 알림',
      message: '피드백이 도착했어요',
      actionLabel: '보기',
      onAction: () => tapped = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('새 알림'), findsOneWidget);
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(find.text('새 알림'), findsNothing);
  });
}
