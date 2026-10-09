import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum PtInfoLogType {
  created,
  updated,
  sessionCompleted,
  sessionReopened,

  /// 담당 트레이너 변경 (관리자)
  trainerChanged,
}

extension PtInfoLogTypeLabel on PtInfoLogType {
  String get label {
    switch (this) {
      case PtInfoLogType.created:
        return 'PT권 등록';
      case PtInfoLogType.updated:
        return 'PT권 수정';
      case PtInfoLogType.sessionCompleted:
        return '수업 완료 차감';
      case PtInfoLogType.sessionReopened:
        return '수업 상태 복구';
      case PtInfoLogType.trainerChanged:
        return '담당 변경';
    }
  }
}

class PtInfoLog {
  final String id;
  final String ptInfoId;
  final String centerId;
  final String memberId;
  final String memberName;
  final String? changedById;
  final String? changedByName;
  final PtInfoLogType type;
  final int previousTotalSessions;
  final int nextTotalSessions;
  final int previousRemainingSessions;
  final int nextRemainingSessions;
  final String? ptSessionId;
  final String? note;

  /// 담당 변경 기록의 이전·새 트레이너 ID ([PtInfoLogType.trainerChanged])
  final String? previousTrainerId;
  final String? nextTrainerId;
  final DateTime createdAt;

  const PtInfoLog({
    required this.id,
    required this.ptInfoId,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.changedById,
    this.changedByName,
    required this.type,
    required this.previousTotalSessions,
    required this.nextTotalSessions,
    required this.previousRemainingSessions,
    required this.nextRemainingSessions,
    this.ptSessionId,
    this.note,
    this.previousTrainerId,
    this.nextTrainerId,
    required this.createdAt,
  });

  int get totalDiff => nextTotalSessions - previousTotalSessions;
  int get remainingDiff => nextRemainingSessions - previousRemainingSessions;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ptInfoId': ptInfoId,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'changedById': changedById,
      'changedByName': changedByName,
      'type': type.name,
      'previousTotalSessions': previousTotalSessions,
      'nextTotalSessions': nextTotalSessions,
      'previousRemainingSessions': previousRemainingSessions,
      'nextRemainingSessions': nextRemainingSessions,
      'ptSessionId': ptSessionId,
      'note': note,
      if (type == PtInfoLogType.trainerChanged) ...{
        'previousTrainerId': previousTrainerId,
        'nextTrainerId': nextTrainerId,
      },
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 앱(관리자)이 새로 쓸 때: 기록 시각은 서버 시각만 허용된다 (규칙 `createdAt == request.time`).
  Map<String, dynamic> toCreateMap() => {
    ...toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory PtInfoLog.fromMap(Map<String, dynamic> map) {
    return PtInfoLog(
      id: map['id'] as String,
      ptInfoId: map['ptInfoId'] as String,
      centerId: map['centerId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String? ?? '',
      changedById: map['changedById'] as String?,
      changedByName: map['changedByName'] as String?,
      type: PtInfoLogType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => PtInfoLogType.updated,
      ),
      previousTotalSessions: map['previousTotalSessions'] as int? ?? 0,
      nextTotalSessions: map['nextTotalSessions'] as int? ?? 0,
      previousRemainingSessions: map['previousRemainingSessions'] as int? ?? 0,
      nextRemainingSessions: map['nextRemainingSessions'] as int? ?? 0,
      ptSessionId: map['ptSessionId'] as String?,
      note: map['note'] as String?,
      previousTrainerId: map['previousTrainerId'] as String?,
      nextTrainerId: map['nextTrainerId'] as String?,
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
    );
  }
}
