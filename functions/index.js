const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');
const adminSetup = require('./admin_setup');
const accountDeletion = require('./account_deletion');
const retentionStore = require('./retention_store');
const inbox = require('./notifications');
const ptSessions = require('./pt_sessions');

initializeApp();

const db = getFirestore();

function formatSessionTime(timestamp) {
  if (!timestamp?.toDate) return '';
  return new Intl.DateTimeFormat('ko-KR', {
    timeZone: 'Asia/Seoul',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(timestamp.toDate());
}

function timestampMillis(timestamp) {
  return timestamp?.toMillis ? timestamp.toMillis() : null;
}

// ── 헬퍼: FCM 단건 발송 ──

function isInvalidTokenError(error) {
  return [
    'messaging/invalid-registration-token',
    'messaging/registration-token-not-registered',
  ].includes(error?.code);
}

async function clearToken(uid) {
  if (!uid) return;
  await db.collection('users').doc(uid).update({
    fcmToken: null,
    fcmTokenUpdatedAt: null,
  });
}

// 알림함에 남기고 푸시를 보낸다. 사용자 문서가 없으면(탈퇴 등) 아무것도 하지 않는다.
// 푸시가 꺼져 있거나 토큰이 없어도 알림함에는 남는다.
// dedupeKey(트리거 이벤트 ID 등)를 주면 같은 이벤트가 다시 전달돼도 알림이 두 번 생기지 않는다.
async function notifyUser(uid, title, body, data, dedupeKey) {
  if (!uid) return;
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) return;

  const inboxDoc = inbox.buildInboxDoc({
    title,
    body,
    data,
    createdAt: FieldValue.serverTimestamp(),
  });
  if (dedupeKey) {
    try {
      await userRef.collection('notifications').doc(`${dedupeKey}`.replace(/[^A-Za-z0-9_-]/g, '_')).create(inboxDoc);
    } catch (e) {
      if (e?.code === 6) return; // ALREADY_EXISTS: 이미 보낸 이벤트
      throw e;
    }
  } else {
    await userRef.collection('notifications').add(inboxDoc);
  }
  await sendNotification({ uid, token: snap.data().fcmToken ?? null }, title, body, data);
}

async function sendNotification(target, title, body, data = {}) {
  const token = typeof target === 'string' ? target : target?.token;
  const uid = typeof target === 'string' ? null : target?.uid;
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
      android: {
        notification: {
          sound: 'default',
          channelId: 'burnfit_default',
        },
      },
    });
  } catch (e) {
    console.error('[FCM] 발송 실패:', e.message);
    if (isInvalidTokenError(e)) {
      await clearToken(uid);
    }
  }
}

// ─────────────────────────────────────────────
// 1. PT 세션 등록 → 회원에게 알림
// ─────────────────────────────────────────────

exports.onPtSessionCreated = onDocumentCreated(
  'pt_sessions/{sessionId}',
  async (event) => {
    const session = event.data.data();
    if (!session) return;

    const dateStr = formatSessionTime(session.scheduledAt);

    await notifyUser(
      session.memberId,
      'PT 일정이 등록됐습니다',
      `${session.trainerName} 트레이너 · ${dateStr} · ${session.durationMinutes}분`,
      { type: 'pt_session_created', sessionId: event.params.sessionId },
      `${event.id}`,
    );
  },
);

// ─────────────────────────────────────────────
// 2. PT 세션 상태 변경 → 회원에게 알림
//    - scheduled → cancelled : 취소 알림
//    - scheduled → completed : 완료 알림 (선택적)
// ─────────────────────────────────────────────

