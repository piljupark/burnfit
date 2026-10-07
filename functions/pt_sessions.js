// PT 세션 상태 변경(완료·완료 취소·예약 취소)의 순수 로직.
// 잔여 횟수는 이 경로(setPtSessionStatus)로만 바뀐다 — 클라이언트 규칙은 트레이너의 잔여 횟수 쓰기를 막는다.
// Firebase에 의존하지 않아 단위 테스트할 수 있다.

const STATUSES = ['scheduled', 'completed', 'cancelled'];

class PtStatusRefused extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * 요청자가 이 세션의 상태를 바꿀 수 있는지.
 * - 같은 센터의 승인된 관리자
 * - 세션 담당이자 회원의 현재 담당인 같은 센터의 승인된 트레이너
 */
function canChangeSession({ caller, callerUid, session, member }) {
  if (!caller || caller.status !== 'approved') return false;
  if (caller.centerId !== session.centerId) return false;
  if (caller.role === 'admin') return true;
  return (
    caller.role === 'trainer' &&
    session.trainerId === callerUid &&
    member?.trainerId === callerUid &&
    member?.centerId === session.centerId
  );
}

/**
 * 상태 전환 계획. 바뀔 것이 없으면 { changed: false }.
 * 완료로 바뀌면 잔여 -1, 완료에서 다른 상태로 바뀌면 잔여 +1 (0 ~ 전체 범위).
 */
function planStatusChange({ session, ptInfo, nextStatus }) {
  if (!STATUSES.includes(nextStatus)) {
    throw new PtStatusRefused('invalid-argument', '알 수 없는 세션 상태입니다.');
  }
  if (session.status === nextStatus) return { changed: false };

  const decrease = session.status !== 'completed' && nextStatus === 'completed';
  const restore = session.status === 'completed' && nextStatus !== 'completed';
  if (!decrease && !restore) {
    return { changed: true, remaining: null, logType: null };
  }

  if (!ptInfo) {
    if (decrease) {
      throw new PtStatusRefused('failed-precondition', '등록된 PT권이 없어 완료 처리할 수 없습니다.');
    }
    return { changed: true, remaining: null, logType: null };
  }

  const total = Number(ptInfo.totalSessions) || 0;
  const current = Number(ptInfo.remainingSessions) || 0;
  if (decrease && current <= 0) {
    throw new PtStatusRefused('failed-precondition', '잔여 PT 횟수가 없어 완료 처리할 수 없습니다.');
  }
  const next = Math.min(total, Math.max(0, decrease ? current - 1 : current + 1));
  return {
    changed: true,
    remaining: { previous: current, next, total },
    logType: decrease ? 'sessionCompleted' : 'sessionReopened',
  };
}

module.exports = { STATUSES, PtStatusRefused, canChangeSession, planStatusChange };
