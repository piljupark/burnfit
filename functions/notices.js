// 공지 푸시: 대상 역할 계산과 알림 문구 (순수 함수, index.js의 onNoticeCreated가 사용).

const AUDIENCE_ROLES = {
  all: ['member', 'trainer'],
  member: ['member'],
  trainer: ['trainer'],
};

/** 공지 대상(audience)에 해당하는 수신 역할. 알 수 없는 값이면 빈 배열(아무에게도 보내지 않음). */
function noticeRecipientRoles(audience) {
  return AUDIENCE_ROLES[audience] ?? [];
}

/** 알림을 받을 사용자인지: 같은 센터 · 승인됨 · 대상 역할 · 작성자 본인 아님. */
function isNoticeRecipient(user, notice) {
  if (!user || !notice) return false;
  return user.centerId === notice.centerId &&
    user.status === 'approved' &&
    noticeRecipientRoles(notice.audience).includes(user.role) &&
    user.uid !== notice.authorId;
}

function buildNoticeMessage(notice) {
  const title = typeof notice?.title === 'string' ? notice.title : '';
  const body = typeof notice?.body === 'string' ? notice.body : '';
  const preview = body.length > 60 ? `${body.slice(0, 60)}...` : body;
  return {
    title: notice?.important === true ? `[중요] ${title}` : `새 공지: ${title}`,
    body: preview,
  };
}

/** 센터마다 하루에 보낼 수 있는 공지 푸시 수 (반복 등록으로 전원에게 알림이 쏟아지지 않게). */
const DAILY_NOTICE_PUSH_LIMIT = 10;

/** 한국 시간 기준 날짜 열쇠 'YYYYMMDD' (하루 횟수를 세는 단위). */
function noticePushDayKey(date) {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, '0');
  const d = String(kst.getUTCDate()).padStart(2, '0');
  return `${y}${m}${d}`;
}

/** 오늘 이미 보낸 수가 [sentToday]일 때 하나 더 보내도 되는지. */
function canSendNoticePush(sentToday, limit = DAILY_NOTICE_PUSH_LIMIT) {
  const n = Number.isInteger(sentToday) && sentToday > 0 ? sentToday : 0;
  return n < limit;
}

module.exports = {
  noticeRecipientRoles,
  isNoticeRecipient,
  buildNoticeMessage,
  DAILY_NOTICE_PUSH_LIMIT,
  noticePushDayKey,
  canSendNoticePush,
};
