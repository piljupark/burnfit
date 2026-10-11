import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// 앱 진동 (화면 안에서 손에 느껴지는 반응). 마이 → 계정 '진동'으로 끄고 켠다. 기기에만 저장.
///
/// 쓰는 곳을 늘릴 때는 아래 종류 중에서 고른다 (같은 동작은 같은 세기).
/// - [selection] 탭 바꾸기 · 고르기
/// - [light] 가벼운 누름 (세트 추가 등)
/// - [success] 세트 완료 · 저장 완료
/// - [warning] 삭제 확인 · 오류
/// - [restWarning] 휴식 10초 전 · [restDone] 휴식 끝 (세게 세 번)
///
/// 휴식 알림 진동([restWarning] · [restDone])은 알림이므로 이 설정과 무관하게 울린다.
/// 앱이 뒤에 있을 때의 휴식 알림은 기기 알림이 맡는다 (`RestTimerAlerts`).
class AppHaptics {
  AppHaptics._();

  static const _prefsKey = 'app_haptics_enabled';

  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  /// 앱 시작 전에 한 번.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_prefsKey) ?? true;
    } catch (e) {
      AppLogger.debug('[Haptics] 설정을 읽지 못함: $e');
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    if (value) HapticFeedback.mediumImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      AppLogger.debug('[Haptics] 설정 저장 실패: $e');
    }
  }

  static bool get _on => enabled.value && !kIsWeb;

  static void selection() {
    if (_on) HapticFeedback.selectionClick();
  }

  static void light() {
    if (_on) HapticFeedback.lightImpact();
  }

  static void success() {
    if (_on) HapticFeedback.mediumImpact();
  }

  static void warning() {
    if (_on) HapticFeedback.heavyImpact();
  }

  static void restWarning() {
    if (!kIsWeb) HapticFeedback.heavyImpact();
  }

  /// 휴식 끝: 긴 진동 세 번 (0.5초 간격).
  static Future<void> restDone() async {
    if (kIsWeb) return;
    for (var i = 0; i < 3; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 500));
      HapticFeedback.vibrate();
    }
  }
}
