const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

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

// ── 헬퍼: FCM 토큰 조회 ──

async function getToken(uid) {
  const doc = await db.collection('users').doc(uid).get();
  return { uid, token: doc.data()?.fcmToken ?? null };
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

    const target = await getToken(session.memberId);

    const dateStr = formatSessionTime(session.scheduledAt);

    await sendNotification(
      target,
      'PT 일정이 등록됐습니다',
      `${session.trainerName} 트레이너 · ${dateStr} · ${session.durationMinutes}분`,
      { type: 'pt_session_created', sessionId: event.params.sessionId },
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
    const scheduleChanged =
      timestampMillis(before.scheduledAt) !== timestampMillis(after.scheduledAt) ||
      before.durationMinutes !== after.durationMinutes ||
      before.trainerId !== after.trainerId;

    if (!statusChanged && !scheduleChanged) return;

    const target = await getToken(after.memberId);

    const dateStr = formatSessionTime(after.scheduledAt);

    if (after.status === 'cancelled') {
      await sendNotification(
        target,
        'PT 일정이 취소됐습니다',
        `${dateStr} 세션이 취소됐습니다.`,
        { type: 'pt_session_cancelled', sessionId: event.params.sessionId },
      );
      return;
    }

    if (after.status === 'scheduled' && scheduleChanged) {
      await sendNotification(
        target,
        'PT 일정이 변경됐습니다',
        `${after.trainerName} 트레이너 · ${dateStr} · ${after.durationMinutes}분`,
        { type: 'pt_session_updated', sessionId: event.params.sessionId },
      );
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

    const target = await getToken(feedback.memberId);

    const targetLabels = {
      meal: '식단',
      workout: '운동',
      cardio: '유산소',
      general: '전체',
    };
    const targetLabel = targetLabels[feedback.targetType] ?? '기록';

    await sendNotification(
      target,
      `${feedback.trainerName} 트레이너가 피드백을 남겼습니다`,
      `${targetLabel} 기록에 새 피드백: ${feedback.content.slice(0, 40)}${feedback.content.length > 40 ? '...' : ''}`,
      { type: 'feedback_created', feedbackId: event.params.feedbackId },
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

    const [memberTarget, trainerTarget] = await Promise.all([
      getToken(after.memberId),
      after.trainerId ? getToken(after.trainerId) : Promise.resolve(null),
    ]);

    const message = `PT 잔여 횟수가 ${after.remainingSessions}회 남았습니다. 갱신을 확인해주세요.`;
    const data = { type: 'pt_remaining_warning', ptInfoId: event.params.ptInfoId };

    await Promise.all([
      sendNotification(memberTarget, 'PT 잔여 횟수 알림', message, data),
      sendNotification(trainerTarget, `${after.memberName}님 PT 잔여 횟수 알림`, message, data),
    ]);
  },
);
