import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../core/app_logger.dart';
import '../core/app_theme.dart';

/// 화면 테마 선택. 기기에만 저장한다 (계정과 무관한 보기 설정).
enum AppThemeChoice {
  system('시스템 설정'),
  light('라이트'),
  dark('다크');

  final String label;

  const AppThemeChoice(this.label);
}

/// 테마 전환: 선택 저장 → 팔레트 교체([AppColors.palette]) → 화면 전체 다시 그리기.
///
/// 색 토큰은 정적 getter라 `const` 위젯은 스스로 다시 그려지지 않는다. 그래서 바뀔 때
/// 모든 Element를 다시 빌드·다시 칠하게 한다 (화면 상태·스크롤·입력은 유지된다).
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_choice';

  /// 기본은 라이트. 다크·시스템 설정은 사용자가 마이 → 화면 테마에서 고른다.
  static const defaultChoice = AppThemeChoice.light;

  AppThemeChoice _choice = defaultChoice;
  bool _observing = false;

  AppThemeChoice get choice => _choice;

  /// 앱 시작 전에 한 번: 저장된 선택을 읽어 첫 화면부터 맞는 색으로 그린다.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _choice = AppThemeChoice.values.firstWhere(
        (c) => c.name == saved,
        orElse: () => defaultChoice,
      );
    } catch (e) {
      AppLogger.debug('[Theme] 저장된 테마를 읽지 못함: $e');
    }
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _apply(rebuild: false);
  }

  Future<void> select(AppThemeChoice choice) async {
    if (choice == _choice) return;
    _choice = choice;
    _apply();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, choice.name);
    } catch (e) {
      AppLogger.debug('[Theme] 테마 저장 실패: $e');
    }
  }

  /// '시스템 설정'일 때 기기 다크 모드가 바뀌면 따라간다.
  @override
  void didChangePlatformBrightness() {
    if (_choice == AppThemeChoice.system) _apply();
  }

  AppPalette _resolve() {
    switch (_choice) {
      case AppThemeChoice.light:
        return AppPalette.light;
      case AppThemeChoice.dark:
        return AppPalette.dark;
      case AppThemeChoice.system:
        final platform =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return platform == Brightness.light
            ? AppPalette.light
            : AppPalette.dark;
    }
  }

  void _apply({bool rebuild = true}) {
    final next = _resolve();
    final changed = !identical(next, AppColors.palette);
    AppColors.palette = next;
    SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
    if (!changed) return;
    notifyListeners();
    if (rebuild) _rebuildAll();
  }

  static void _rebuildAll() {
    void visit(Element element) {
      element.markNeedsBuild();
      if (element is RenderObjectElement) element.renderObject.markNeedsPaint();
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}
