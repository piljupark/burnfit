// 알림함(users/{uid}/notifications)의 순수 로직. 앱 모델: lib/models/app_notification.dart

// 알림함 보관 기간. 지나면 매일 파기 작업이 지운다.
const INBOX_RETENTION_DAYS = 90;

// FCM data에서 알림이 가리키는 문서 ID를 꺼낸다.
const TARGET_ID_KEYS = ['sessionId', 'feedbackId', 'ptInfoId', 'noticeId', 'mealId'];

function buildInboxDoc({ title, body, data, createdAt }) {
  const targetKey = TARGET_ID_KEYS.find((key) => typeof data?.[key] === 'string');
  return {
    type: typeof data?.type === 'string' ? data.type : 'unknown',
    title: String(title ?? ''),
    body: String(body ?? ''),
    targetId: targetKey ? data[targetKey] : null,
    createdAt,
    readAt: null,
  };
}

function inboxCutoff(now = new Date()) {
  return new Date(now.getTime() - INBOX_RETENTION_DAYS * 24 * 60 * 60 * 1000);
}

module.exports = { INBOX_RETENTION_DAYS, buildInboxDoc, inboxCutoff };
