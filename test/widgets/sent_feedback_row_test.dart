import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/models/feedback.dart' as fb;
import 'package:pt_solution_v2/screens/trainer/trainer_sent_feedback_screen.dart';

fb.Feedback _feedback({
  fb.FeedbackTargetType type = fb.FeedbackTargetType.meal,
  String? targetDate = '2026-10-13',
  DateTime? readAt,
  DateTime? updatedAt,
}) {
  final created = DateTime(2026, 10, 13, 12);
  return fb.Feedback(
    id: 'f1',
    centerId: 'c1',
    trainerId: 't1',
    trainerName: '박코치',
    memberId: 'm1',
    memberName: '김민지',
    targetType: type,
    targetId: type == fb.FeedbackTargetType.general ? null : 'x1',
    targetDate: targetDate,
    content: '단백질 아주 좋아요.',
    readAt: readAt,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<void> pump(WidgetTester tester, fb.Feedback f) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SentFeedbackRow(feedback: f, onMore: () {}),
      ),
    ),
  );

  testWidgets('종류 · 대상 날짜 · 안 읽음', (tester) async {
    await pump(tester, _feedback());
    expect(find.textContaining('식단'), findsOneWidget);
    expect(find.textContaining('10월 13일'), findsOneWidget);
    expect(find.textContaining('안 읽음'), findsOneWidget);
    expect(find.textContaining('수정됨'), findsNothing);
  });

  testWidgets('고친 뒤 읽음', (tester) async {
    await pump(
      tester,
      _feedback(
        updatedAt: DateTime(2026, 10, 13, 13),
        readAt: DateTime(2026, 10, 13, 14),
      ),
    );
    expect(find.textContaining('수정됨'), findsOneWidget);
    expect(find.textContaining('읽음'), findsOneWidget);
    expect(find.textContaining('안 읽음'), findsNothing);
  });

  testWidgets('전체 피드백은 기록 날짜 대신 보낸 날', (tester) async {
    await pump(
      tester,
      _feedback(type: fb.FeedbackTargetType.general, targetDate: null),
    );
    expect(find.textContaining('전체'), findsOneWidget);
    expect(find.textContaining('10월 13일'), findsOneWidget);
  });
}
