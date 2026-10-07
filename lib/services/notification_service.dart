import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/service_validator.dart';
import '../models/app_notification.dart';

/// 알림함 조회·읽음 처리·삭제. 알림을 만드는 것은 서버 함수만 한다.
class NotificationService {
  NotificationService._();

  /// 알림함 보관 기간(일). 서버 값과 같아야 한다 (functions/notifications.js `INBOX_RETENTION_DAYS`).
  static const int retentionDays = 90;

  static const int _pageSize = 50;
  static const int _unreadCountCap = 99;

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _inbox(String uid) {
    ServiceValidator.requireText(uid, '사용자 ID');
    return _db.collection('users').doc(uid).collection('notifications');
  }

  /// 안 읽은 알림 수 (실시간). 표시는 99+까지만 하므로 그 이상은 세지 않는다.
  static Stream<int> watchUnreadCount(String uid) {
    return _inbox(uid)
        .where('readAt', isNull: true)
        .limit(_unreadCountCap + 1)
        .snapshots()
        .map((snap) => snap.size);
  }

  static Future<List<AppNotification>> getRecent(String uid) async {
    final snap = await _inbox(
      uid,
    ).orderBy('createdAt', descending: true).limit(_pageSize).get();
    return snap.docs
        .map((d) => AppNotification.fromMap(d.id, d.data()))
        .toList();
  }

  static Future<void> markRead(String uid, Iterable<String> ids) async {
    final unique = ids.toSet();
    if (unique.isEmpty) return;
    final inbox = _inbox(uid);
    final batch = _db.batch();
    for (final id in unique) {
      batch.update(inbox.doc(id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  static Future<void> delete(String uid, String id) =>
      _inbox(uid).doc(id).delete();
}
