// 관리자 저장 흐름 점검: 앱이 보내는 실제 데이터가 보안 규칙을 통과하는지 에뮬레이터에서 확인한다.
//
// 준비: Firebase 에뮬레이터 실행 + 예시 데이터 (functions/integration/seed_screens.js)
// 실행:
//   flutter drive -d <iOS 시뮬레이터> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/admin_flow_test.dart \
//     --dart-define=USE_FIREBASE_EMULATOR=true
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pt_solution_v2/core/app_icons.dart';
import 'package:pt_solution_v2/main.dart';
import 'package:pt_solution_v2/widgets/app_nav_bar.dart';

const _password = 'password123';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, [int ms = 2500]) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('관리자: PT 등록 · 담당 배정 · PT 수정 · 가입 승인', (tester) async {
    await bootstrapApp(withMessaging: false);
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@burnfit.test',
      password: _password,
    );
    await tester.pumpWidget(PtSolutionApp(key: UniqueKey()));
    await wait(tester, 4000);

    final db = FirebaseFirestore.instance;
    final newbie = await db
        .collection('users')
        .where('email', isEqualTo: 'newbie@burnfit.test')
        .where('centerId', isEqualTo: 'center-gangnam')
        .get();
    final newbieUid = newbie.docs.single.id;

    // ── 회원 탭 → 신입회원 (PT 없음) ──
    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text('회원')),
    );
    await wait(tester);
    await tester.tap(find.text('신입회원').first);
    await wait(tester);

    // 총 횟수 +3 (남은 횟수도 함께 늘어난다)
    final plus = find.byIcon(AppIcons.bold(AppIcons.add));
    for (var i = 0; i < 3; i++) {
      await tester.tap(plus.first);
      await tester.pump(const Duration(milliseconds: 200));
    }
    // 담당 트레이너 고르기
    await tester.tap(find.text('담당 트레이너'));
    await wait(tester, 1500);
    await tester.tap(find.text('김도윤').last);
    await wait(tester, 1500);
    await tester.tap(find.text('저장'));
    await wait(tester, 4000);

    final created = await db.collection('pt_infos').doc(newbieUid).get();
    expect(created.exists, isTrue, reason: '새 PT권은 회원 ID 문서로 만들어진다');
    expect(created.data()!['totalSessions'], 3);
    expect(created.data()!['remainingSessions'], 3);
    final user = await db.collection('users').doc(newbieUid).get();
    expect(user.data()!['trainerName'], '김도윤');

    Future<List<String>> logTypes() async {
      final logs = await db
          .collection('pt_info_logs')
          .where('centerId', isEqualTo: 'center-gangnam')
          .where('memberId', isEqualTo: newbieUid)
          .get();
      return logs.docs.map((d) => d.data()['type'] as String).toList();
    }

    expect(await logTypes(), containsAll(['trainerChanged', 'created']));

    // ── 같은 회원 PT 수정: 총 +1, 변경 사유 필수 ──
    await tester.tap(plus.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).last, '추가 결제 1회');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('저장'));
    await wait(tester, 4000);

    final updated = await db.collection('pt_infos').doc(newbieUid).get();
    expect(updated.data()!['totalSessions'], 4);
    expect(updated.data()!['remainingSessions'], 4);
    expect(await logTypes(), contains('updated'));

    // ── 홈 → 가입 요청 → 첫 요청 승인 ──
    Navigator.of(tester.element(find.text('신입회원').first)).pop();
    await wait(tester, 1500);
    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text('홈')),
    );
    await wait(tester);
    await tester.tap(find.textContaining('가입 요청').first);
    await wait(tester);
    final pendingBefore = await db
        .collection('join_requests')
        .where('centerId', isEqualTo: 'center-gangnam')
        .where('status', isEqualTo: 'pending')
        .get();
    await tester.tap(find.text('승인').first);
    await wait(tester, 4000);
    final pendingAfter = await db
        .collection('join_requests')
        .where('centerId', isEqualTo: 'center-gangnam')
        .where('status', isEqualTo: 'pending')
        .get();
    expect(pendingAfter.size, pendingBefore.size - 1);
  });
}
