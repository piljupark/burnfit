import 'package:cloud_firestore/cloud_firestore.dart';
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

    final snap = await _db
        .collection('centers')
        .where('status', isEqualTo: 'active')
        .get();
    final all = snap.docs.map((d) => center_model.Center.fromMap(d.data()));
    if (q.isEmpty) return all.toList();
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  static Future<void> createCenter(center_model.Center center) async {
    _validateCenter(center);

    await _db.collection('centers').doc(center.id).set(center.toMap());
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

  static Future<void> savePtInfo(
    PtInfo info, {
    String? changedById,
    String? changedByName,
    String? note,
    PtInfo? previousInfo,
    bool fetchPreviousInfo = true,
  }) async {
    _validatePtInfo(info);
    final ptInfoRef = _db.collection('pt_infos').doc(info.id);
    final logRef = _db.collection('pt_info_logs').doc();

    if (!fetchPreviousInfo || previousInfo != null) {
      final batch = _db.batch();
      batch.set(ptInfoRef, info.toMap());
      batch.set(
        logRef,
        _buildPtInfoLog(
          id: logRef.id,
          info: info,
          previous: previousInfo,
          type: previousInfo == null
              ? PtInfoLogType.created
              : PtInfoLogType.updated,
          changedById: changedById,
          changedByName: changedByName,
          note: note,
        ).toMap(),
      );
      await batch.commit();
      return;
    }

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ptInfoRef);
      final previous = snap.exists ? PtInfo.fromMap(snap.data()!) : null;
      transaction.set(ptInfoRef, info.toMap());
      transaction.set(
        logRef,
        _buildPtInfoLog(
          id: logRef.id,
          info: info,
          previous: previous,
          type: previous == null
              ? PtInfoLogType.created
              : PtInfoLogType.updated,
          changedById: changedById,
          changedByName: changedByName,
          note: note,
        ).toMap(),
      );
    });
  }

  static Future<void> updatePtInfo(String id, Map<String, dynamic> data) async {
    ServiceValidator.requireText(id, 'PT 정보 ID');
    if (data.isEmpty) {
      throw ArgumentError('수정할 PT권 정보가 없습니다.');
    }
    _validatePtInfoUpdate(data);

    final payload = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    await _db.collection('pt_infos').doc(id).update(payload);
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

  static Future<fb.Feedback?> getFeedbackByTarget(
    String targetId, {
    String? centerId,
    String? memberId,
    String? trainerId,
  }) async {
    ServiceValidator.requireText(targetId, '피드백 대상 ID');
    if (centerId != null) {
      ServiceValidator.requireText(centerId, '센터 ID');
    }
    if (memberId != null) {
      ServiceValidator.requireText(memberId, '회원 ID');
    }
    if (trainerId != null) {
      ServiceValidator.requireText(trainerId, '트레이너 ID');
    }

    Query query = _db
        .collection('feedbacks')
        .where('targetId', isEqualTo: targetId)
        .limit(1);
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    if (memberId != null) {
      query = query.where('memberId', isEqualTo: memberId);
    }
    if (trainerId != null) {
      query = query.where('trainerId', isEqualTo: trainerId);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return null;
    return fb.Feedback.fromMap(snap.docs.first.data() as Map<String, dynamic>);
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
    );
    await _db.collection('pt_sessions').doc(session.id).set(session.toMap());
  }

  static Future<void> updatePtSessionSchedule({
    required String sessionId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? note,
  }) async {
    ServiceValidator.requireText(sessionId, 'PT 세션 ID');
    ServiceValidator.requirePositiveInt(durationMinutes, 'PT 시간');
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

  static Future<void> updatePtSessionStatus(
    String sessionId,
    PtSessionStatus status,
  ) async {
    final sessionRef = _db.collection('pt_sessions').doc(sessionId);
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) return;

    final currentSession = PtSession.fromMap(sessionSnap.data()!);
    final ptInfoQuery = await _db
        .collection('pt_infos')
        .where('centerId', isEqualTo: currentSession.centerId)
        .where('memberId', isEqualTo: currentSession.memberId)
        .limit(1)
        .get();
    final ptInfoRef = ptInfoQuery.docs.isEmpty
        ? null
        : ptInfoQuery.docs.first.reference;

    await _db.runTransaction((transaction) async {
      final freshSessionSnap = await transaction.get(sessionRef);
      if (!freshSessionSnap.exists) return;

      final session = PtSession.fromMap(freshSessionSnap.data()!);
      if (session.status == status) return;

      final shouldDecreaseRemaining =
          session.status != PtSessionStatus.completed &&
          status == PtSessionStatus.completed;
      final shouldRestoreRemaining =
          session.status == PtSessionStatus.completed &&
          status != PtSessionStatus.completed;

      if (!shouldDecreaseRemaining && !shouldRestoreRemaining) {
        transaction.update(sessionRef, {
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      if (ptInfoRef == null) {
        if (shouldDecreaseRemaining) {
          throw ArgumentError('등록된 PT권이 없어 완료 처리할 수 없습니다.');
        }
        transaction.update(sessionRef, {
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final ptInfoSnap = await transaction.get(ptInfoRef);
      if (!ptInfoSnap.exists) {
        if (shouldDecreaseRemaining) {
          throw ArgumentError('등록된 PT권이 없어 완료 처리할 수 없습니다.');
        }
        transaction.update(sessionRef, {
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final ptInfo = PtInfo.fromMap(ptInfoSnap.data()!);
      if (shouldDecreaseRemaining && ptInfo.remainingSessions <= 0) {
        throw ArgumentError('잔여 PT 횟수가 없어 완료 처리할 수 없습니다.');
      }
      final nextRemaining = shouldDecreaseRemaining
          ? (ptInfo.remainingSessions - 1).clamp(0, ptInfo.totalSessions)
          : (ptInfo.remainingSessions + 1).clamp(0, ptInfo.totalSessions);

      transaction.update(sessionRef, {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(ptInfoRef, {
        'remainingSessions': nextRemaining,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final logRef = _db.collection('pt_info_logs').doc();
      transaction.set(
        logRef,
        _buildPtInfoLog(
          id: logRef.id,
          info: PtInfo(
            id: ptInfo.id,
            centerId: ptInfo.centerId,
            memberId: ptInfo.memberId,
            memberName: ptInfo.memberName,
            trainerId: ptInfo.trainerId,
            startDate: ptInfo.startDate,
            endDate: ptInfo.endDate,
            totalSessions: ptInfo.totalSessions,
            remainingSessions: nextRemaining,
            renewalDate: ptInfo.renewalDate,
            createdAt: ptInfo.createdAt,
            updatedAt: DateTime.now(),
          ),
          previous: ptInfo,
          type: shouldDecreaseRemaining
              ? PtInfoLogType.sessionCompleted
              : PtInfoLogType.sessionReopened,
          changedById: session.trainerId,
          changedByName: session.trainerName,
          ptSessionId: session.id,
        ).toMap(),
      );
    });
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

  static Future<void> assignTrainer(
    String memberId,
    String trainerId,
    String trainerName,
  ) async {
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(trainerId, '트레이너 ID');
    ServiceValidator.requireText(trainerName, '트레이너 이름');

    final memberRef = _db.collection('users').doc(memberId);
    final ptInfoSnap = await _db
        .collection('pt_infos')
        .where('memberId', isEqualTo: memberId)
        .get();
    final sessionSnap = await _db
        .collection('pt_sessions')
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: PtSessionStatus.scheduled.name)
        .get();

    await _commitInChunks(
      [memberRef, ...sessionSnap.docs.map((doc) => doc.reference)],
      {
        'trainerId': trainerId,
        'trainerName': trainerName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _commitInChunks(
      ptInfoSnap.docs.map((doc) => doc.reference).toList(),
      {'trainerId': trainerId, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  static Future<void> createAdmin({
    required AppUser admin,
    required center_model.Center center,
  }) async {
    _validateUser(admin);
    _validateCenter(center);

    final batch = _db.batch();
    batch.set(_db.collection('users').doc(admin.uid), admin.toMap());
    batch.set(_db.collection('centers').doc(center.id), center.toMap());
    await batch.commit();
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
      _db
          .collection('pt_sessions')
          .where('centerId', isEqualTo: centerId)
          .where('status', isEqualTo: 'completed')
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('scheduledAt', isLessThan: Timestamp.fromDate(monthEnd))
          .get(),
      _db
          .collection('pt_sessions')
          .where('centerId', isEqualTo: centerId)
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get(),
      _db
          .collection('pt_infos')
          .where('centerId', isEqualTo: centerId)
          .where('remainingSessions', isGreaterThan: 0)
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

    final completedSessions = results[2].docs
        .map((d) => PtSession.fromMap(d.data()))
        .toList();

    final upcomingSessions = results[3].docs
        .map((d) => PtSession.fromMap(d.data()))
        .toList();

    final lowPtInfos =
        results[4].docs.map((d) => PtInfo.fromMap(d.data())).toList()
          ..sort((a, b) => a.remainingSessions.compareTo(b.remainingSessions));

    final todaySessions = results[5].docs
        .map((d) => PtSession.fromMap(d.data()))
        .toList();
    final todayScheduledSessions = todaySessions
        .where((s) => s.status == PtSessionStatus.scheduled)
        .length;
    final todayCompletedSessions = todaySessions
        .where((s) => s.status == PtSessionStatus.completed)
        .length;

    final expiringPtInfos =
        results[6].docs.map((d) => PtInfo.fromMap(d.data())).toList()
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
    final monthlyScheduledTotal =
        completedSessions.length + upcomingSessions.length;
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

  static void _validateCenter(center_model.Center center) {
    ServiceValidator.requireText(center.id, '센터 ID');
    ServiceValidator.requireText(center.name, '센터 이름');
    ServiceValidator.requireText(center.adminId, '관리자 ID');
    ServiceValidator.requireText(center.status, '센터 상태');
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

  static Future<void> _requireRemainingPtSession({
    required String centerId,
    required String memberId,
  }) async {
    final ptInfo = await getPtInfo(memberId, centerId: centerId);
    if (ptInfo == null) {
      throw ArgumentError('등록된 PT권이 없어 일정을 생성할 수 없습니다.');
    }
    if (ptInfo.remainingSessions <= 0) {
      throw ArgumentError('잔여 PT 횟수가 없어 일정을 생성할 수 없습니다.');
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

  static void _validatePtInfoUpdate(Map<String, dynamic> data) {
    final total = data['totalSessions'];
    final remaining = data['remainingSessions'];

    if (total is int) {
      ServiceValidator.requireNonNegativeInt(total, '전체 PT 횟수');
    }
    if (remaining is int) {
      ServiceValidator.requireNonNegativeInt(remaining, '잔여 PT 횟수');
    }
    if (total is int && remaining is int && remaining > total) {
      throw ArgumentError('잔여 PT 횟수는 전체 PT 횟수보다 클 수 없습니다.');
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
