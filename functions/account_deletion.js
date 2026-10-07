// 회원 탈퇴(deleteMyAccount)의 순수 로직: 역할별로 무엇을 지우고 무엇을 정리할지 정한다.
// Firebase에 의존하지 않아 단위 테스트할 수 있다.

// 탈퇴 직전 다시 로그인한 지 이 시간 안이어야 한다 (탈취된 세션으로 탈퇴하는 것 방지).
const RECENT_LOGIN_MAX_AGE_SEC = 5 * 60;

// 회원 본인의 기록 (memberId로 연결). 탈퇴 시 모두 지운다.
const MEMBER_OWNED_COLLECTIONS = [
  'workouts',
  'meals',
  'cardios',
  'feedbacks',
  'inbodies',
  'pt_infos',
  'pt_sessions',
  'pt_info_logs',
];

class DeletionRefused extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function isRecentLogin(authTimeSec, nowMs) {
  if (typeof authTimeSec !== 'number') return false;
  const ageSec = nowMs / 1000 - authTimeSec;
  return ageSec >= 0 && ageSec <= RECENT_LOGIN_MAX_AGE_SEC;
}

/**
 * 역할별 탈퇴 계획.
 * - deletes: 지울 문서 (collection, field == uid)
 * - updates: 남기되 연결을 끊을 문서 (collection, where[], data)
 * - storagePrefixes: 지울 Storage 경로
 *
 * 관리자는 센터가 주인 없이 남으므로 앱에서 탈퇴할 수 없다.
 */
function buildDeletionPlan(user, uid) {
  const role = user?.role;
  const centerId = user?.centerId;

  if (role === 'admin') {
    throw new DeletionRefused(
      'failed-precondition',
      '센터 관리자 계정은 앱에서 탈퇴할 수 없습니다. 관리자 변경 후 다시 시도하거나 고객센터로 문의해주세요.',
    );
  }

  const common = [
    { collection: 'custom_exercises', field: 'memberId' },
    { collection: 'join_requests', field: 'userId' },
  ];

  if (role === 'member') {
    return {
      deletes: [
        ...MEMBER_OWNED_COLLECTIONS.map((collection) => ({ collection, field: 'memberId' })),
        ...common,
      ],
      updates: [],
      storagePrefixes: centerId ? [`${centerId}/meals/${uid}/`] : [],
    };
  }

  if (role === 'trainer') {
    return {
      deletes: common,
      updates: [
        // 담당 회원은 '트레이너 미배정'으로 돌린다.
        {
          collection: 'users',
          where: [['trainerId', '==', uid]],
          data: { trainerId: null, trainerName: null },
        },
        // 예정된 PT는 취소한다 (회원에게 취소 알림이 간다).
        {
          collection: 'pt_sessions',
          where: [['trainerId', '==', uid], ['status', '==', 'scheduled']],
          data: { status: 'cancelled' },
        },
        {
          collection: 'pt_infos',
          where: [['trainerId', '==', uid]],
          data: { trainerId: null },
        },
      ],
      storagePrefixes: [],
    };
  }

  // 사용자 문서가 없거나 역할이 비정상인 계정: 가입 신청만 정리한다.
  return { deletes: common, updates: [], storagePrefixes: [] };
}

module.exports = {
  RECENT_LOGIN_MAX_AGE_SEC,
  MEMBER_OWNED_COLLECTIONS,
  DeletionRefused,
  isRecentLogin,
  buildDeletionPlan,
};
