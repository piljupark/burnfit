import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../core/service_validator.dart';

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
  static GlobalKey<ScaffoldMessengerState>? _messengerKey;
  static StreamSubscription<String>? _tokenRefreshSub;

  // ── 초기화 (앱 시작 시 1회 호출) ──

  static Future<void> initialize({
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) async {
    _messengerKey = messengerKey;

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

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
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
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
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body.isNotEmpty) ...[const SizedBox(height: 2), Text(body)],
            ],
          ),
        ),
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
