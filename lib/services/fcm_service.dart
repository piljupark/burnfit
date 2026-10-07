import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../widgets/app_toast.dart';
import 'notification_target.dart';

// 백그라운드 메시지 핸들러 — 반드시 top-level 함수여야 함
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // 백그라운드에서는 Flutter 엔진이 별도로 실행되므로
  // UI 업데이트 없이 데이터 처리만 허용
  AppLogger.debug('[FCM] 백그라운드 메시지 수신');
}

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;
  static StreamSubscription<String>? _tokenRefreshSub;

  /// 사용자가 누른 알림이 가리키는 화면. 역할별 홈 화면이 읽고 [takePendingTarget]으로 비운다.
  /// 앱이 꺼진 상태에서 알림으로 열린 경우 로그인·스플래시가 끝날 때까지 여기 보관된다.
  static final ValueNotifier<NotificationTarget?> pendingTarget = ValueNotifier(
    null,
  );

  static NotificationTarget? takePendingTarget() {
    final target = pendingTarget.value;
    pendingTarget.value = null;
    return target;
  }

  static void clearPendingTarget() => pendingTarget.value = null;

  static void _openFromMessage(RemoteMessage message) {
    final target = NotificationTarget.fromData(message.data);
    if (target != null) pendingTarget.value = target;
  }

  // ── 초기화 (앱 시작 시 1회 호출) ──

  static Future<void> initialize() async {
    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // 알림을 눌러 앱이 열린 경우 (백그라운드 → 포그라운드, 종료 상태 → 실행)
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openFromMessage(initialMessage);

    // iOS 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.debug('[FCM] 알림 권한 거부됨');
      return;
    }

    // 포그라운드 알림 표시 설정 (iOS)
    // 앱이 켜져 있을 때는 위쪽 토스트(AppToast)로 보여주므로 iOS 시스템 배너는 끈다 (두 번 뜨지 않게).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    // 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen((message) {
      AppLogger.debug('[FCM] 포그라운드 메시지 수신');
      _showForegroundMessage(message);
    });
  }

  static void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? '새 알림';
    final body = notification?.body ?? '';
    final target = NotificationTarget.fromData(message.data);

    AppToast.show(
      null,
      title: title,
      message: body.isEmpty ? title : body,
      duration: const Duration(seconds: 4),
      actionLabel: target == null ? null : '보기',
      onAction: target == null ? null : () => pendingTarget.value = target,
    );
  }

  // ── FCM 토큰 저장 ──

  static Future<void> saveToken(String uid) async {
    try {
      ServiceValidator.requireText(uid, '사용자 ID');

      final token = await _messaging.getToken();
      if (token == null) return;

      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.debug('[FCM] 토큰 저장 완료');

      // 토큰 갱신 감지
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _db.collection('users').doc(uid).update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger.debug('[FCM] 토큰 갱신 저장 완료');
        } catch (e) {
          AppLogger.debug('[FCM] 토큰 갱신 저장 실패: $e');
        }
      });
    } catch (e) {
      AppLogger.debug('[FCM] 토큰 저장 실패: $e');
    }
  }

  /// 이 기기의 알림 연결만 끊는다 (사용자 문서는 건드리지 않음).
  /// 탈퇴처럼 사용자 문서가 이미 없을 때 쓴다.
  static Future<void> detachDevice() async {
    clearPendingTarget();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      await _messaging.deleteToken();
    } catch (e) {
      AppLogger.debug('[FCM] 기기 토큰 삭제 실패: $e');
    }
  }

  // ── FCM 토큰 삭제 (로그아웃 시) ──

  static Future<void> removeToken(String uid) async {
    try {
      ServiceValidator.requireText(uid, '사용자 ID');

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      await _messaging.deleteToken();
    } catch (e) {
      AppLogger.debug('[FCM] 토큰 삭제 실패: $e');
    }
  }
}
