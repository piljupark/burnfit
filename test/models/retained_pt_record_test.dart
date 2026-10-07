import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/pt_info_log.dart';
import 'package:pt_solution_v2/models/pt_session.dart';
import 'package:pt_solution_v2/models/retained_pt_record.dart';

Timestamp _ts(int y, int m, int d) => Timestamp.fromDate(DateTime.utc(y, m, d));

RetainedPtRecord _record(
  String id, {
  String kind = 'pt_info',
  String alias = 'withdrawn_a',
  Map<String, dynamic> data = const {},
  Timestamp? retainedAt,
  Timestamp? expireAt,
}) {
  return RetainedPtRecord.fromMap(id, {
    'kind': kind,
    'sourceId': id,
    'centerId': 'c1',
    'memberAlias': alias,
    'data': data,
    'retainedAt': retainedAt ?? _ts(2026, 10, 7),
    'expireAt': expireAt ?? _ts(2029, 10, 7),
  });
}

void main() {
  group('RetainedPtRecord.fromMap', () {
    test('종류별 필드를 읽는다', () {
      final session = _record('s1', kind: 'pt_session', data: {
        'scheduledAt': _ts(2026, 9, 1),
        'durationMinutes': 50,
        'status': 'completed',
        'trainerName': '김트',
      });
      expect(session.kind, RetainedPtRecordKind.ptSession);
      expect(session.sessionStatus, PtSessionStatus.completed);
      expect(session.durationMinutes, 50);
      expect(session.eventDate!.toUtc(), DateTime.utc(2026, 9, 1));

      final log = _record('l1', kind: 'pt_info_log', data: {
        'type': 'sessionCompleted',
        'previousRemainingSessions': 13,
        'nextRemainingSessions': 12,
      });
      expect(log.logType, PtInfoLogType.sessionCompleted);
      expect(log.nextRemainingSessions, 12);
    });

    test('형식이 깨진 값은 null로 다루고 화면을 막지 않는다', () {
      final broken = _record('x', kind: 'something', data: {
        'startDate': 'not-a-date',
        'totalSessions': '30',
        'status': 'weird',
      });
      expect(broken.kind, RetainedPtRecordKind.unknown);
      expect(broken.startDate, isNull);
      expect(broken.totalSessions, isNull);
      expect(broken.sessionStatus, isNull);
    });
  });

  group('WithdrawnMemberSummary.group', () {
    test('같은 별칭의 계약을 한 명으로 묶고 최근 탈퇴 순으로 정렬한다', () {
      final records = [
        _record('a-old', alias: 'withdrawn_a', data: {'startDate': _ts(2025, 1, 1)}, retainedAt: _ts(2026, 3, 1)),
        _record('a-new', alias: 'withdrawn_a', data: {'startDate': _ts(2026, 1, 1)},
            retainedAt: _ts(2026, 3, 1), expireAt: _ts(2030, 1, 1)),
        _record('b', alias: 'withdrawn_b', retainedAt: _ts(2026, 9, 1)),
        _record('s', alias: 'withdrawn_c', kind: 'pt_session'),
      ];

      final members = WithdrawnMemberSummary.group(records);

      expect(members.map((m) => m.memberAlias), ['withdrawn_b', 'withdrawn_a'],
          reason: '수업 기록만 있는 별칭은 목록에 넣지 않는다');
      final a = members[1];
      expect(a.contracts.map((c) => c.id), ['a-new', 'a-old']);
      expect(a.latestContract.id, 'a-new');
      expect(a.withdrawnAt!.toUtc(), DateTime.utc(2026, 3, 1));
      expect(a.expireAt.toUtc(), DateTime.utc(2030, 1, 1), reason: '가장 늦은 파기일');
    });

    test('트레이너 ID를 모은다', () {
      final members = WithdrawnMemberSummary.group([
        _record('1', data: {'trainerId': 't1'}),
        _record('2', data: {'trainerId': 't2'}),
        _record('3'),
      ]);
      expect(members.single.trainerIds, {'t1', 't2'});
    });
  });
}
