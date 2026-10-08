import 'package:shared_preferences/shared_preferences.dart';

import '../models/notice.dart';

/// 공지 읽음 상태 (기기 로컬). 사용자별로 마지막으로 본 공지 시각과
/// '다시 보지 않기'/확인한 중요 공지 ID를 저장한다.
class NoticeReadStore {
  NoticeReadStore._();

  static String _seenKey(String uid) => 'notice_last_seen_$uid';
  static String _sheetKey(String uid, String id) =>
      'notice_sheet_shown_${uid}_$id';

  static Future<DateTime?> lastSeen(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_seenKey(uid));
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markSeen(String uid, List<Notice> items) async {
    final latest = latestCreatedAt(items);
    if (latest == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prev = prefs.getInt(_seenKey(uid)) ?? 0;
      if (latest.millisecondsSinceEpoch > prev) {
        await prefs.setInt(_seenKey(uid), latest.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  static DateTime? latestCreatedAt(List<Notice> items) {
    DateTime? latest;
    for (final n in items) {
      final c = n.createdAt;
      if (c != null && (latest == null || c.isAfter(latest))) latest = c;
    }
    return latest;
  }

  /// 마지막으로 본 시각 이후에 올라온 공지 수.
  static int unreadCount(List<Notice> items, DateTime? lastSeen) {
    return items
        .where(
          (n) =>
              n.createdAt != null &&
              (lastSeen == null || n.createdAt!.isAfter(lastSeen)),
        )
        .length;
  }

  static Future<bool> wasSheetShown(String uid, String noticeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_sheetKey(uid, noticeId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSheetShown(String uid, String noticeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sheetKey(uid, noticeId), true);
    } catch (_) {}
  }
}
