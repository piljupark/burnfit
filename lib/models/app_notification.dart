import '../core/firestore_date.dart';
import '../services/notification_target.dart';

/// 알림함 항목 (users/{uid}/notifications). 서버 함수 notifyUser가 만든다.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? targetId;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.targetId,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  /// 눌렀을 때 이동할 화면 (푸시 알림을 눌렀을 때와 같다).
  NotificationTarget? get target => NotificationTarget.fromData({'type': type});

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: map['type'] as String? ?? 'unknown',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      targetId: map['targetId'] as String?,
      createdAt: _date(map['createdAt']),
      readAt: _date(map['readAt']),
    );
  }

  static DateTime? _date(Object? value) {
    try {
      return FirestoreDate.parseNullable(value, 'date');
    } on ArgumentError {
      return null;
    }
  }
}