exports.onPtSessionUpdated = onDocumentUpdated(
  'pt_sessions/{sessionId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const statusChanged = before.status !== after.status;
    // 담당 트레이너만 바뀐 경우(재배정)는 세션마다 알리지 않는다 — onUserUpdated가 한 번 알린다.
    const scheduleChanged =
      timestampMillis(before.scheduledAt) !== timestampMillis(after.scheduledAt) ||
      before.durationMinutes !== after.durationMinutes;

    if (!statusChanged && !scheduleChanged) return;

    const dateStr = formatSessionTime(after.scheduledAt);

    if (after.status === 'cancelled') {
      await notifyUser(
        after.memberId,
        'PT 일정이 취소됐습니다',
        `${dateStr} 세션이 취소됐습니다.`,
        { type: 'pt_session_cancelled', sessionId: event.params.sessionId },
        `${event.id}`,
      );
      return;
    }

    if (after.status === 'scheduled' && scheduleChanged) {
      await notifyUser(
        after.memberId,
        'PT 일정이 변경됐습니다',
        `${after.trainerName} 트레이너 · ${dateStr} · ${after.durationMinutes}분`,
        { type: 'pt_session_updated', sessionId: event.params.sessionId },
        `${event.id}`,
      );
    }
  },
);

// ─────────────────────────────────────────────
// 2-1. 사용자 변경 → 가입 승인 · 담당 트레이너 배정 알림
// ─────────────────────────────────────────────

exports.onUserUpdated = onDocumentUpdated(
  'users/{uid}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    const uid = event.params.uid;

    if (before.status !== 'approved' && after.status === 'approved') {
      await notifyUser(
        uid,
        '가입이 승인됐습니다',
        `${after.centerName ?? '센터'}에서 가입을 승인했어요. 지금 바로 이용할 수 있어요.`,
        { type: 'account_approved' },
        `${event.id}-approved`,
      );
    }

    if (after.role === 'member' && after.trainerId && before.trainerId !== after.trainerId) {
      await Promise.all([
        notifyUser(
          uid,
          '담당 트레이너가 배정됐습니다',
          `${after.trainerName ?? ''} 트레이너가 담당합니다.`,
          { type: 'trainer_assigned' },
          `${event.id}-member`,
        ),
        notifyUser(
          after.trainerId,
          '새 담당 회원',
          `${after.name ?? '회원'}님이 담당 회원으로 배정됐습니다.`,
          { type: 'member_assigned' },
          `${event.id}-trainer`,
        ),
      ]);
    }
  },
);

// ─────────────────────────────────────────────
// 3. 피드백 등록 → 회원에게 알림
// ─────────────────────────────────────────────

exports.onFeedbackCreated = onDocumentCreated(
  'feedbacks/{feedbackId}',
  async (event) => {
    const feedback = event.data.data();
    if (!feedback) return;

    const targetLabels = {
      meal: '식단',
      workout: '운동',
      cardio: '유산소',
      general: '전체',
    };
    const targetLabel = targetLabels[feedback.targetType] ?? '기록';
    const content = typeof feedback.content === 'string' ? feedback.content : '';
    const preview = content.length > 40 ? `${content.slice(0, 40)}...` : content;

    await notifyUser(
      feedback.memberId,
      `${feedback.trainerName ?? ''} 트레이너가 피드백을 남겼습니다`,
      `${targetLabel} 기록에 새 피드백: ${preview}`,
      { type: 'feedback_created', feedbackId: event.params.feedbackId },
      `${event.id}`,
    );
  },
);

// ─────────────────────────────────────────────
// 4. PT 잔여 횟수 경고 → 회원 + 트레이너에게 알림
//    pt_infos 업데이트 시 remainingSessions 가 3 이하가 되면 발송
// ─────────────────────────────────────────────

exports.onPtInfoUpdated = onDocumentUpdated(
  'pt_infos/{ptInfoId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const threshold = 3;
    const wasAbove = before.remainingSessions > threshold;
    const isBelow = after.remainingSessions <= threshold && after.remainingSessions > 0;

    // threshold 아래로 처음 진입했을 때만 발송
    if (!wasAbove || !isBelow) return;

    const message = `PT 잔여 횟수가 ${after.remainingSessions}회 남았습니다. 갱신을 확인해주세요.`;
    const data = { type: 'pt_remaining_warning', ptInfoId: event.params.ptInfoId };

    await Promise.all([
      notifyUser(after.memberId, 'PT 잔여 횟수 알림', message, data, `${event.id}-m`),
      notifyUser(after.trainerId, `${after.memberName}님 PT 잔여 횟수 알림`, message, data, `${event.id}-t`),
    ]);
  },
);

