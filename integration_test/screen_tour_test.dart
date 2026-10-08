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
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pt_solution_v2/main.dart';
import 'package:pt_solution_v2/screens/member/workout_sheets.dart';
import 'package:pt_solution_v2/services/theme_controller.dart';
import 'package:pt_solution_v2/widgets/app_icon_button.dart';
import 'package:pt_solution_v2/widgets/app_nav_bar.dart';
import 'package:pt_solution_v2/widgets/notification_bell_button.dart';

const _password = 'password123';
const _tourTheme = String.fromEnvironment('TOUR_THEME', defaultValue: 'light');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, [int ms = 2500]) async {
    // 로딩 점이 계속 움직이므로 pumpAndSettle 대신 일정 시간만 그린다.
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
    // 앱 Navigator는 전역 키(appNavigatorKey)를 쓰므로, 이전 앱을 완전히 내린 뒤 새로 띄운다
    // (바로 바꾸면 이전 화면 스택이 새 앱으로 옮겨진다).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(PtSolutionApp(key: UniqueKey()));
    await wait(tester, 4000);
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
    );
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
    // 기본(라이트)으로 찍는다. --dart-define=TOUR_THEME=dark 이면 전체 투어를 다크로 찍는다.
    await ThemeController.instance.select(
      _tourTheme == 'dark' ? AppThemeChoice.dark : AppThemeChoice.light,
    );

    // ── 로그인 ──
    await startApp(tester);
    await shot('00_login');

    // ── 회원 ──
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'member@burnfit.test',
      password: _password,
    );
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
      // 홈 바로가기 8칸의 '식단'
      await tester.tap(find.text('식단').first);
      await wait(tester);
      await shot('13_meal_log');
      await step('meal type sheet', () async {
        await tester.tap(find.text('아침').first);
        await wait(tester);
        await shot('13e_meal_type_sheet');
        await back(tester);
      });
      await back(tester);
    });
    await step('nutrition guide', () async {
      await tester.tap(find.text('식단').first);
      await wait(tester);
      await tester.tap(find.text('알아보기'));
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
    await step('home calendar view', () async {
      await tester.tap(find.text('캘린더').first);
      await wait(tester);
      await shot('11_member_home_calendar');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await wait(tester, 800);
      await shot('11b_member_home_records');
      // 위로 되돌려 보기 고르기 버튼이 다시 보이게 한다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
      await wait(tester, 800);
      await tester.tap(find.text('기록').first);
      await wait(tester);
      await shot('11c_member_home_record_list');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
      await tester.tap(find.text('오늘').first);
      await wait(tester);
    });
    await step('workout tab', () async {
      await tapNav(tester, '운동');
      await shot('14_workout');
    });
    await step('workout recording', () async {
      await tester.tap(find.text('종목 추가'));
      await wait(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ExercisePickerSheet),
              matching: find.textContaining('벤치'),
            )
            .first,
      );
      await wait(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '60');
      await tester.enterText(fields.at(1), '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await wait(tester, 600);
      await tester.tap(find.bySemanticsLabel('1세트 완료'));
      await wait(tester, 1500);
      await shot('14a_workout_recording');
      await tester.tap(find.text('운동 마치기'));
      await wait(tester, 3000);
      await shot('14b_workout_done');
      await tester.tap(find.text('확인'));
      await wait(tester);
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
    await step('profile detail', () async {
      await tester.tap(find.text('신체 정보').first);
      await wait(tester);
      await shot('16b_profile_detail');
      await back(tester);
    });
    await step('feedback', () async {
      // 트레이너 피드백은 홈 바로가기 '피드백'
      await tapNav(tester, '홈');
      await tester.tap(find.text('피드백').first);
      await wait(tester);
      await shot('18_feedback');
      await back(tester);
    });

    // ── 트레이너 ──
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'trainer@burnfit.test',
      password: _password,
    );
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
      await tester.tap(
        iconButton((l) => l.contains('예약') || l.contains('추가')).first,
      );
      await wait(tester);
      await shot('23_reserve_sheet');
      // 진행 시간을 90분으로 늘려 11:00 예약과 겹치게 → 경고·저장 비활성 확인
      await tester.tap(find.textContaining('종료').first);
      await wait(tester, 800);
      await tester.drag(
        find.byType(CupertinoPicker).first,
        const Offset(0, -108),
      );
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
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@burnfit.test',
      password: _password,
    );
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
    await step('trainer sheet', () async {
      await tester.tap(find.text('김도윤').first);
      await wait(tester);
      await shot('35_admin_trainer_sheet');
      await back(tester);
    });
    await step('admin my', () async {
      await tapNav(tester, '마이');
      await shot('36_admin_my');
    });

    // ── 다른 테마 (마이 → 화면 테마에서 바꾼다): 기본이 라이트면 다크로 몇 장 ──
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'member@burnfit.test',
      password: _password,
    );
    await startApp(tester);
    await step('theme sheet', () async {
      await tapNav(tester, '마이');
      // 탭 바에 가리지 않게 줄을 화면 안으로 올린다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await wait(tester, 600);
      await tester.tap(find.text('화면 테마'));
      await wait(tester, 1200);
      final other = _tourTheme == 'dark' ? '라이트' : '다크';
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(other),
        ),
      );
      await wait(tester, 1200);
      await shot('40_alt_theme_sheet');
      await back(tester);
      await shot('41_alt_my');
    });
    for (final (label, name) in [
      ('홈', '42_alt_home'),
      ('운동', '43_alt_workout'),
      ('PT', '44_alt_pt'),
    ]) {
      await step('alt $label', () async {
        await tapNav(tester, label);
        await shot(name);
      });
    }
    await step('alt meal log', () async {
      await tapNav(tester, '홈');
      await tester.tap(find.text('식단').first);
      await wait(tester);
      await shot('45_alt_meal_log');
      await back(tester);
    });
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'trainer@burnfit.test',
      password: _password,
    );
    await startApp(tester);
    await shot('46_alt_trainer_home');
    await step('alt schedule', () async {
      await tapNav(tester, '일정');
      await shot('47_alt_trainer_schedule');
      await tester.tap(
        iconButton((l) => l.contains('예약') || l.contains('추가')).first,
      );
      await wait(tester);
      await shot('48_alt_reserve_sheet');
      await back(tester);
    });
    await FirebaseAuth.instance.signOut();
    await startApp(tester);
    await shot('49_alt_login');
    // 다음 실행을 위해 기본 테마로 되돌린다.
    await ThemeController.instance.select(ThemeController.defaultChoice);

    await FirebaseAuth.instance.signOut();
  });
}
