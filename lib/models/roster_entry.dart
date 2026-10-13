import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

/// 센터 명단 한 줄 (`centers/{centerId}/roster/{번호 숫자만}`).
///
/// 관리자가 엑셀로 올린, 아직 가입하지 않은 사람. 같은 번호를 다시 올리면 덮어쓴다
/// (문서 이름이 번호라서). 가입 요청을 승인하며 담당 · PT를 붙이면 이 줄은 지운다.
/// 그 센터 관리자만 읽고 쓴다 (`firestore.rules`).
class RosterEntry {
  /// 문서 이름 = 번호 숫자만 ('01012345678').
  final String id;
  final String centerId;

  /// 'member' | 'trainer'
  final String role;
  final String name;

  /// '010-1234-5678'
  final String phone;

  /// 회원만: 담당 트레이너 (올릴 때 같은 센터의 승인된 트레이너 이름으로 찾은 것)
  final String? trainerId;
  final String? trainerName;

  /// 회원만: PT 총 횟수 · 기간
  final int? ptTotal;
  final DateTime? ptStart;
  final DateTime? ptEnd;
  final DateTime updatedAt;

  const RosterEntry({
    required this.id,
    required this.centerId,
    required this.role,
    required this.name,
    required this.phone,
    this.trainerId,
    this.trainerName,
    this.ptTotal,
    this.ptStart,
    this.ptEnd,
    required this.updatedAt,
  });

  bool get isTrainer => role == 'trainer';

  /// '010-1234-5678' → '01012345678' (문서 이름).
  static String idFor(String phone) => phone.replaceAll('-', '');

  /// 저장할 값. [updatedAt]은 서버 시각.
  Map<String, dynamic> toWriteMap() => {
    'centerId': centerId,
    'role': role,
    'name': name,
    'phone': phone,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'ptTotal': ptTotal,
    'ptStart': ptStart == null ? null : Timestamp.fromDate(ptStart!),
    'ptEnd': ptEnd == null ? null : Timestamp.fromDate(ptEnd!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory RosterEntry.fromMap(String id, Map<String, dynamic> map) {
    return RosterEntry(
      id: id,
      centerId: map['centerId'] as String? ?? '',
      role: map['role'] == 'trainer' ? 'trainer' : 'member',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      trainerId: map['trainerId'] as String?,
      trainerName: map['trainerName'] as String?,
      ptTotal: (map['ptTotal'] as num?)?.toInt(),
      ptStart: FirestoreDate.parseNullable(map['ptStart'], 'ptStart'),
      ptEnd: FirestoreDate.parseNullable(map['ptEnd'], 'ptEnd'),
      updatedAt:
          FirestoreDate.parseNullable(map['updatedAt'], 'updatedAt') ??
          DateTime.now(),
    );
  }
}
