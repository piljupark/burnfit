// 회원 탈퇴(deleteMyAccount)의 순수 로직: 역할별로 무엇을 지우고 무엇을 정리할지 정한다.
// Firebase에 의존하지 않아 단위 테스트할 수 있다.

// 탈퇴 직전 다시 로그인한 지 이 시간 안이어야 한다 (탈취된 세션으로 탈퇴하는 것 방지).
const RECENT_LOGIN_MAX_AGE_SEC = 5 * 60;

// 회원 본인의 기록 중 탈퇴 즉시 지우는 것 (memberId로 연결). 건강·생활 기록이다.
const MEMBER_DELETED_COLLECTIONS = [
  'workouts',
  'meals',
  'cardios',
  'feedbacks',
  'inbodies',
];

// PT 계약·이용 내역: 환불 등 분쟁 대응을 위해 회원을 알 수 없게 바꿔 보관한다.
// keep: 남길 필드 (회원 ID·이름, 자유 메모는 남기지 않는다)
const RETAINED_COLLECTION = 'retained_pt_records';
const RETENTION_YEARS = 3;
const MEMBER_RETAINED_SOURCES = [
  {
    collection: 'pt_infos',
    kind: 'pt_info',
    keep: [
      'centerId', 'trainerId', 'trainerName', 'startDate', 'endDate', 'totalSessions',
      'remainingSessions', 'renewalDate', 'createdAt', 'updatedAt',
    ],
  },
  {
    collection: 'pt_sessions',
    kind: 'pt_session',
    keep: [
      'centerId', 'trainerId', 'trainerName', 'scheduledAt', 'durationMinutes',
      'status', 'createdAt', 'updatedAt',
    ],
  },
  {
    collection: 'pt_info_logs',
    kind: 'pt_info_log',
    keep: [
      'centerId', 'ptInfoId', 'ptSessionId', 'changedById', 'changedByName', 'type',
      'previousTotalSessions', 'nextTotalSessions',
      'previousRemainingSessions', 'nextRemainingSessions', 'createdAt',
    ],
  },
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
 * - retains: 회원을 알 수 없게 바꿔 보관한 뒤 원본을 지울 문서 (MEMBER_RETAINED_SOURCES)
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
      retains: MEMBER_RETAINED_SOURCES,
      deletes: [
        ...MEMBER_DELETED_COLLECTIONS.map((collection) => ({ collection, field: 'memberId' })),
        ...common,
      ],
      updates: [],
      storagePrefixes: centerId ? [`${centerId}/meals/${uid}/`] : [],
    };
  }

  if (role === 'trainer') {
    return {
      retains: [],
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
  return { retains: [], deletes: common, updates: [], storagePrefixes: [] };
}

function toMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

/**
 * 보관 만료 시각: PT 종료일과 탈퇴일 중 늦은 날로부터 RETENTION_YEARS년.
 * 아직 진행 중인 PT를 두고 탈퇴해도 종료 후 3년은 근거가 남는다.
 */
function retentionExpiry(ptInfos, nowMs) {
  const endMs = ptInfos
    .map((info) => toMillis(info?.endDate))
    .filter((ms) => ms != null);
  const base = new Date(Math.max(nowMs, ...endMs));
  base.setFullYear(base.getFullYear() + RETENTION_YEARS);
  return base;
}

/**
 * 보관용 문서. 원본 문서 ID를 키로 써서 재시도해도 중복되지 않는다.
 * PT 계약에는 담당 이름이 없으므로, 탈퇴 직전 회원의 담당이 그 계약의 담당과 같으면
 * 그 이름([memberTrainer])을 함께 남긴다 (트레이너가 나중에 바뀌거나 퇴사해도 기록에서 알아볼 수 있게).
 */
function buildRetainedRecord({ source, sourceId, data, memberAlias, retainedAt, expireAt, memberTrainer }) {
  const kept = {};
  for (const field of source.keep) {
    if (data[field] !== undefined) kept[field] = data[field];
  }
  if (
    source.kind === 'pt_info' &&
    kept.trainerName === undefined &&
    typeof memberTrainer?.name === 'string' &&
    memberTrainer.id != null &&
    memberTrainer.id === data.trainerId
  ) {
    kept.trainerName = memberTrainer.name;
  }
  return {
    id: `${source.kind}_${sourceId}`,
    doc: {
      kind: source.kind,
      sourceId,
      centerId: data.centerId ?? null,
      memberAlias,
      data: kept,
      retainedAt,
      expireAt,
    },
  };
}

module.exports = {
  RECENT_LOGIN_MAX_AGE_SEC,
  MEMBER_DELETED_COLLECTIONS,
  MEMBER_RETAINED_SOURCES,
  RETAINED_COLLECTION,
  RETENTION_YEARS,
  DeletionRefused,
  isRecentLogin,
  buildDeletionPlan,
  retentionExpiry,
  buildRetainedRecord,
};
