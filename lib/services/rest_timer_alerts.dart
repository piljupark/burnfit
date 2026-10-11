import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/app_haptics.dart';
import '../core/app_logger.dart';
import 'workout_reminder.dart';

enum RestAlertKind { warning, done }

/// 휴식 타이머 알림 (기기 안 알림, 서버를 거치지 않는다). 시각 계산은 [RestTimer]가 한다.
///
/// - 앱이 앞에 있을 때: [RestTimer]가 10초 전·끝을 직접 알린다 ([fireNow] — 진동, 안드로이드는 알림도).
/// - 앱이 뒤로 갈 때: 10초 전·끝 알림을 예약해 두고([scheduleFor]), 앞으로 돌아오면 지운다
///   ([cancelScheduled]). 앱이 잠들어 있어도 휴대폰이 알려 준다.
/// - 휴식 중 진행 표시([showOngoing]): 안드로이드는 알림 센터에 줄어드는 남은 시간,
///   아이폰(16.2+)은 잠금 화면 · 다이내믹 아일랜드 실시간 현황 (`ios/RestTimerWidget`,
///   다리는 `ios/Runner/RestTimerActivityPlugin.swift`).
///
/// 알림 권한·초기화는 [WorkoutReminder]가 맡는다 (같은 기기 알림 묶음).
class RestTimerAlerts {
  RestTimerAlerts._();

  static const int _ongoingId = 7100;
  static const int _warningId = 7101;
  static const int _doneId = 7102;
  static const String _payload = 'rest_timer';

  /// 10초 전 알림까지 남은 초.
  static const int warningSeconds = 10;

  static FlutterLocalNotificationsPlugin get _plugin => WorkoutReminder.plugin;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const _activity = MethodChannel('refit/rest_activity');

