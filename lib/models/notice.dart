import '../core/firestore_date.dart';

/// 공지 대상.
enum NoticeAudience {
  all('all', '전체'),
  member('member', '회원'),
  trainer('trainer', '트레이너');

  final String value;
  final String label;
  const NoticeAudience(this.value, this.label);

  static NoticeAudience parse(Object? value) {
    for (final a in NoticeAudience.values) {
      if (a.value == value) return a;
    }
    return NoticeAudience.all;
  }
}

/// 센터 공지사항 (notices/{id}). 관리자만 작성하고, 대상이 맞는 같은 센터 사용자가 읽는다.
class Notice {
  static const int titleMax = 40;
  static const int bodyMax = 2000;

  final String id;
  final String centerId;
  final String title;
  final String body;
  final NoticeAudience audience;
  final bool pinned;
  final bool important;

  /// 등록할 때 푸시 알림을 요청했는지 (서버 함수가 대상에게 보낸다)
  final bool notify;
  final String authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Notice({
    required this.id,
    required this.centerId,
    required this.title,
    required this.body,
    required this.audience,
    required this.pinned,
    required this.important,
    this.notify = false,
    required this.authorId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isEdited =>
      createdAt != null &&
      updatedAt != null &&
      updatedAt!.difference(createdAt!).inSeconds > 1;

  factory Notice.fromMap(String id, Map<String, dynamic> map) {
    return Notice(
      id: id,
      centerId: map['centerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: NoticeAudience.parse(map['audience']),
      pinned: map['pinned'] as bool? ?? false,
      important: map['important'] as bool? ?? false,
      notify: map['notify'] as bool? ?? false,
      authorId: map['authorId'] as String? ?? '',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  /// 내용 필드만 (시각·작성자·센터는 서비스가 붙인다).
  Map<String, dynamic> toContentMap() => {
    'title': title,
    'body': body,
    'audience': audience.value,
    'pinned': pinned,
    'important': important,
  };

  static DateTime? _date(Object? value) {
    try {
      return FirestoreDate.parseNullable(value, 'date');
    } on ArgumentError {
      return null;
    }
  }
}
