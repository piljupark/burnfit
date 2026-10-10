import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_logger.dart';
import '../core/workout_timing.dart';
import 'fcm_service.dart';
import 'notification_target.dart';

/// 개인 운동 '마치셨나요?' 리마인드 (기기 안에서 예약하는 알림, 서버를 거치지 않는다).
///
/// 세트를 완료할 때마다 [workoutReminderDelay] 뒤로 다시 예약하고, 저장하거나 운동을 비우면 지운다.
/// 알림을 누르면 회원 운동 탭으로 간다 ([FcmService.pendingTarget]에 [NotificationTarget.workout]).
/// 알림 권한은 앱 시작 때 [FcmService]가 받는다 — 여기서는 다시 묻지 않는다.
class WorkoutReminder {
  WorkoutReminder._();

  static const int _notificationId = 7001;
  static const String _payload = 'workout';
  static const String _channelId = 'workout_reminder';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// 앱 시작 때 한 번. 실패해도 앱은 그대로 쓴다 (리마인드만 오지 않는다).
  static Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _open,
      );
      // 앱이 꺼진 상태에서 이 알림을 눌러 열린 경우
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _open(response);
      }
      _ready = true;
    } catch (e) {
      AppLogger.debug('[WorkoutReminder] 초기화 실패: $e');
    }
  }

  static void _open(NotificationResponse response) {
    if (response.payload == _payload) {
      FcmService.pendingTarget.value = NotificationTarget.workout;
    }
  }

  /// 마지막 세트를 완료한 때([lastSetAt])로부터 [workoutReminderDelay] 뒤에 알린다. 이전 예약은 바꾼다.
  static Future<void> scheduleAfterSet(DateTime lastSetAt) async {
    if (!_ready) return;
    final at = lastSetAt.add(workoutReminderDelay);
    if (!at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        // 정해진 순간이면 되므로 시간대는 UTC로 계산한다 (기기 시간대 정보가 필요 없다).
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        title: '운동 마치셨나요?',
        body: '눌러서 오늘 운동을 저장하세요.',
        payload: _payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '운동 리마인드',
            channelDescription: '개인 운동을 마치지 않았을 때 알려 줍니다.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // 정확한 시각 권한 없이 예약한다 (몇 분 늦을 수 있다).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      AppLogger.debug('[WorkoutReminder] 예약 실패: $e');
    }
  }

  static Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      AppLogger.debug('[WorkoutReminder] 취소 실패: $e');
    }
  }
}