  /// 아이폰 실시간 현황 (16.2 미만 · 꺼 둔 경우 네이티브가 무시한다).
  static Future<void> _iosActivity(String method, [Object? args]) async {
    if (!_ios) return;
    try {
      await _activity.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // 테스트 · 다른 플랫폼
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 실시간 현황 $method 실패: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // 채널은 한 번 만들면 진동 모양을 바꿀 수 없다 — 바꾸려면 채널 ID를 새로 짓는다.
  static AndroidNotificationDetails _androidAlert(RestAlertKind kind) =>
      switch (kind) {
        RestAlertKind.warning => AndroidNotificationDetails(
          'rest_timer_warning',
          '휴식 10초 전',
          channelDescription: '휴식이 10초 남았을 때 짧게 알려 줍니다.',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 300]),
          timeoutAfter: 10 * 1000,
          category: AndroidNotificationCategory.reminder,
        ),
        RestAlertKind.done => AndroidNotificationDetails(
          'rest_timer_done',
          '휴식 끝',
          channelDescription: '휴식이 끝나면 세게 진동합니다.',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 700]),
          timeoutAfter: 60 * 1000,
          category: AndroidNotificationCategory.alarm,
        ),
      };

  static NotificationDetails _details(RestAlertKind kind) =>
      NotificationDetails(
        android: _androidAlert(kind),
        iOS: const DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      );

  static int _id(RestAlertKind kind) =>
      kind == RestAlertKind.warning ? _warningId : _doneId;

  static String _title(RestAlertKind kind) =>
      kind == RestAlertKind.warning ? '휴식 10초 남음' : '휴식 끝';

  static String _body(RestAlertKind kind) =>
      kind == RestAlertKind.warning ? '다음 세트를 준비하세요.' : '다음 세트를 시작하세요.';

  /// 앱이 앞에 있을 때 바로 알린다.
  static Future<void> fireNow(RestAlertKind kind) async {
    if (kind == RestAlertKind.warning) {
      AppHaptics.restWarning();
    } else {
      AppHaptics.restDone();
    }
    // 안드로이드는 알림 채널의 진동이 화면 안 진동보다 세다.
    if (!_android || !WorkoutReminder.isReady) return;
    try {
      // 같은 알림이 예약돼 있었다면 지워 두 번 울리지 않게 한다.
      await _plugin.cancel(id: _id(kind));
      await _plugin.show(
        id: _id(kind),
        title: _title(kind),
        body: _body(kind),
        payload: _payload,
        notificationDetails: _details(kind),
      );
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 알림 실패: $e');
    }
  }

  /// 앱이 뒤로 갈 때: [endAt]에 끝 알림, 그 10초 전에 미리 알림을 예약한다.
  static Future<void> scheduleFor(DateTime endAt) async {
    if (!WorkoutReminder.isReady) return;
    final now = DateTime.now();
    final mode = await _scheduleMode();
    final warningAt = endAt.subtract(const Duration(seconds: warningSeconds));
    for (final (kind, at) in [
      (RestAlertKind.warning, warningAt),
      (RestAlertKind.done, endAt),
    ]) {
      if (!at.isAfter(now.add(const Duration(milliseconds: 500)))) continue;
      try {
        await _plugin.zonedSchedule(
          id: _id(kind),
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          title: _title(kind),
          body: _body(kind),
          payload: _payload,
          notificationDetails: _details(kind),
          androidScheduleMode: mode,
        );
      } catch (e) {
        AppLogger.debug('[RestTimerAlerts] 예약 실패: $e');
      }
    }
  }

  /// 예약만 지운다 (이미 뜬 알림은 [clearAll]).
  static Future<void> cancelScheduled() async {
    if (!WorkoutReminder.isReady) return;
    try {
      await _plugin.cancel(id: _warningId);
      await _plugin.cancel(id: _doneId);
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 취소 실패: $e');
    }
  }

  /// 휴식을 건너뛰거나 끝난 뒤 앱에 돌아왔을 때: 예약 · 진행 표시 · 뜬 알림 모두 지운다.
  static Future<void> clearAll() async {
    await _iosActivity('end');
    if (!WorkoutReminder.isReady) return;
    try {
      await _plugin.cancel(id: _ongoingId);
      await _plugin.cancel(id: _warningId);
      await _plugin.cancel(id: _doneId);
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 지우기 실패: $e');
    }
  }

  static Future<void> clearOngoing() async {
    await _iosActivity('end');
    if (!_android || !WorkoutReminder.isReady) return;
    try {
      await _plugin.cancel(id: _ongoingId);
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 진행 표시 지우기 실패: $e');
    }
  }

  /// 휴식 중 진행 표시. 시스템이 남은 시간을 직접 세므로 앱이 잠들어도 줄어든다.
  /// 안드로이드는 알림 센터의 '휴식 중' 줄, 아이폰은 잠금 화면 · 다이내믹 아일랜드.
  static Future<void> showOngoing(DateTime startAt, DateTime endAt) async {
    await _iosActivity('show', {
      'startAt': startAt.millisecondsSinceEpoch,
      'endAt': endAt.millisecondsSinceEpoch,
    });
    if (!_android || !WorkoutReminder.isReady) return;
    final left = endAt.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) return;
    try {
      await _plugin.show(
        id: _ongoingId,
        title: '휴식 중',
        body: '휴식이 끝나면 진동으로 알려 드려요.',
        payload: _payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer_ongoing',
            '휴식 타이머 진행',
            channelDescription: '휴식 중 남은 시간을 알림 센터에 보여 줍니다.',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showWhen: true,
            when: endAt.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: left,
            category: AndroidNotificationCategory.stopwatch,
          ),
        ),
      );
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 진행 표시 실패: $e');
    }
  }

  /// 안드로이드 12+에서 정확한 시각 알림 권한이 있으면 정확히, 없으면 근사로 (몇 분 늦을 수 있다).
  static Future<AndroidScheduleMode> _scheduleMode() async {
    if (!_android) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await _canScheduleExact();
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<bool> _canScheduleExact() async {
    try {
      return await _androidPlugin?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  static const _askedKey = 'rest_timer_exact_alarm_asked';

  /// 안드로이드에서 '알람 및 리마인더' 권한이 꺼져 있고 아직 한 번도 묻지 않았으면 true.
  static Future<bool> shouldAskExactPermission() async {
    if (!_android || !WorkoutReminder.isReady) return false;
    if (await _canScheduleExact()) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return false;
      await prefs.setBool(_askedKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 시스템 설정의 '알람 및 리마인더' 화면을 연다.
  static Future<void> requestExactPermission() async {
    try {
      await _androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      AppLogger.debug('[RestTimerAlerts] 권한 요청 실패: $e');
    }
  }
}
