// 화면 투어: 역할별로 로그인해 주요 화면을 돌며 스크린샷을 남긴다 (디자인 확인용).
//
// 준비: Firebase 에뮬레이터 실행 + 예시 데이터 (functions/integration/seed_screens.js 참고)
// 실행:
//   flutter drive -d <iOS 시뮬레이터> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screen_tour_test.dart \
//     --dart-define=USE_FIREBASE_EMULATOR=true
// 결과: build/screen_tour/*.png
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pt_solution_v2/main.dart';
import 'package:pt_solution_v2/widgets/app_icon_button.dart';
import 'package:pt_solution_v2/widgets/app_nav_bar.dart';
import 'package:pt_solution_v2/widgets/notification_bell_button.dart';

const _password = 'password123';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, [int ms = 2500]) async {
    // Orb가 계속 움직이므로 pumpAndSettle 대신 일정 시간만 그린다.
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      debugPrint('[tour] 스크린샷 실패 $name: $e');
    }
  }

  Future<void> step(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('[tour] 건너뜀 "$label": $e');
    }
  }

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(PtSolutionApp(key: UniqueKey()));
    await wait(tester, 4000);
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AppNavBar), matching: find.text(label)));
    await wait(tester);
  }

  Future<void> back(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    // 열린 화면이 없으면(탭이 빗나간 경우) 첫 화면을 닫지 않는다.
    if (!navigator.canPop()) return;
    navigator.pop();
    await wait(tester, 1200);
  }

  Finder iconButton(bool Function(String label) match) =>
      find.byWidgetPredicate((w) => w is AppIconButton && match(w.label));

  testWidgets('screen tour', (tester) async {
    await bootstrapApp(withMessaging: false);
    await FirebaseAuth.instance.signOut();

    // ── 로그인 ──
    await startApp(tester);
    await shot('00_login');

    // ── 회원 ──
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'member@burnfit.test', password: _password);
    await startApp(tester);
    await shot('10_member_home');
    // 스크롤하기 전에 위쪽 버튼(알림·바로가기)부터 연다.
    await step('notifications', () async {
      await tester.tap(find.byType(NotificationBellButton).first);
      await wait(tester);
      await shot('12_notifications');
      await back(tester);
    });
    await step('meal log', () async {
      await tester.tap(find.text('식단 기록').first);
      await wait(tester);
      await shot('13_meal_log');
      await back(tester);
    });
    await step('nutrition guide', () async {
      await tester.tap(find.text('식단 기록').first);
      await wait(tester);
      await tester.tap(find.text('뭐 먹을지 고민될 때'));
      await wait(tester);
      await shot('13a_nutrition_guide');
      await tester.tap(find.text('단백질'));
      await wait(tester);
      await shot('13b_food_list');
      await tester.tap(find.text('닭가슴살'));
      await wait(tester);
      await shot('13c_food_sheet');
      await tester.tap(find.textContaining('식단에 추가'));
      await wait(tester);
      await shot('13d_meal_input_prefilled');
      // 입력 → 목록 → 가이드 → 식단 기록 순으로 닫는다 (저장하지 않음)
      for (var i = 0; i < 4; i++) {
        await back(tester);
      }
    });
    await step('member scroll', () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await wait(tester, 800);
      await shot('11_member_home_records');
    });
    await step('workout tab', () async {
      await tapNav(tester, '운동');
      await shot('14_workout');
    });
    await step('pt tab', () async {
      await tapNav(tester, 'PT');
      await shot('15_pt_schedule');
    });
    await step('my tab', () async {
      await tapNav(tester, '마이');
      await shot('16_profile');
    });
    await step('stats', () async {
      await tester.tap(find.text('운동 통계').first);
      await wait(tester);
      await shot('17_workout_stats');
      await back(tester);
    });
    await step('feedback', () async {
      final item = find.text('트레이너 피드백').last;
      await tester.scrollUntilVisible(item, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(item);
      await wait(tester);
      await shot('18_feedback');
      await back(tester);
    });

    // ── 트레이너 ──
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'trainer@burnfit.test', password: _password);
    await startApp(tester);
    await shot('20_trainer_home');
    await step('pt record', () async {
      // 예약된 PT 세션 줄 → PT 기록 (개편 전과 같은 동작)
      await tester.tap(find.text('이민지').first);
      await wait(tester);
      await shot('21_pt_record');
      await back(tester);
    });
    await step('member detail', () async {
      // 개인운동 줄 → 회원 상세
      await tester.tap(find.text('이민지').last);
      await wait(tester);
      await shot('25_member_detail');
      await back(tester);
    });
    await step('schedule tab', () async {
      await tapNav(tester, '일정');
      await shot('22_trainer_schedule');
    });
    await step('reserve sheet', () async {
      await tester.tap(iconButton((l) => l.contains('예약') || l.contains('추가')).first);
      await wait(tester);
      await shot('23_reserve_sheet');
      // 진행 시간을 90분으로 늘려 11:00 예약과 겹치게 → 경고·저장 비활성 확인
      await tester.tap(find.textContaining('종료').first);
      await wait(tester, 800);
      await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -108));
      await wait(tester, 1200);
      await shot('23b_reserve_conflict');
      await back(tester);
    });
    await step('trainer my', () async {
      await tapNav(tester, '마이');
      await shot('24_trainer_my');
    });

    // ── 관리자 ──
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'admin@burnfit.test', password: _password);
    await startApp(tester);
    await shot('30_admin_home');
    await step('requests', () async {
      await tester.tap(find.textContaining('가입 신청').first);
      await wait(tester);
      await shot('31_admin_requests');
      await back(tester);
    });
    await step('dashboard', () async {
      await tester.tap(find.text('대시보드').first);
      await wait(tester);
      await shot('32_admin_dashboard');
      await back(tester);
    });
    await step('members tab', () async {
      await tapNav(tester, '회원');
      await shot('33_admin_members');
    });
    await step('trainers tab', () async {
      await tapNav(tester, '트레이너');
      await shot('34_admin_trainers');
    });

    await FirebaseAuth.instance.signOut();
  });
}
