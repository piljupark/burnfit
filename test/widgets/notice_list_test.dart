import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/notice.dart';
import 'package:pt_solution_v2/screens/common/notice_list_screen.dart';
import 'package:pt_solution_v2/widgets/notice_widgets.dart';

Notice _n(String id, String title, {bool pinned = false}) => Notice(
  id: id,
  centerId: 'c1',
  title: title,
  body: '$title 본문',
  audience: NoticeAudience.all,
  pinned: pinned,
  important: false,
  authorId: 'a',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  testWidgets('고정 섹션과 전체 섹션을 나눠 보여주고 누르면 상세로 간다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: NoticeListScreen(
          loader: () async => [
            _n('p', '운영 시간 변경', pinned: true),
            _n('a', '추석 휴관 안내'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('고정된 공지'), findsOneWidget);
    expect(find.text('전체 공지'), findsOneWidget);
    expect(find.byType(NoticeTile), findsNWidgets(2));
    expect(find.byIcon(noticePinIcon), findsOneWidget);

    await tester.tap(find.text('추석 휴관 안내'));
    await tester.pumpAndSettle();
    expect(find.text('추석 휴관 안내 본문'), findsOneWidget);
  });

  testWidgets('공지가 없으면 빈 상태', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: NoticeListScreen(loader: () async => [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 공지가 없어요'), findsOneWidget);
  });
}
