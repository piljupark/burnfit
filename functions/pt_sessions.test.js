const { describe, it } = require('node:test');
const assert = require('assert');
const { canChangeSession, planStatusChange, PtStatusRefused } = require('./pt_sessions');

const session = { centerId: 'c1', memberId: 'm1', trainerId: 't1', status: 'scheduled' };

describe('canChangeSession', () => {
  const member = { centerId: 'c1', trainerId: 't1' };
  it('세션 담당이자 회원 담당인 승인된 트레이너는 바꿀 수 있다', () => {
    assert.ok(canChangeSession({ caller: { role: 'trainer', status: 'approved', centerId: 'c1' }, callerUid: 't1', session, member }));
  });
  it('담당이 바뀐 트레이너·다른 트레이너·승인 대기·다른 센터는 안 된다', () => {
    assert.ok(!canChangeSession({ caller: { role: 'trainer', status: 'approved', centerId: 'c1' }, callerUid: 't1', session, member: { centerId: 'c1', trainerId: 't2' } }));
    assert.ok(!canChangeSession({ caller: { role: 'trainer', status: 'approved', centerId: 'c1' }, callerUid: 't2', session, member }));
    assert.ok(!canChangeSession({ caller: { role: 'trainer', status: 'pending', centerId: 'c1' }, callerUid: 't1', session, member }));
    assert.ok(!canChangeSession({ caller: { role: 'admin', status: 'approved', centerId: 'c2' }, callerUid: 'a', session, member }));
  });
  it('같은 센터 관리자는 바꿀 수 있고, 회원 본인은 안 된다', () => {
    assert.ok(canChangeSession({ caller: { role: 'admin', status: 'approved', centerId: 'c1' }, callerUid: 'a', session, member }));
    assert.ok(!canChangeSession({ caller: { role: 'member', status: 'approved', centerId: 'c1' }, callerUid: 'm1', session, member }));
  });
});

describe('planStatusChange', () => {
  const pt = { totalSessions: 10, remainingSessions: 3 };
  it('완료로 바꾸면 1회 차감, 같은 상태면 아무 일도 없다', () => {
    assert.deepStrictEqual(planStatusChange({ session, ptInfo: pt, nextStatus: 'completed' }).remaining, { previous: 3, next: 2, total: 10 });
    assert.deepStrictEqual(planStatusChange({ session: { ...session, status: 'completed' }, ptInfo: pt, nextStatus: 'completed' }), { changed: false });
  });
  it('완료를 취소하면 1회 복구하되 전체를 넘지 않는다', () => {
    const p = planStatusChange({ session: { ...session, status: 'completed' }, ptInfo: { totalSessions: 10, remainingSessions: 10 }, nextStatus: 'scheduled' });
    assert.strictEqual(p.remaining.next, 10);
    assert.strictEqual(p.logType, 'sessionReopened');
  });
  it('예약 ↔ 취소는 잔여에 영향이 없다', () => {
    assert.deepStrictEqual(planStatusChange({ session, ptInfo: pt, nextStatus: 'cancelled' }), { changed: true, remaining: null, logType: null });
  });
  it('잔여 0회·PT권 없음·알 수 없는 상태는 거부한다', () => {
    assert.throws(() => planStatusChange({ session, ptInfo: { totalSessions: 10, remainingSessions: 0 }, nextStatus: 'completed' }), PtStatusRefused);
    assert.throws(() => planStatusChange({ session, ptInfo: undefined, nextStatus: 'completed' }), PtStatusRefused);
    assert.throws(() => planStatusChange({ session, ptInfo: pt, nextStatus: 'done' }), PtStatusRefused);
  });
});
