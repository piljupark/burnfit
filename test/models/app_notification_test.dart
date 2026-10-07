import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/app_notification.dart';
import 'package:pt_solution_v2/services/notification_service.dart';
import 'package:pt_solution_v2/services/notification_target.dart';

void main() {
  test('알림함 문서를 읽고, 눌렀을 때 갈 화면을 정한다', () {
    final item = AppNotification.fromMap('n1', {
      'type': 'feedback_created',
      'title': '김트 트레이너가 피드백을 남겼습니다',
      'body': '식단 기록에 새 피드백',
      'targetId': 'f1',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 7)),
      'readAt': null,
    });
    expect(item.isRead, isFalse);
    expect(item.target, NotificationTarget.feedback);
    expect(item.targetId, 'f1');
  });

  test('알 수 없는 종류나 빠진 값이 있어도 읽는다', () {
    final item = AppNotification.fromMap('n2', {
      'type': 'new_type',
      'readAt': 'broken',
    });
    expect(item.target, isNull);
    expect(item.title, '');
    expect(item.createdAt, isNull);
    expect(item.readAt, isNull);
  });

  test('보관 기간 안내가 서버 값과 같다 (functions/notifications.js)', () {
    final source = File('functions/notifications.js').readAsStringSync();
    final match = RegExp(
      r'const INBOX_RETENTION_DAYS = (\d+);',
    ).firstMatch(source);
    expect(match, isNotNull);
    expect(NotificationService.retentionDays, int.parse(match!.group(1)!));
  });
}
