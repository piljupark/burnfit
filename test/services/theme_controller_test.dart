import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/app_colors.dart';
import 'package:pt_solution_v2/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) =>
      Container(key: const Key('probe'), color: AppColors.canvas);
}

void main() {
  final controller = ThemeController.instance;

  tearDown(() async {
    await controller.select(ThemeController.defaultChoice);
    AppColors.palette = AppPalette.light;
  });

  testWidgets('저장된 선택이 없으면 라이트로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await controller.load();
    expect(controller.choice, AppThemeChoice.light);
    expect(AppColors.palette, same(AppPalette.light));
  });

  testWidgets('저장된 다크 선택을 불러온다', (tester) async {
    SharedPreferences.setMockInitialValues({'app_theme_choice': 'dark'});
    await controller.load();
    expect(controller.choice, AppThemeChoice.dark);
    expect(AppColors.canvas, AppPalette.dark.canvas);
  });

  testWidgets('선택을 바꾸면 저장하고 const 위젯도 새 색으로 다시 그린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await controller.load();
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: _Probe()),
    );
    Color probeColor() =>
        tester.widget<Container>(find.byKey(const Key('probe'))).color!;
    expect(probeColor(), AppPalette.light.canvas);

    await controller.select(AppThemeChoice.dark);
    await tester.pump();
    expect(probeColor(), AppPalette.dark.canvas);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_choice'), 'dark');
  });
}
