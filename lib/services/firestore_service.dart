import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../models/user.dart';
import '../models/center.dart' as center_model;
import '../models/join_request.dart';
import '../models/pt_info.dart';
import '../models/pt_info_log.dart';
import '../models/feedback.dart' as fb;
import '../models/pt_session.dart';
import '../models/inbody.dart';
import '../models/admin_stats.dart';

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Users ----------

  static Future<AppUser?> getUser(String uid) async {
    ServiceValidator.requireText(uid, '사용자 ID');

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  /// 사용자 문서를 실시간으로 받는다 (승인·거절 등 상태 변화 감지용). 문서가 없으면 null.
  /// 이 기기에서 쓴 값이 서버에 확정되기 전 결과는 건너뛴다
  /// (서버 시각(updatedAt)이 비어 있어 읽을 수 없고, 상태 변화는 늘 서버에서 온다).
  static Stream<AppUser?> watchUser(String uid) {
    ServiceValidator.requireText(uid, '사용자 ID');

    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .where((doc) => !doc.metadata.hasPendingWrites)
        .map((doc) {
          final data = doc.data();
          return data == null ? null : AppUser.fromMap(data);
        });
  }

  static Future<void> saveUser(AppUser user) async {
    _validateUser(user);

    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    ServiceValidator.requireText(uid, '사용자 ID');
    if (data.isEmpty) {
      throw ArgumentError('수정할 사용자 정보가 없습니다.');
    }

    final payload = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    await _db.collection('users').doc(uid).update(payload);
  }

  static Future<List<AppUser>> getUsersByCenter(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');

    final snap = await _db
        .collection('users')
        .where('centerId', isEqualTo: centerId)
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
  }

  static Future<List<AppUser>> getMembersByTrainer(
    String centerId,
    String trainerId,
  ) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(trainerId, '트레이너 ID');

    final snap = await _db
        .collection('users')
        .where('centerId', isEqualTo: centerId)
        .where('role', isEqualTo: 'member')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
  }

  static Future<List<AppUser>> getTrainersByCenter(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');

    final snap = await _db
        .collection('users')
        .where('centerId', isEqualTo: centerId)
        .where('role', isEqualTo: 'trainer')
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
  }

  // ---------- Centers ----------

  static Future<center_model.Center?> getCenter(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');

    final doc = await _db.collection('centers').doc(centerId).get();
    if (!doc.exists) return null;
    return center_model.Center.fromMap(doc.data()!);
  }

  static Future<List<center_model.Center>> searchCenters(String query) async {
    final q = query.trim().toLowerCase();

    // 센터 목록은 늘 서버에서 읽는다. 기본(서버 → 실패 시 기기 캐시)이면 서버에 닿지 못할 때
    // 오류 대신 빈 캐시로 답해 '검색된 센터가 없습니다'로 보인다 → 오류로 올려 다시 시도하게 한다.
    final snap = await _db
        .collection('centers')
        .where('status', isEqualTo: 'active')
        .get(const GetOptions(source: Source.server));
    // 형식이 어긋난 문서 하나 때문에 목록 전체가 실패하지 않게 그 문서만 건너뛴다.
    final all = <center_model.Center>[];
    for (final doc in snap.docs) {
      try {
        // 콘솔에서 직접 만든 문서처럼 'id' 칸이 없으면 문서 ID를 쓴다.
        all.add(center_model.Center.fromMap({'id': doc.id, ...doc.data()}));
      } catch (e) {
        AppLogger.debug('[FirestoreService] 센터 문서 파싱 실패(${doc.id}): $e');
      }
    }
    if (q.isEmpty) return all;
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  // ---------- Join Requests ----------

  static Future<void> createJoinRequest(JoinRequest req) async {
    _validateJoinRequest(req);

    await _db.collection('join_requests').doc(req.id).set(req.toMap());
  }

  static Future<List<JoinRequest>> getPendingRequests(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');

    final snap = await _db
        .collection('join_requests')
        .where('centerId', isEqualTo: centerId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) => JoinRequest.fromMap(d.data())).toList();
  }

  static Future<void> approveJoinRequest(
    String requestId,
    String userId,
  ) async {
    ServiceValidator.requireText(requestId, '가입 요청 ID');
    ServiceValidator.requireText(userId, '사용자 ID');

    final batch = _db.batch();
    batch.update(_db.collection('join_requests').doc(requestId), {
      'status': 'approved',
    });
    batch.update(_db.collection('users').doc(userId), {
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> rejectJoinRequest(String requestId, String userId) async {
    ServiceValidator.requireText(requestId, '가입 요청 ID');
    ServiceValidator.requireText(userId, '사용자 ID');

    final batch = _db.batch();
    batch.update(_db.collection('join_requests').doc(requestId), {
      'status': 'rejected',
    });
    batch.update(_db.collection('users').doc(userId), {
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ---------- PT Info ----------

  static Future<PtInfo?> getPtInfo(String memberId, {String? centerId}) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    if (centerId != null) {
      ServiceValidator.requireText(centerId, '센터 ID');
    }

    Query query = _db
        .collection('pt_infos')
        .where('memberId', isEqualTo: memberId)
        .limit(1);
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return null;
    return PtInfo.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  /// 관리자 PT권 등록·수정 + 변경 기록 (한 트랜잭션).
  ///
  /// 수정은 바뀔 수 있는 운영 필드만 update 한다 (회원 이름 등 다른 필드는 건드리지 않는다).
  /// [previousInfo]는 화면을 열 때 읽은 값이다. 그 사이 트레이너의 PT 완료로 잔여가 바뀌었으면
  /// 덮어쓰지 않고 다시 확인하라고 알린다 (차감이 되돌려지는 것 방지).
  static Future<void> savePtInfo(
    PtInfo info, {
    String? changedById,
    String? changedByName,
    String? note,
    PtInfo? previousInfo,
  }) async {
    _validatePtInfo(info);
    if (info.remainingSessions > info.totalSessions) {
      throw ArgumentError('잔여 횟수는 전체 횟수보다 많을 수 없습니다.');
    }
    final start = info.startDate;
    final end = info.endDate;
    if (start != null && end != null && end.isBefore(start)) {
      throw ArgumentError('종료일이 시작일보다 앞설 수 없습니다.');
    }
    final ptInfoRef = _db.collection('pt_infos').doc(info.id);
    final logRef = _db.collection('pt_info_logs').doc();

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ptInfoRef);
      final current = snap.exists ? PtInfo.fromMap(snap.data()!) : null;
      if (current != null &&
          previousInfo != null &&
          current.remainingSessions != previousInfo.remainingSessions) {
        throw ArgumentError(
          '그 사이 PT 잔여 횟수가 ${current.remainingSessions}회로 바뀌었습니다. 화면을 다시 열어 확인해주세요.',
        );
      }
      if (current == null) {
        transaction.set(ptInfoRef, info.toMap());
      } else {
        final map = info.toMap();
        transaction.update(ptInfoRef, {
          for (final key in const [
            'trainerId',
            'startDate',
            'endDate',
            'totalSessions',
            'remainingSessions',
            'renewalDate',
          ])
            key: map[key],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
        logRef,
        _buildPtInfoLog(
          id: logRef.id,
          info: info,
          previous: current,
          type: current == null ? PtInfoLogType.created : PtInfoLogType.updated,
          changedById: changedById,
          changedByName: changedByName,
          note: note,
        ).toMap(),
      );
    });
  }

  static Future<List<PtInfo>> getPtInfosByCenter(String centerId) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    final snap = await _db
        .collection('pt_infos')
        .where('centerId', isEqualTo: centerId)
        .get();
    return snap.docs.map((d) => PtInfo.fromMap(d.data())).toList();
  }

  // ---------- Feedbacks ----------

  static Future<void> createFeedback(fb.Feedback feedback) async {
    ServiceValidator.requireText(feedback.id, '피드백 ID');
    ServiceValidator.requireText(feedback.centerId, '센터 ID');
    ServiceValidator.requireText(feedback.trainerId, '트레이너 ID');
    ServiceValidator.requireText(feedback.memberId, '회원 ID');
    ServiceValidator.requireText(feedback.content, '피드백 내용');
    await _db.collection('feedbacks').doc(feedback.id).set(feedback.toMap());
  }

  /// 피드백 내용만 고친다 (규칙: content·updatedAt만 허용 — 문서 전체를 다시 쓰면 거부된다).
  static Future<void> updateFeedbackContent(
    String feedbackId,
    String content,
  ) async {
    ServiceValidator.requireText(feedbackId, '피드백 ID');
    ServiceValidator.requireText(content, '피드백 내용');
    await _db.collection('feedbacks').doc(feedbackId).update({
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<fb.Feedback>> getFeedbacksForMember(
    String memberId, {
    String? centerId,
    int limit = 20,
  }) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    if (centerId != null) {
      ServiceValidator.requireText(centerId, '센터 ID');
    }
    ServiceValidator.requirePositiveInt(limit, '피드백 조회 개수');

    Query query = _db
        .collection('feedbacks')
        .where('memberId', isEqualTo: memberId);
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    final snap = await query.get();
    return _parseFeedbackDocs(snap.docs);
  }

  /// 기록 하나(식단·운동·유산소)에 달린 피드백 전체, 오래된 순.
  /// 담당이 바뀌면 이전 트레이너의 피드백도 함께 남고, 지금 담당 트레이너도 읽을 수 있다
  /// (규칙이 회원 기준으로 판단하므로 [memberId] 조건이 꼭 있어야 한다).
  static Future<List<fb.Feedback>> getFeedbacksByTarget(
    String targetId, {
    required String centerId,
    required String memberId,
  }) async {
    ServiceValidator.requireText(targetId, '피드백 대상 ID');
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');

    final snap = await _db
        .collection('feedbacks')
        .where('targetId', isEqualTo: targetId)
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .get();
    return _parseFeedbackDocs(snap.docs)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static List<fb.Feedback> _parseFeedbackDocs(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final feedbacks = <fb.Feedback>[];
    for (final doc in docs) {
      try {
        feedbacks.add(fb.Feedback.fromMap(doc.data() as Map<String, dynamic>));
      } catch (e) {
        AppLogger.debug('[FirestoreService] 피드백 문서 파싱 실패(${doc.id}): $e');
      }
    }
    return feedbacks;
  }

  static Future<void> deleteFeedback(fb.Feedback feedback) async {
    ServiceValidator.requireText(feedback.id, '피드백 ID');

    final batch = _db.batch();
    batch.delete(_db.collection('feedbacks').doc(feedback.id));

    final targetRef = _feedbackTargetRef(feedback);
    if (targetRef != null) {
      batch.update(targetRef, {
        'hasFeedback': false,
        'feedbackId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static Future<void> markFeedbacksRead({
    required String centerId,
    required String memberId,
    required Iterable<String> feedbackIds,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    final ids = feedbackIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;

    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_db.collection('feedbacks').doc(id), {
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static DocumentReference<Map<String, dynamic>>? _feedbackTargetRef(
    fb.Feedback feedback,
  ) {
    final targetId = feedback.targetId;
    if (targetId == null || targetId.trim().isEmpty) return null;

    switch (feedback.targetType) {
      case fb.FeedbackTargetType.meal:
        return _db.collection('meals').doc(targetId);
      case fb.FeedbackTargetType.workout:
        return _db.collection('workouts').doc(targetId);
      case fb.FeedbackTargetType.cardio:
        return _db.collection('cardios').doc(targetId);
      case fb.FeedbackTargetType.general:
        return null;
    }
  }

  // ---------- PT Sessions ----------

  static Future<void> savePtSession(PtSession session) async {
    ServiceValidator.requireText(session.id, 'PT 세션 ID');
    ServiceValidator.requireText(session.centerId, '센터 ID');
    ServiceValidator.requireText(session.trainerId, '트레이너 ID');
    ServiceValidator.requireText(session.memberId, '회원 ID');
    ServiceValidator.requirePositiveInt(session.durationMinutes, 'PT 시간');
    await _requireRemainingPtSession(
      centerId: session.centerId,
      memberId: session.memberId,
      trainerId: session.trainerId,
      scheduledAt: session.scheduledAt,
    );
    await _db.collection('pt_sessions').doc(session.id).set(session.toMap());
  }

  static Future<void> updatePtSessionSchedule({
    required String sessionId,
    required String centerId,
    required String memberId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? note,
  }) async {
    ServiceValidator.requireText(sessionId, 'PT 세션 ID');
    ServiceValidator.requirePositiveInt(durationMinutes, 'PT 시간');
    // 새로 잡을 때와 같이 PT권 종료일 뒤로는 옮기지 않는다.
    final ptInfo = await getPtInfo(memberId, centerId: centerId);
    if (ptInfo != null) _requireBeforePtEnd(ptInfo, scheduledAt);
    await _db.collection('pt_sessions').doc(sessionId).update({
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<PtSession>> getPtSessionsByTrainer(
    String centerId,
    String trainerId, {
    DateTime? from,
    DateTime? to,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(trainerId, '트레이너 ID');
    _validateDateTimeRange(from: from, to: to, fieldName: 'PT 일정');

    Query query = _db
        .collection('pt_sessions')
        .where('centerId', isEqualTo: centerId)
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('scheduledAt');

    if (from != null) {
      query = query.where(
        'scheduledAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      query = query.where(
        'scheduledAt',
        isLessThanOrEqualTo: Timestamp.fromDate(to),
      );
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => PtSession.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  static Future<List<PtInfoLog>> getPtInfoLogs({
    required String centerId,
    required String memberId,
    int limit = 20,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requirePositiveInt(limit, 'PT권 변경 로그 조회 개수');

    final snap = await _db
        .collection('pt_info_logs')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => PtInfoLog.fromMap(d.data())).toList();
  }

  static Future<List<PtSession>> getPtSessionsByMember(
    String memberId, {
    String? centerId,
    DateTime? from,
    DateTime? to,
  }) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    if (centerId != null) {
      ServiceValidator.requireText(centerId, '센터 ID');
    }
    _validateDateTimeRange(from: from, to: to, fieldName: 'PT 일정');

    Query query = _db
        .collection('pt_sessions')
        .where('memberId', isEqualTo: memberId);
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    query = query.orderBy('scheduledAt');

    if (from != null) {
      query = query.where(
        'scheduledAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      query = query.where(
        'scheduledAt',
        isLessThanOrEqualTo: Timestamp.fromDate(to),
      );
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => PtSession.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  /// PT 세션 상태 변경 (완료 · 완료 취소 · 예약 취소).
  /// 잔여 횟수 차감·복구와 변경 기록은 서버 함수(setPtSessionStatus)가 한 트랜잭션으로 처리한다.
  /// 이미 그 상태면 아무 일도 없으므로 다시 불러도 안전하다.
  static Future<PtStatusResult> updatePtSessionStatus(
    String sessionId,
    PtSessionStatus status,
  ) async {
    ServiceValidator.requireText(sessionId, 'PT 세션 ID');
    final result = await FirebaseFunctions.instance
        .httpsCallable('setPtSessionStatus')
        .call<Map<String, dynamic>>({
          'sessionId': sessionId,
          'status': status.name,
        });
    final data = result.data;
    return PtStatusResult(
      changed: data['changed'] == true,
      remainingSessions: (data['remainingSessions'] as num?)?.toInt(),
    );
  }

  /// 예약된 세션을 완료로 바꾸기 전 확인: PT권이 있고 잔여 횟수가 남아 있어야 한다.
  /// (서버 함수도 같은 이유로 거부하지만, 운동 기록을 먼저 저장하기 전에 막으려고 미리 본다.)
  static Future<void> requireRemainingForCompletion({
    required String centerId,
    required String memberId,
  }) async {
    final ptInfo = await getPtInfo(memberId, centerId: centerId);
    if (ptInfo == null) {
      throw ArgumentError('등록된 PT권이 없어 PT를 완료 처리할 수 없습니다.');
    }
    if (ptInfo.remainingSessions <= 0) {
      throw ArgumentError('잔여 PT 횟수가 없어 PT를 완료 처리할 수 없습니다.');
    }
  }

  // ---------- Inbodies ----------

  static Future<void> saveInbody(Inbody inbody) async {
    ServiceValidator.requireText(inbody.id, 'InBody ID');
    ServiceValidator.requireText(inbody.centerId, '센터 ID');
    ServiceValidator.requireText(inbody.memberId, '회원 ID');
    ServiceValidator.requireText(inbody.trainerId, '트레이너 ID');
    ServiceValidator.requireDateKey(inbody.measurementDate, '측정일');
    ServiceValidator.requireOptionalPositiveDouble(inbody.weight, '체중');
    ServiceValidator.requireOptionalPositiveDouble(inbody.muscleMass, '골격근량');
    ServiceValidator.requireOptionalPositiveDouble(inbody.bodyFat, '체지방량');
    ServiceValidator.requireOptionalPositiveDouble(
      inbody.bodyFatPercent,
      '체지방률',
    );
    ServiceValidator.requireOptionalPositiveDouble(inbody.bmi, 'BMI');
    ServiceValidator.requireOptionalPositiveDouble(inbody.bmr, 'BMR');
    ServiceValidator.requireOptionalPositiveInt(inbody.visceralFat, '내장지방 레벨');
    await _db.collection('inbodies').doc(inbody.id).set(inbody.toMap());
  }

  static Future<List<Inbody>> getInbodiesByMember(
    String memberId, {
    String? centerId,
    int limit = 10,
  }) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    if (centerId != null) {
      ServiceValidator.requireText(centerId, '센터 ID');
    }
    ServiceValidator.requirePositiveInt(limit, 'InBody 조회 개수');

    Query query = _db
        .collection('inbodies')
        .where('memberId', isEqualTo: memberId);
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    query = query.orderBy('measurementDate', descending: true).limit(limit);
    final snap = await query.get();
    return snap.docs
        .map((d) => Inbody.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  static Future<void> deleteInbody(String inbodyId) async {
    ServiceValidator.requireText(inbodyId, 'InBody ID');

    await _db.collection('inbodies').doc(inbodyId).delete();
  }

  // ---------- Admin helpers ----------

  /// 회원 담당 트레이너 배정·변경: 회원 문서, PT권, 앞으로의 예약 일정을 한 번에 바꾼다.
  /// 조회에 centerId를 넣어야 관리자 읽기 규칙(isCenterAdmin)이 조회를 허용한다.
  static Future<void> assignTrainer({
    required String centerId,
    required String memberId,
    required String trainerId,
    required String trainerName,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(trainerId, '트레이너 ID');
    ServiceValidator.requireText(trainerName, '트레이너 이름');

    final memberRef = _db.collection('users').doc(memberId);
    final results = await Future.wait([
      _db
          .collection('pt_infos')
          .where('centerId', isEqualTo: centerId)
          .where('memberId', isEqualTo: memberId)
          .get(),
      _db
          .collection('pt_sessions')
          .where('centerId', isEqualTo: centerId)
          .where('memberId', isEqualTo: memberId)
          .where('status', isEqualTo: PtSessionStatus.scheduled.name)
          .get(),
    ]);
    final ptInfoRefs = results[0].docs.map((d) => d.reference).toList();
    final sessionRefs = results[1].docs.map((d) => d.reference).toList();

    final assigned = {
      'trainerId': trainerId,
      'trainerName': trainerName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // 일반적으로 한 배치(500건) 안에 들어가므로 중간에 일부만 바뀌는 일이 없다.
    if (1 + ptInfoRefs.length + sessionRefs.length <= 450) {
      final batch = _db.batch();
      batch.update(memberRef, assigned);
      for (final ref in sessionRefs) {
        batch.update(ref, assigned);
      }
      for (final ref in ptInfoRefs) {
        batch.update(ref, {
          'trainerId': trainerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return;
    }
    await _commitInChunks([memberRef, ...sessionRefs], assigned);
    await _commitInChunks(ptInfoRefs, {
      'trainerId': trainerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Admin Dashboard ----------

  static Future<AdminStats> getAdminStats(String centerId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final expiryLimit = todayStart.add(const Duration(days: 14));

    final results = await Future.wait([
      _db
          .collection('users')
          .where('centerId', isEqualTo: centerId)
          .where('role', isEqualTo: 'member')
          .where('status', isEqualTo: 'approved')
          .get(),
      _db
          .collection('users')
          .where('centerId', isEqualTo: centerId)
          .where('role', isEqualTo: 'trainer')
          .where('status', isEqualTo: 'approved')
          .get(),
      // 이번 달 세션 전체 (완료율·예정 수는 이 범위에서만 센다)
      _db
          .collection('pt_sessions')
          .where('centerId', isEqualTo: centerId)
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('scheduledAt', isLessThan: Timestamp.fromDate(monthEnd))
          .get(),
      // 잔여 3회 이하 (0회 포함 — 갱신이 가장 급한 회원)
      _db
          .collection('pt_infos')
          .where('centerId', isEqualTo: centerId)
          .where('remainingSessions', isGreaterThanOrEqualTo: 0)
          .where('remainingSessions', isLessThanOrEqualTo: 3)
          .get(),
      _db
          .collection('pt_sessions')
          .where('centerId', isEqualTo: centerId)
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('scheduledAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),
      _db
          .collection('pt_infos')
          .where('centerId', isEqualTo: centerId)
          .where(
            'endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where(
            'endDate',
            isLessThanOrEqualTo: Timestamp.fromDate(expiryLimit),
          )
          .get(),
    ]);

    final memberCount = results[0].docs.length;
    final trainerCount = results[1].docs.length;

    final monthSessions = results[2].docs
        .map((d) => PtSession.fromMap(d.data()))
        .toList();
    final completedSessions = monthSessions
        .where((s) => s.status == PtSessionStatus.completed)
        .toList();
    final monthScheduled = monthSessions
        .where((s) => s.status == PtSessionStatus.scheduled)
        .toList();
    // 이번 달 중 아직 다가오지 않은 예약 (홈의 '예정 세션')
    final upcomingSessions = monthScheduled
        .where((s) => !s.scheduledAt.isBefore(now))
        .toList();

    final lowPtInfos =
        results[3].docs.map((d) => PtInfo.fromMap(d.data())).toList()
          ..sort((a, b) => a.remainingSessions.compareTo(b.remainingSessions));

    final todaySessions = results[4].docs
        .map((d) => PtSession.fromMap(d.data()))
        .toList();
    final todayScheduledSessions = todaySessions
        .where((s) => s.status == PtSessionStatus.scheduled)
        .length;
    final todayCompletedSessions = todaySessions
        .where((s) => s.status == PtSessionStatus.completed)
        .length;

    final expiringPtInfos =
        results[5].docs.map((d) => PtInfo.fromMap(d.data())).toList()
          ..sort((a, b) {
            final aEnd = a.endDate ?? expiryLimit;
            final bEnd = b.endDate ?? expiryLimit;
            return aEnd.compareTo(bEnd);
          });

    final Map<String, TrainerSessionStat> trainerMap = {};
    for (final s in completedSessions) {
      final prev = trainerMap[s.trainerId];
      trainerMap[s.trainerId] = TrainerSessionStat(
        trainerId: s.trainerId,
        trainerName: s.trainerName,
        completedCount: (prev?.completedCount ?? 0) + 1,
      );
    }
    final trainerStats = trainerMap.values.toList()
      ..sort((a, b) => b.completedCount.compareTo(a.completedCount));
    // 완료율 = 이번 달 완료 / (이번 달 완료 + 이번 달 예약). 취소는 빼고, 다음 달 예약은 넣지 않는다.
    final monthlyScheduledTotal =
        completedSessions.length + monthScheduled.length;
    final monthlyCompletionRate = monthlyScheduledTotal == 0
        ? 0.0
        : completedSessions.length / monthlyScheduledTotal;

    return AdminStats(
      memberCount: memberCount,
      trainerCount: trainerCount,
      monthlyCompletedSessions: completedSessions.length,
      upcomingSessionCount: upcomingSessions.length,
      todayScheduledSessions: todayScheduledSessions,
      todayCompletedSessions: todayCompletedSessions,
      monthlyCompletionRate: monthlyCompletionRate,
      trainerStats: trainerStats,
      lowPtMembers: lowPtInfos,
      expiringPtMembers: expiringPtInfos,
    );
  }

  static void _validateUser(AppUser user) {
    ServiceValidator.requireText(user.uid, '사용자 ID');
    ServiceValidator.requireText(user.email, '이메일');
    ServiceValidator.requireText(user.name, '이름');
    ServiceValidator.requireText(user.centerId, '센터 ID');
    ServiceValidator.requireText(user.centerName, '센터 이름');
  }

  static void _validateJoinRequest(JoinRequest req) {
    ServiceValidator.requireText(req.id, '가입 요청 ID');
    ServiceValidator.requireText(req.userId, '사용자 ID');
    ServiceValidator.requireText(req.userName, '사용자 이름');
    ServiceValidator.requireText(req.userEmail, '사용자 이메일');
    ServiceValidator.requireText(req.centerId, '센터 ID');
    ServiceValidator.requireText(req.centerName, '센터 이름');
    ServiceValidator.requireText(req.role, '가입 역할');
    if (req.role != UserRole.member.name && req.role != UserRole.trainer.name) {
      throw ArgumentError('가입 역할이 올바르지 않습니다.');
    }
    if (req.status != JoinRequestStatus.pending) {
      throw ArgumentError('새 가입 요청은 대기 상태여야 합니다.');
    }
  }

  static void _validateDateTimeRange({
    required DateTime? from,
    required DateTime? to,
    required String fieldName,
  }) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('$fieldName 시작일은 종료일보다 늦을 수 없습니다.');
    }
  }

  static void _validatePtInfo(PtInfo info) {
    ServiceValidator.requireText(info.id, 'PT 정보 ID');
    ServiceValidator.requireText(info.centerId, '센터 ID');
    ServiceValidator.requireText(info.memberId, '회원 ID');
    ServiceValidator.requireNonNegativeInt(info.totalSessions, '전체 PT 횟수');
    ServiceValidator.requireNonNegativeInt(info.remainingSessions, '잔여 PT 횟수');
    if (info.remainingSessions > info.totalSessions) {
      throw ArgumentError('잔여 PT 횟수는 전체 PT 횟수보다 클 수 없습니다.');
    }
  }

  /// 새 예약 전 확인: PT권이 있고, 만료 전이며, 이미 잡힌 예약을 빼고도 잔여가 남아야 한다
  /// (잔여 1회에 예약 5개를 잡아 두고 완료 때 막히는 일을 막는다).
  static Future<void> _requireRemainingPtSession({
    required String centerId,
    required String memberId,
    required String trainerId,
    required DateTime scheduledAt,
  }) async {
    final ptInfo = await getPtInfo(memberId, centerId: centerId);
    if (ptInfo == null) {
      throw ArgumentError('등록된 PT권이 없어 일정을 생성할 수 없습니다.');
    }
    _requireBeforePtEnd(ptInfo, scheduledAt);
    final booked = await _db
        .collection('pt_sessions')
        .where('centerId', isEqualTo: centerId)
        .where('trainerId', isEqualTo: trainerId)
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: PtSessionStatus.scheduled.name)
        .count()
        .get();
    final available = ptInfo.remainingSessions - (booked.count ?? 0);
    if (available <= 0) {
      throw ArgumentError(
        ptInfo.remainingSessions <= 0
            ? '잔여 PT 횟수가 없어 일정을 생성할 수 없습니다.'
            : '잔여 ${ptInfo.remainingSessions}회가 모두 예약돼 있어 더 잡을 수 없습니다.',
      );
    }
  }

  static void _requireBeforePtEnd(PtInfo ptInfo, DateTime scheduledAt) {
    final end = ptInfo.endDate;
    if (end != null &&
        DateTime(
          scheduledAt.year,
          scheduledAt.month,
          scheduledAt.day,
        ).isAfter(DateTime(end.year, end.month, end.day))) {
      throw ArgumentError(
        'PT권 종료일(${end.year}.${end.month}.${end.day}) 이후로는 예약할 수 없습니다.',
      );
    }
  }

  static Future<void> _commitInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
    Map<String, dynamic> data,
  ) async {
    const chunkSize = 450;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(chunkSize)) {
        batch.update(ref, data);
      }
      await batch.commit();
    }
  }

  static PtInfoLog _buildPtInfoLog({
    required String id,
    required PtInfo info,
    required PtInfo? previous,
    required PtInfoLogType type,
    String? changedById,
    String? changedByName,
    String? ptSessionId,
    String? note,
  }) {
    return PtInfoLog(
      id: id,
      ptInfoId: info.id,
      centerId: info.centerId,
      memberId: info.memberId,
      memberName: info.memberName,
      changedById: changedById,
      changedByName: changedByName,
      type: type,
      previousTotalSessions: previous?.totalSessions ?? 0,
      nextTotalSessions: info.totalSessions,
      previousRemainingSessions: previous?.remainingSessions ?? 0,
      nextRemainingSessions: info.remainingSessions,
      ptSessionId: ptSessionId,
      note: note,
      createdAt: DateTime.now(),
    );
  }
}

/// PT 세션 상태 변경 결과 (서버 함수 setPtSessionStatus).
/// [changed]가 false면 이미 그 상태여서 잔여 횟수도 그대로다.
class PtStatusResult {
  final bool changed;

  /// 바뀐 뒤 잔여 횟수 (PT권이 없거나 바뀌지 않았으면 null).
  final int? remainingSessions;

  const PtStatusResult({required this.changed, this.remainingSessions});
}
