import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/service_validator.dart';
import '../models/notice.dart';
import '../models/user.dart';

/// 센터 공지사항 조회·작성. 권한은 firestore.rules(notices)가 최종 판단한다.
class NoticeService {
  NoticeService._();

  static const int _pageSize = 100;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notices');

  /// 관리자용: 센터의 모든 공지 (고정 먼저, 최신순).
  static Future<List<Notice>> getForAdmin(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    final snap = await _col
        .where('centerId', isEqualTo: centerId)
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();
    return snap.docs.map((d) => Notice.fromMap(d.id, d.data())).toList();
  }

  /// 회원·트레이너용: 전체 + 내 역할 대상 공지 (고정 먼저, 최신순).
  static Future<List<Notice>> getForViewer(
    String centerId,
    UserRole role,
  ) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    final snap = await _col
        .where('centerId', isEqualTo: centerId)
        .where('audience', whereIn: ['all', role.name])
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();
    return sortPinnedFirst(
      snap.docs.map((d) => Notice.fromMap(d.id, d.data())).toList(),
    );
  }

  /// 고정 공지를 앞으로 (각 그룹 안에서는 기존 순서 유지).
  static List<Notice> sortPinnedFirst(List<Notice> items) => [
    ...items.where((n) => n.pinned),
    ...items.where((n) => !n.pinned),
  ];

  static Future<Notice?> get(String id) async {
    ServiceValidator.requireText(id, '공지 ID');
    final doc = await _col.doc(id).get();
    final data = doc.data();
    return data == null ? null : Notice.fromMap(doc.id, data);
  }

  static Future<String> create({
    required String centerId,
    required String authorId,
    required String title,
    required String body,
    required NoticeAudience audience,
    required bool pinned,
    required bool important,
    bool notify = false,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(authorId, '작성자 ID');
    final ref = _col.doc();
    await ref.set({
      'centerId': centerId,
      'authorId': authorId,
      ..._content(title, body, audience, pinned, important),
      'notify': notify,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> update(
    String id, {
    required String title,
    required String body,
    required NoticeAudience audience,
    required bool pinned,
    required bool important,
  }) {
    ServiceValidator.requireText(id, '공지 ID');
    return _col.doc(id).update({
      ..._content(title, body, audience, pinned, important),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) {
    ServiceValidator.requireText(id, '공지 ID');
    return _col.doc(id).delete();
  }

  static Map<String, dynamic> _content(
    String title,
    String body,
    NoticeAudience audience,
    bool pinned,
    bool important,
  ) {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty || t.length > Notice.titleMax) {
      throw ArgumentError('제목은 1~${Notice.titleMax}자로 입력해 주세요');
    }
    if (b.isEmpty || b.length > Notice.bodyMax) {
      throw ArgumentError('내용은 1~${Notice.bodyMax}자로 입력해 주세요');
    }
    return {
      'title': t,
      'body': b,
      'audience': audience.value,
      'pinned': pinned,
      'important': important,
    };
  }
}
