import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/services/notification_target.dart';

void main() {
  group('NotificationTarget.fromData', () {
    test('피드백 알림은 피드백 화면으로 보낸다', () {
      expect(
        NotificationTarget.fromData({'type': 'feedback_created', 'feedbackId': 'f1'}),
        NotificationTarget.feedback,
      );
    });

    test('PT 관련 알림은 모두 PT 일정으로 보낸다', () {
      for (final type in [
        'pt_session_created',
        'pt_session_updated',
        'pt_session_cancelled',
        'pt_remaining_warning',
      ]) {
        expect(
          NotificationTarget.fromData({'type': type}),
          NotificationTarget.ptSchedule,
          reason: type,
        );
      }
    });

    test('알 수 없거나 없는 type은 무시한다', () {
      expect(NotificationTarget.fromData({'type': 'unknown'}), isNull);
      expect(NotificationTarget.fromData({}), isNull);
      expect(NotificationTarget.fromData({'type': 3}), isNull);
    });

    test('서버가 보내는 모든 type을 처리한다 (functions/index.js와 동기화)', () {
      final source = File('functions/index.js').readAsStringSync();
      final sentTypes = RegExp(r"type: '([a-z_]+)'")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      expect(sentTypes, isNotEmpty);
      for (final type in sentTypes) {
        expect(
          NotificationTarget.fromData({'type': type}),
          isNotNull,
          reason: 'functions/index.js가 보내는 "$type" 알림을 눌러도 이동할 곳이 없습니다',
        );
      }
    });
  });
}
