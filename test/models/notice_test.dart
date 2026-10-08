import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/notice.dart';
import 'package:pt_solution_v2/services/notice_read_store.dart';
import 'package:pt_solution_v2/services/notice_service.dart';
import 'package:pt_solution_v2/services/notification_target.dart';

Notice _n(String id, {bool pinned = false, DateTime? at}) => Notice(
  id: id,
  centerId: 'c1',
  title: id,
  body: 'b',
  audience: NoticeAudience.all,
  pinned: pinned,
  important: false,
  authorId: 'a',
  createdAt: at,
);

void main() {
  group('Notice.fromMap / toContentMap', () {
    test('모든 필드를 읽고 내용 필드만 내보낸다', () {
      final created = DateTime(2026, 10, 1, 9);
      final n = Notice.fromMap('n1', {
        'centerId': 'c1',
        'title': '휴관 안내',
        'body': '추석 휴관',
        'audience': 'trainer',
        'pinned': true,
        'important': true,
        'authorId': 'admin',
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': Timestamp.fromDate(created.add(const Duration(hours: 1))),
      });
      expect(n.id, 'n1');
      expect(n.audience, NoticeAudience.trainer);
      expect(n.pinned, isTrue);
      expect(n.important, isTrue);
      expect(n.createdAt, created);
      expect(n.isEdited, isTrue);
      expect(n.toContentMap(), {
        'title': '휴관 안내',
        'body': '추석 휴관',
        'audience': 'trainer',
        'pinned': true,
        'important': true,
      });
    });

    test('빠진 값·이상한 값은 안전한 기본값', () {
      final n = Notice.fromMap('x', {'audience': 'everyone', 'createdAt': 'not-a-date'});
      expect(n.audience, NoticeAudience.all);
      expect(n.title, '');
      expect(n.pinned, isFalse);
      expect(n.createdAt, isNull);
      expect(n.isEdited, isFalse);
    });
  });

  test('고정 공지를 앞으로, 그룹 안 순서는 유지', () {
    final sorted = NoticeService.sortPinnedFirst([
      _n('a'),
      _n('b', pinned: true),
      _n('c'),
      _n('d', pinned: true),
    ]);
    expect(sorted.map((n) => n.id), ['b', 'd', 'a', 'c']);
  });

  test('마지막으로 본 시각 이후 글만 새 글로 센다', () {
    final items = [
      _n('a', at: DateTime(2026, 10, 1)),
      _n('b', at: DateTime(2026, 10, 3)),
      _n('c'),
    ];
    expect(NoticeReadStore.unreadCount(items, null), 2);
    expect(NoticeReadStore.unreadCount(items, DateTime(2026, 10, 2)), 1);
    expect(NoticeReadStore.latestCreatedAt(items), DateTime(2026, 10, 3));
  });

  test('공지 알림은 공지 목록으로 이동한다', () {
    expect(
      NotificationTarget.fromData({'type': 'notice_created'}),
      NotificationTarget.notices,
    );
  });
}
