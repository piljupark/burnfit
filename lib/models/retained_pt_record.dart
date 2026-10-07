import '../core/firestore_date.dart';
import 'pt_info_log.dart';
import 'pt_session.dart';

/// 탈퇴 회원의 PT 이력 사본 (retained_pt_records).
///
/// 서버 함수(functions/retention_store.js)만 만들며, 회원 ID·이름·메모는 들어 있지 않다.
/// 같은 회원의 기록은 [memberAlias]로 묶인다. [expireAt]이 지나면 서버가 파기한다.
enum RetainedPtRecordKind {
  ptInfo('pt_info'),
  ptSession('pt_session'),
  ptInfoLog('pt_info_log'),
  unknown('');

  final String value;

  const RetainedPtRecordKind(this.value);

  static RetainedPtRecordKind fromValue(Object? value) {
    return RetainedPtRecordKind.values.firstWhere(
      (kind) => kind.value == value && kind != RetainedPtRecordKind.unknown,
      orElse: () => RetainedPtRecordKind.unknown,
    );
  }
}

class RetainedPtRecord {
  final String id;
  final RetainedPtRecordKind kind;
  final String sourceId;
  final String centerId;
  final String memberAlias;
  final Map<String, dynamic> data;
  final DateTime? retainedAt;
  final DateTime expireAt;

  const RetainedPtRecord({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.centerId,
    required this.memberAlias,
    required this.data,
    required this.retainedAt,
    required this.expireAt,
  });

  factory RetainedPtRecord.fromMap(String id, Map<String, dynamic> map) {
    final data = map['data'];
    return RetainedPtRecord(
      id: id,
      kind: RetainedPtRecordKind.fromValue(map['kind']),
      sourceId: map['sourceId'] as String? ?? '',
      centerId: map['centerId'] as String? ?? '',
      memberAlias: map['memberAlias'] as String? ?? '',
      data: data is Map<String, dynamic> ? data : const {},
      retainedAt: _date(map['retainedAt']),
      expireAt: FirestoreDate.parse(map['expireAt'], 'expireAt'),
    );
  }

  // ── PT 계약 (pt_info) ──
  DateTime? get startDate => _date(data['startDate']);
  DateTime? get endDate => _date(data['endDate']);
  DateTime? get renewalDate => _date(data['renewalDate']);
  int? get totalSessions => _int(data['totalSessions']);
  int? get remainingSessions => _int(data['remainingSessions']);

  // ── 수업 (pt_session) ──
  DateTime? get scheduledAt => _date(data['scheduledAt']);
  int? get durationMinutes => _int(data['durationMinutes']);
  PtSessionStatus? get sessionStatus {
    final status = data['status'];
    for (final value in PtSessionStatus.values) {
      if (value.name == status) return value;
    }
    return null;
  }

  // ── 횟수 변경 이력 (pt_info_log) ──
  PtInfoLogType? get logType {
    final type = data['type'];
    for (final value in PtInfoLogType.values) {
      if (value.name == type) return value;
    }
    return null;
  }

  int? get previousRemainingSessions => _int(data['previousRemainingSessions']);
  int? get nextRemainingSessions => _int(data['nextRemainingSessions']);
  int? get previousTotalSessions => _int(data['previousTotalSessions']);
  int? get nextTotalSessions => _int(data['nextTotalSessions']);
  String? get changedByName => data['changedByName'] as String?;

  // ── 공통 ──
  String? get trainerId => data['trainerId'] as String?;
  String? get trainerName => data['trainerName'] as String?;
  DateTime? get createdAt => _date(data['createdAt']);

  /// 목록 정렬 기준: 수업은 수업 일시, 이력은 기록 시각, 계약은 시작일.
  DateTime? get eventDate {
    switch (kind) {
      case RetainedPtRecordKind.ptSession:
        return scheduledAt ?? createdAt;
      case RetainedPtRecordKind.ptInfoLog:
        return createdAt;
      case RetainedPtRecordKind.ptInfo:
        return startDate ?? createdAt;
      case RetainedPtRecordKind.unknown:
        return createdAt;
    }
  }

  static DateTime? _date(Object? value) {
    try {
      return FirestoreDate.parseNullable(value, 'date');
    } on ArgumentError {
      return null;
    }
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}

/// 탈퇴 회원 한 명 (같은 별칭의 PT 계약 묶음). 관리자 목록 한 줄.
class WithdrawnMemberSummary {
  final String memberAlias;
  final List<RetainedPtRecord> contracts;

  const WithdrawnMemberSummary({
    required this.memberAlias,
    required this.contracts,
  });

  /// 가장 최근 계약 (시작일 기준).
  RetainedPtRecord get latestContract => contracts.first;

  DateTime? get withdrawnAt => contracts
      .map((c) => c.retainedAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

  DateTime get expireAt =>
      contracts.map((c) => c.expireAt).reduce((a, b) => b.isAfter(a) ? b : a);

  Set<String> get trainerIds =>
      contracts.map((c) => c.trainerId).whereType<String>().toSet();

  /// PT 계약 기록을 회원별로 묶고, 최근 탈퇴 순으로 정렬한다.
  static List<WithdrawnMemberSummary> group(
    Iterable<RetainedPtRecord> records,
  ) {
    final byAlias = <String, List<RetainedPtRecord>>{};
    for (final record in records) {
      if (record.kind != RetainedPtRecordKind.ptInfo ||
          record.memberAlias.isEmpty) {
        continue;
      }
      byAlias.putIfAbsent(record.memberAlias, () => []).add(record);
    }

    final summaries = byAlias.entries.map((entry) {
      final contracts = [...entry.value]
        ..sort((a, b) => _compareDesc(a.startDate, b.startDate));
      return WithdrawnMemberSummary(
        memberAlias: entry.key,
        contracts: contracts,
      );
    }).toList()..sort((a, b) => _compareDesc(a.withdrawnAt, b.withdrawnAt));
    return summaries;
  }

  static int _compareDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}
