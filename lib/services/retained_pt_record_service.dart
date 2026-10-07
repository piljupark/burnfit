import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/service_validator.dart';
import '../models/retained_pt_record.dart';

/// 탈퇴 회원 PT 이력 조회 (관리자 전용, 읽기만).
///
/// 보안 규칙상 같은 센터 관리자만 읽을 수 있으므로 모든 조회에 centerId 조건을 건다.
class RetainedPtRecordService {
  RetainedPtRecordService._();

  static final _collection = FirebaseFirestore.instance.collection('retained_pt_records');

  /// 센터의 탈퇴 회원 목록 (PT 계약 기록 기준, 최근 탈퇴 순).
  static Future<List<WithdrawnMemberSummary>> getWithdrawnMembers(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    final snap = await _collection
        .where('centerId', isEqualTo: centerId)
        .where('kind', isEqualTo: RetainedPtRecordKind.ptInfo.value)
        .get();
    return WithdrawnMemberSummary.group(
      snap.docs.map((d) => RetainedPtRecord.fromMap(d.id, d.data())),
    );
  }

  /// 탈퇴 회원 한 명의 전체 이력 (최근 순).
  static Future<List<RetainedPtRecord>> getMemberRecords({
    required String centerId,
    required String memberAlias,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberAlias, '회원 구분값');
    final snap = await _collection
        .where('centerId', isEqualTo: centerId)
        .where('memberAlias', isEqualTo: memberAlias)
        .get();
    final records = snap.docs.map((d) => RetainedPtRecord.fromMap(d.id, d.data())).toList()
      ..sort((a, b) {
        final ad = a.eventDate;
        final bd = b.eventDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    return records;
  }
}
