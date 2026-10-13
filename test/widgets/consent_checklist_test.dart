import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/validators.dart';
import 'package:pt_solution_v2/widgets/consent_checklist.dart';

void main() {
  group('휴대폰 번호', () {
    test('하이픈 · 공백을 지우고 010-1234-5678 형태로', () {
      expect(Validators.normalizePhone('01012345678'), '010-1234-5678');
      expect(Validators.normalizePhone('010 1234 5678'), '010-1234-5678');
      expect(Validators.normalizePhone('011-123-4567'), '011-123-4567');
      expect(Validators.normalizePhone('02-123-4567'), isNull);
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone('010-1234-5678'), isNull);
    });

    test('화면에서는 가운데를 가린다', () {
      expect(Validators.maskPhone('010-1234-5678'), '010-****-5678');
    });
  });

  group('동의 묶음', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool privacy,
      bool? health,
      required ValueChanged<bool> onPrivacy,
      ValueChanged<bool>? onHealth,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsentChecklist(
            privacy: privacy,
            health: health,
            onPrivacy: onPrivacy,
            onHealth: onHealth,
          ),
        ),
      ),
    );

    testWidgets('회원: 전체 동의를 누르면 두 개 모두 켜진다', (tester) async {
      bool? p;
      bool? h;
      await pump(
        tester,
        privacy: false,
        health: false,
        onPrivacy: (v) => p = v,
        onHealth: (v) => h = v,
      );
      expect(find.textContaining('건강 정보 수집'), findsOneWidget);
      await tester.tap(find.text('전체 동의'));
      expect(p, isTrue);
      expect(h, isTrue);
    });

    testWidgets('트레이너: 건강 정보 줄이 없다', (tester) async {
      await pump(tester, privacy: false, onPrivacy: (_) {});
      expect(find.textContaining('건강 정보 수집'), findsNothing);
      expect(find.textContaining('개인정보 수집'), findsOneWidget);
    });

    testWidgets("'보기'는 전문 시트 (보관 기간 · 거부 권리)", (tester) async {
      await pump(
        tester,
        privacy: false,
        health: false,
        onPrivacy: (_) {},
        onHealth: (_) {},
      );
      await tester.tap(find.bySemanticsLabel('개인정보 수집 · 이용 전문 보기'));
      await tester.pumpAndSettle();
      expect(find.text('보관 기간'), findsOneWidget);
      expect(find.textContaining('3년간 보관'), findsOneWidget);
      expect(find.text('동의하지 않을 권리'), findsOneWidget);
    });
  });
}
