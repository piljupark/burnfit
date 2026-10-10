import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/screens/login_screen.dart';
import 'package:pt_solution_v2/screens/register_flow_screen.dart';
import 'package:pt_solution_v2/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  group('로그인', () {
    testWidgets('기억된 계정이 없으면 이메일·비밀번호만 받는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('로그인'), findsWidgets);
      expect(find.text('이메일'), findsOneWidget);
      // 라벨과 안내 글자
      expect(find.text('비밀번호'), findsNWidgets(2));
      // 센터·역할 고르기는 없다
      expect(find.text('센터'), findsNothing);
      expect(find.text('트레이너'), findsNothing);
      expect(find.text('가입하기'), findsOneWidget);
    });

    testWidgets('기억된 계정이 있으면 카드 + 비밀번호, 바꾸기로 이메일 화면을 오간다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_login_account': jsonEncode({
          'email': 'minji@burnfit.kr',
          'centerName': '버닝짐 강남점',
          'role': 'member',
        }),
      });
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('다시 오셨네요'), findsOneWidget);
      expect(find.text('버닝짐 강남점'), findsOneWidget);
      expect(find.text('회원 · minji@burnfit.kr'), findsOneWidget);
      expect(find.text('이메일'), findsNothing);

      await tester.tap(find.text('바꾸기'));
      await tester.pumpAndSettle();
      expect(find.text('다시 오셨네요'), findsNothing);
      expect(find.text('이메일'), findsOneWidget);

      await tester.tap(find.text('지난번 계정으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('다시 오셨네요'), findsOneWidget);
    });

    testWidgets('빈 칸으로 로그인하면 칸 아래 오류', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('이메일을 입력해주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
    });
  });

  group('가입 단계', () {
    testWidgets('관리자: 역할 → 계정 → 센터 열기, 뒤로는 앞 단계로 (값 유지)', (tester) async {
      await tester.pumpWidget(_app(const RegisterFlowScreen()));
      await tester.pumpAndSettle();

      expect(find.text('어떤 계정을 만들까요?'), findsOneWidget);
      await tester.tap(find.text('관리자'));
      await tester.pumpAndSettle();
      expect(find.text('계정을 만들어요'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      // 빈 칸이면 넘어가지 않는다
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('계정을 만들어요'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '박관리');
      await tester.enterText(fields.at(1), 'admin@burnfit.kr');
      await tester.enterText(fields.at(2), 'burn5');
      await tester.pump();
      expect(find.text('8자 이상 · 지금 5자'), findsOneWidget);
      await tester.enterText(fields.at(2), 'burnfit123');
      await tester.pump();
      expect(find.text('8자 이상'), findsOneWidget);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('센터를 열어요'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('계정을 만들어요'), findsOneWidget);
      expect(find.text('admin@burnfit.kr'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('어떤 계정을 만들까요?'), findsOneWidget);
    });
  });
}
