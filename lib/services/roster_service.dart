import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../models/join_request.dart';
import '../models/pt_info.dart';
import '../models/roster_entry.dart';
import '../models/user.dart';
import 'contact_service.dart';
import 'firestore_service.dart';

/// 가입 요청과 명단을 맞춰 본 결과.
class RosterMatch {
  final RosterEntry entry;

  /// 신청자 이름과 명단 이름이 같은지 (띄어쓰기 무시). 다르면 승인해도 명단 정보를 붙이지 않는다.
  final bool sameName;

  const RosterMatch({required this.entry, required this.sameName});
}

/// 센터 명단 (`centers/{centerId}/roster`) — 그 센터 관리자만 쓴다.
///
/// 올리기 → 미가입 목록 → 가입 요청에서 '명단과 일치' → 승인하면 담당 · PT를 붙이고 줄을 지운다.
/// 번호만 같다고 자동 승인하지 않는다 (문자 인증이 없어 남의 번호로도 가입할 수 있다).
class RosterService {
  RosterService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String centerId) {
    ServiceValidator.requireText(centerId, '센터 ID');
    return _db.collection('centers').doc(centerId).collection('roster');
  }

  /// 미가입 명단 (이름순).
  static Future<List<RosterEntry>> list(String centerId) async {
    final snap = await _col(centerId).get();
    final rows = <RosterEntry>[];
    for (final d in snap.docs) {
      try {
        rows.add(RosterEntry.fromMap(d.id, d.data()));
      } catch (e) {
        AppLogger.debug('[RosterService] 명단 줄 읽기 실패(${d.id}): $e');
      }
    }
    return rows..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 이미 승인된 계정의 번호 → 이름 (올리기 미리보기의 '가입됨').
  /// 번호를 저장하지 않은 예전 계정은 빠진다.
  static Future<Map<String, String>> joinedPhones(String centerId) async {
    final users = await FirestoreService.getUsersByCenter(centerId);
    final targets = users.where((u) => !u.isAdmin).toList();
    final phones = await Future.wait(
      targets.map((u) async {
        try {
          return await ContactService.getPhone(u.uid);
        } catch (_) {
          return null;
        }
      }),
    );
    return {
      for (var i = 0; i < targets.length; i++)
        if (phones[i] != null) phones[i]!: targets[i].name,
    };
  }

  /// 여러 줄 저장 (같은 번호는 덮어쓴다). 한 묶음 400줄씩.
  static Future<void> saveAll(String centerId, List<RosterEntry> entries) async {
    const chunk = 400;
    for (var i = 0; i < entries.length; i += chunk) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(chunk)) {
        batch.set(_col(centerId).doc(e.id), e.toWriteMap());
      }
      await batch.commit();
    }
  }

  static Future<void> delete(String centerId, String id) =>
      _col(centerId).doc(id).delete();

  /// 신청자의 번호(가입 요청 줄에 가려서 보인다)와, 그 번호가 명단에 있으면 그 줄.
  /// 번호가 없는 예전 계정 · 구분이 다른 줄은 맞추지 않는다.
  static Future<({String? phone, RosterMatch? match})> lookup(
    JoinRequest req,
  ) async {
    final phone = await ContactService.getPhone(req.userId);
    if (phone == null) return (phone: null, match: null);
    final snap = await _col(req.centerId).doc(RosterEntry.idFor(phone)).get();
    final data = snap.data();
    if (data == null) return (phone: phone, match: null);
    final entry = RosterEntry.fromMap(snap.id, data);
    if (entry.role != req.role) return (phone: phone, match: null);
    String n(String s) => s.replaceAll(RegExp(r'\s'), '');
    return (
      phone: phone,
      match: RosterMatch(entry: entry, sameName: n(entry.name) == n(req.userName)),
    );
  }

  /// 승인한 뒤 명단의 담당 · PT를 붙이고 명단 줄을 지운다.
  ///
  /// 승인은 이미 끝난 뒤라, 여기서 실패하면 안내 문구를 돌려준다 (회원 상세에서 마저 넣는다).
  /// 다 붙였으면 null.
  static Future<String?> applyAfterApproval({
    required JoinRequest req,
    required RosterEntry entry,
    required AppUser admin,
  }) async {
    final warnings = <String>[];
    if (req.role == 'member') {
      String? trainerId;
      final wantTrainer = entry.trainerId;
      if (wantTrainer != null) {
        try {
          final trainers = await FirestoreService.getTrainersByCenter(
            req.centerId,
          );
          final trainer = trainers.where((t) => t.uid == wantTrainer).toList();
          if (trainer.isEmpty) {
            warnings.add('담당 트레이너(${entry.trainerName ?? ''})를 찾지 못했어요');
          } else {
            await FirestoreService.assignTrainer(
              centerId: req.centerId,
              memberId: req.userId,
              trainerId: trainer.first.uid,
              trainerName: trainer.first.name,
              changedById: admin.uid,
              changedByName: admin.name,
            );
            trainerId = trainer.first.uid;
          }
        } catch (e) {
          AppLogger.debug('[RosterService] 담당 배정 실패: $e');
          warnings.add('담당 트레이너를 붙이지 못했어요');
        }
      }
      final total = entry.ptTotal;
      if (total != null) {
        try {
          final now = DateTime.now();
          await FirestoreService.savePtInfo(
            PtInfo(
              id: req.userId,
              centerId: req.centerId,
              memberId: req.userId,
              memberName: req.userName,
              trainerId: trainerId,
              startDate: entry.ptStart,
              endDate: entry.ptEnd,
              totalSessions: total,
              remainingSessions: total,
              createdAt: now,
              updatedAt: now,
            ),
            changedById: admin.uid,
            changedByName: admin.name,
            note: '명단에서 등록',
          );
        } catch (e) {
          AppLogger.debug('[RosterService] PT 등록 실패: $e');
          warnings.add('PT 정보를 붙이지 못했어요');
        }
      }
    }
    if (warnings.isNotEmpty) {
      // 줄을 남겨 두면 관리자가 명단에서 내용을 다시 볼 수 있다.
      return '${warnings.join(' · ')}. 회원 상세에서 넣어 주세요.';
    }
    try {
      await delete(req.centerId, entry.id);
    } catch (e) {
      AppLogger.debug('[RosterService] 명단 줄 지우기 실패: $e');
    }
    return null;
  }
}
