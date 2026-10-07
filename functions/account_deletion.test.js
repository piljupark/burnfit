const { describe, it } = require('node:test');
const assert = require('assert');
const {
  RECENT_LOGIN_MAX_AGE_SEC,
  MEMBER_OWNED_COLLECTIONS,
  DeletionRefused,
  isRecentLogin,
  buildDeletionPlan,
} = require('./account_deletion');

describe('isRecentLogin', () => {
  const nowMs = 1_800_000_000_000;
  const nowSec = nowMs / 1000;

  it('5분 이내 로그인만 허용한다', () => {
    assert.strictEqual(isRecentLogin(nowSec - 10, nowMs), true);
    assert.strictEqual(isRecentLogin(nowSec - RECENT_LOGIN_MAX_AGE_SEC, nowMs), true);
    assert.strictEqual(isRecentLogin(nowSec - RECENT_LOGIN_MAX_AGE_SEC - 1, nowMs), false);
  });

  it('값이 없거나 미래 시각이면 거부한다', () => {
    assert.strictEqual(isRecentLogin(undefined, nowMs), false);
    assert.strictEqual(isRecentLogin(nowSec + 60, nowMs), false);
  });
});

describe('buildDeletionPlan', () => {
  it('관리자는 거부한다', () => {
    assert.throws(
      () => buildDeletionPlan({ role: 'admin', centerId: 'c1' }, 'u1'),
      (e) => e instanceof DeletionRefused && e.code === 'failed-precondition',
    );
  });

  it('회원은 본인 기록 전부와 식단 사진을 지운다', () => {
    const plan = buildDeletionPlan({ role: 'member', centerId: 'c1' }, 'u1');
    const deleted = plan.deletes.map((d) => d.collection);
    for (const c of MEMBER_OWNED_COLLECTIONS) assert.ok(deleted.includes(c), c);
    assert.ok(deleted.includes('custom_exercises'));
    assert.ok(deleted.includes('join_requests'));
    assert.deepStrictEqual(plan.storagePrefixes, ['c1/meals/u1/']);
    assert.deepStrictEqual(plan.updates, []);
  });

  it('트레이너는 회원 기록을 지우지 않고 담당 관계만 끊는다', () => {
    const plan = buildDeletionPlan({ role: 'trainer', centerId: 'c1' }, 't1');
    const deleted = plan.deletes.map((d) => d.collection);
    for (const c of MEMBER_OWNED_COLLECTIONS) assert.ok(!deleted.includes(c), c);

    const users = plan.updates.find((u) => u.collection === 'users');
    assert.deepStrictEqual(users.where, [['trainerId', '==', 't1']]);
    assert.deepStrictEqual(users.data, { trainerId: null, trainerName: null });

    const sessions = plan.updates.find((u) => u.collection === 'pt_sessions');
    assert.deepStrictEqual(sessions.data, { status: 'cancelled' });
    assert.ok(sessions.where.some(([f, , v]) => f === 'status' && v === 'scheduled'));
    assert.deepStrictEqual(plan.storagePrefixes, []);
  });

  it('사용자 문서가 없으면 가입 신청 등만 정리한다', () => {
    const plan = buildDeletionPlan(undefined, 'u1');
    assert.deepStrictEqual(plan.deletes.map((d) => d.collection).sort(), ['custom_exercises', 'join_requests']);
  });

  it('센터 정보가 없는 회원은 Storage 경로를 만들지 않는다', () => {
    const plan = buildDeletionPlan({ role: 'member' }, 'u1');
    assert.deepStrictEqual(plan.storagePrefixes, []);
  });
});
