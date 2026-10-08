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

module.exports = { noticeRecipientRoles, isNoticeRecipient, buildNoticeMessage };
