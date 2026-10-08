import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/app_icons.dart';
import 'package:pt_solution_v2/widgets/app_nav_bar.dart';

void main() {
  const items = [
    AppNavItem(label: '홈', icon: AppIcons.home, activeIcon: AppIcons.homeFill),
    AppNavItem(
      label: '마이',
      icon: AppIcons.profile,
      activeIcon: AppIcons.profileFill,
    ),
  ];

  Future<Rect> pumpBar(WidgetTester tester, double safeBottom) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: EdgeInsets.only(bottom: safeBottom),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppNavBar(currentIndex: 0, onTap: (_) {}, items: items),
            ),
          ),
        ),
      ),
    );
    return tester.getRect(find.byType(AppNavBar));
  }

  testWidgets('안전 영역이 없으면(웹·데스크톱) 아래 여백도 위와 같은 10이다', (tester) async {
    final bar = await pumpBar(tester, 0);
    final label = tester.getRect(find.text('홈'));
    // 위 선(1) 아래 10 ~ 아이콘, 글자 아래 ~ 바닥 10
    expect(bar.height, 1 + AppNavBar.contentHeight + 10);
    expect(bar.bottom - label.bottom, closeTo(10, 0.5));
  });

  testWidgets('홈 표시줄이 있으면 아래 여백은 안전 영역 높이다', (tester) async {
    final bar = await pumpBar(tester, 34);
    expect(bar.height, 1 + AppNavBar.contentHeight + 34);
  });
}