// ─────────────────────────────────────────────
// 5. 센터 관리자 가입 (callable)
//    설정 코드는 Secret Manager에만 두고 서버에서 검증한다.
//    관리자 계정·센터 문서는 이 함수만 만들 수 있다 (firestore.rules 참고).
// ─────────────────────────────────────────────

const ADMIN_SETUP_CODE = defineSecret('ADMIN_SETUP_CODE');

function userFacingError(code, message) {
  return new HttpsError(code, message, { userMessage: message });
}

// 시도 한 번을 먼저 기록(예약)한 뒤 코드를 비교한다. 확인과 기록을 한 트랜잭션에서 하므로
// 동시에 여러 요청을 보내도 '1시간 5회' 제한을 넘길 수 없다. 성공하면 기록을 지운다.
async function reserveAttempt(throttleRef) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(throttleRef);
    if (adminSetup.isThrottled(snap.data(), Date.now())) {
      throw userFacingError('resource-exhausted', '시도 횟수를 초과했습니다. 1시간 후 다시 시도해주세요.');
    }
    tx.set(throttleRef, adminSetup.nextFailureRecord(snap.data(), Date.now()));
  });
}

exports.registerCenterAdmin = onCall(
  { secrets: [ADMIN_SETUP_CODE] },
  async (request) => {
    let input;
    try {
      input = adminSetup.parseAdminSetupInput(request.data);
    } catch (e) {
      if (e instanceof adminSetup.InputError) throw userFacingError('invalid-argument', e.message);
      throw e;
    }

    const throttleRef = db
      .collection('security_throttles')
      .doc(adminSetup.throttleKey(request.rawRequest?.ip));
    await reserveAttempt(throttleRef);

    // 비밀값 저장 시 끝에 줄바꿈이 섞여도 맞도록 앞뒤 공백을 지우고 비교한다.
    if (!adminSetup.setupCodeMatches(input.setupCode, ADMIN_SETUP_CODE.value().trim())) {
      throw userFacingError('permission-denied', '설정 코드가 올바르지 않습니다.');
    }
    await throttleRef.delete().catch(() => {});

    let authUser;
    try {
      authUser = await getAuth().createUser({
        email: input.email,
        password: input.password,
        displayName: input.name,
      });
    } catch (e) {
      if (e?.code === 'auth/email-already-exists') {
        throw userFacingError('already-exists', '이미 가입된 이메일입니다.');
      }
      if (e?.code === 'auth/invalid-password') {
        throw userFacingError('invalid-argument', '비밀번호 형식이 올바르지 않습니다.');
      }
      console.error('[registerCenterAdmin] 계정 생성 실패:', e?.code);
      throw new HttpsError('internal', 'account-creation-failed');
    }

    const centerRef = db.collection('centers').doc();
    const now = FieldValue.serverTimestamp();
    try {
      const batch = db.batch();
      batch.create(centerRef, adminSetup.buildCenterDoc({
        centerId: centerRef.id,
        adminId: authUser.uid,
        centerName: input.centerName,
        centerAddress: input.centerAddress,
        now,
      }));
      batch.create(db.collection('users').doc(authUser.uid), adminSetup.buildAdminUserDoc({
        uid: authUser.uid,
        email: input.email,
        name: input.name,
        centerId: centerRef.id,
        centerName: input.centerName,
        now,
      }));
      batch.delete(throttleRef);
      await batch.commit();
    } catch (e) {
      // 문서 생성에 실패하면 고아 계정이 남지 않도록 인증 계정도 되돌린다.
      await getAuth().deleteUser(authUser.uid).catch((rollbackError) => {
        console.error('[registerCenterAdmin] 롤백 실패:', authUser.uid, rollbackError?.code);
      });
      console.error('[registerCenterAdmin] 문서 생성 실패:', e?.code);
      throw new HttpsError('internal', 'center-creation-failed');
    }

    return { uid: authUser.uid, centerId: centerRef.id };
  },
);

// ─────────────────────────────────────────────
// 6. 회원 탈퇴 (callable)
//    본인만, 방금 다시 로그인한 상태에서만 실행된다.
//    데이터 → 사용자 문서 → 인증 계정 순으로 지워서, 중간에 실패해도 다시 실행하면 이어진다.
// ─────────────────────────────────────────────

const DELETION_PAGE_SIZE = 300;
const DELETION_MAX_PAGES = 200;

// 쿼리 결과가 빌 때까지 한 페이지씩 처리한다.
// 지우거나, 갱신으로 조건에서 빠지는 문서에만 써야 한다 (계획의 updates가 모두 그렇다).
async function drainQuery(query, applyToRef) {
  let total = 0;
  for (let page = 0; page < DELETION_MAX_PAGES; page += 1) {
    const snap = await query.limit(DELETION_PAGE_SIZE).select().get();
    if (snap.empty) return total;
    const writer = db.bulkWriter();
    snap.docs.forEach((doc) => applyToRef(writer, doc.ref));
    await writer.close();
    total += snap.size;
  }
  throw new Error(`drainQuery: ${DELETION_MAX_PAGES} 페이지를 넘었습니다`);
}

async function executeDeletionPlan(plan, uid, userRef) {
  if (plan.retains.length > 0) {
    const prep = await retentionStore.prepareRetention(db, userRef, uid);
    for (const source of plan.retains) {
      await retentionStore.moveToRetention(db, source, uid, prep);
    }
  }
  for (const { collection, where, data } of plan.updates) {
    let query = db.collection(collection);
    for (const [field, op, value] of where) query = query.where(field, op, value);
    const payload = { ...data, updatedAt: FieldValue.serverTimestamp() };
    await drainQuery(query, (writer, ref) => writer.update(ref, payload));
  }
  for (const { collection, field } of plan.deletes) {
    await drainQuery(
      db.collection(collection).where(field, '==', uid),
      (writer, ref) => writer.delete(ref),
    );
  }
  for (const prefix of plan.storagePrefixes) {
    await getStorage().bucket().deleteFiles({ prefix });
  }
}

exports.deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw userFacingError('unauthenticated', '로그인이 필요합니다.');
  if (!accountDeletion.isRecentLogin(request.auth.token?.auth_time, Date.now())) {
    throw userFacingError('failed-precondition', '보안을 위해 비밀번호를 다시 입력해주세요.');
  }

  const userRef = db.collection('users').doc(uid);
  const user = (await userRef.get()).data();

  let plan;
  try {
    plan = accountDeletion.buildDeletionPlan(user, uid);
  } catch (e) {
    if (e instanceof accountDeletion.DeletionRefused) throw userFacingError(e.code, e.message);
    throw e;
  }

  try {
    await executeDeletionPlan(plan, uid, userRef);
    // 사용자 문서와 하위 알림함(notifications)을 함께 지운다.
    await db.recursiveDelete(userRef);
    await getAuth().deleteUser(uid);
  } catch (e) {
    console.error('[deleteMyAccount] 실패:', uid, e?.code ?? e?.message);
    throw userFacingError('internal', '탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
  }

  console.log('[deleteMyAccount] 완료:', uid, user?.role ?? 'unknown');
  return { deleted: true };
});

// ─────────────────────────────────────────────
// 6-1. PT 세션 상태 변경 (완료 · 완료 취소 · 예약 취소)
//    잔여 횟수와 변경 기록은 서버에서만 바꾼다. 같은 상태로 다시 부르면 아무 일도 없다 (재시도 안전).
// ─────────────────────────────────────────────

exports.setPtSessionStatus = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw userFacingError('unauthenticated', '로그인이 필요합니다.');
  const sessionId = request.data?.sessionId;
  const nextStatus = request.data?.status;
  if (typeof sessionId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(sessionId)) {
    throw userFacingError('invalid-argument', '세션 정보가 올바르지 않습니다.');
  }
  if (!ptSessions.STATUSES.includes(nextStatus)) {
    throw userFacingError('invalid-argument', '알 수 없는 세션 상태입니다.');
  }

  const callerSnap = await db.collection('users').doc(uid).get();
  const caller = callerSnap.data();
  const sessionRef = db.collection('pt_sessions').doc(sessionId);

  try {
    return await db.runTransaction(async (tx) => {
      const sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw new ptSessions.PtStatusRefused('not-found', 'PT 일정을 찾을 수 없습니다.');
      const session = sessionSnap.data();
      const memberSnap = await tx.get(db.collection('users').doc(session.memberId));
      if (!ptSessions.canChangeSession({ caller, callerUid: uid, session, member: memberSnap.data() })) {
        throw new ptSessions.PtStatusRefused('permission-denied', '이 PT 일정을 바꿀 권한이 없습니다.');
      }

      const ptQuery = await tx.get(
        db.collection('pt_infos')
          .where('centerId', '==', session.centerId)
          .where('memberId', '==', session.memberId)
          .limit(1),
      );
      const ptDoc = ptQuery.docs[0];
      const plan = ptSessions.planStatusChange({
        session,
        ptInfo: ptDoc?.data(),
        nextStatus,
      });
      if (!plan.changed) return { changed: false };

      tx.update(sessionRef, { status: nextStatus, updatedAt: FieldValue.serverTimestamp() });
      if (plan.remaining && ptDoc) {
        const pt = ptDoc.data();
        tx.update(ptDoc.ref, {
          remainingSessions: plan.remaining.next,
          updatedAt: FieldValue.serverTimestamp(),
        });
        const logRef = db.collection('pt_info_logs').doc();
        tx.set(logRef, {
          id: logRef.id,
          ptInfoId: ptDoc.id,
          centerId: session.centerId,
          memberId: session.memberId,
          memberName: pt.memberName ?? session.memberName ?? '',
          changedById: uid,
          changedByName: caller?.name ?? '',
          type: plan.logType,
          previousTotalSessions: plan.remaining.total,
          nextTotalSessions: plan.remaining.total,
          previousRemainingSessions: plan.remaining.previous,
          nextRemainingSessions: plan.remaining.next,
          ptSessionId: sessionId,
          note: null,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      return { changed: true, remainingSessions: plan.remaining?.next ?? null };
    });
  } catch (e) {
    if (e instanceof ptSessions.PtStatusRefused) throw userFacingError(e.code, e.message);
    console.error('[setPtSessionStatus] 실패:', sessionId, e?.code ?? e?.message);
    throw userFacingError('internal', 'PT 일정 상태를 바꾸지 못했습니다. 잠시 후 다시 시도해주세요.');
  }
});

// ─────────────────────────────────────────────
// 7. 탈퇴 회원 PT 이력 파기 (매일 04:00 KST)
//    retained_pt_records는 만료일(PT 종료일·탈퇴일 중 늦은 날 + 3년)이 지나면 지운다.
// ─────────────────────────────────────────────

exports.purgeExpiredRetainedRecords = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'Asia/Seoul' },
  async () => {
    const purged = await retentionStore.purgeExpired(db);
    console.log('[purgeExpiredRetainedRecords] 파기:', purged);
  },
);

// ─────────────────────────────────────────────
// 8. 알림함 정리 (매일 04:30 KST) — 90일 지난 알림 삭제
// ─────────────────────────────────────────────

exports.purgeOldNotifications = onSchedule(
  { schedule: 'every day 04:30', timeZone: 'Asia/Seoul' },
  async () => {
    const cutoff = Timestamp.fromDate(inbox.inboxCutoff());
    const purged = await drainQuery(
      db.collectionGroup('notifications').where('createdAt', '<', cutoff),
      (writer, ref) => writer.delete(ref),
    );
    console.log('[purgeOldNotifications] 삭제:', purged);
  },
);
