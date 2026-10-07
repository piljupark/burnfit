const { describe, it } = require('node:test');
const assert = require('assert');
const {
  RECENT_LOGIN_MAX_AGE_SEC,
  MEMBER_DELETED_COLLECTIONS,
  MEMBER_RETAINED_SOURCES,
  DeletionRefused,
  isRecentLogin,
  buildDeletionPlan,
  retentionExpiry,
  buildRetainedRecord,
} = require('./account_deletion');

const RETAINED = MEMBER_RETAINED_SOURCES.map((s) => s.collection);

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

  it('회원은 건강·생활 기록과 식단 사진을 지우고 PT 이력은 보관 대상으로 둔다', () => {
    const plan = buildDeletionPlan({ role: 'member', centerId: 'c1' }, 'u1');
    const deleted = plan.deletes.map((d) => d.collection);
    for (const c of MEMBER_DELETED_COLLECTIONS) assert.ok(deleted.includes(c), c);
    for (const c of RETAINED) assert.ok(!deleted.includes(c), `${c}는 바로 지우지 않는다`);
    assert.deepStrictEqual(plan.retains.map((r) => r.collection), RETAINED);
    assert.ok(deleted.includes('custom_exercises'));
    assert.ok(deleted.includes('join_requests'));
    assert.deepStrictEqual(plan.storagePrefixes, ['c1/meals/u1/']);
    assert.deepStrictEqual(plan.updates, []);
  });

  it('트레이너는 회원 기록을 지우지 않고 담당 관계만 끊는다', () => {
    const plan = buildDeletionPlan({ role: 'trainer', centerId: 'c1' }, 't1');
    const deleted = plan.deletes.map((d) => d.collection);
    for (const c of [...MEMBER_DELETED_COLLECTIONS, ...RETAINED]) assert.ok(!deleted.includes(c), c);
    assert.deepStrictEqual(plan.retains, []);

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

describe('retentionExpiry', () => {
  const now = Date.UTC(2026, 9, 7);

  it('PT가 이미 끝났으면 탈퇴일로부터 3년', () => {
    const ended = { endDate: new Date(Date.UTC(2026, 0, 1)) };
    assert.strictEqual(retentionExpiry([ended], now).getTime(), Date.UTC(2029, 9, 7));
  });

  it('PT가 남아 있으면 가장 늦은 종료일로부터 3년', () => {
    const infos = [
      { endDate: new Date(Date.UTC(2026, 11, 31)) },
      { endDate: { toMillis: () => Date.UTC(2027, 5, 30) } },
    ];
    assert.strictEqual(retentionExpiry(infos, now).getTime(), Date.UTC(2030, 5, 30));
  });

  it('종료일이 없거나 PT 정보가 없으면 탈퇴일로부터 3년', () => {
    assert.strictEqual(retentionExpiry([{ endDate: null }], now).getTime(), Date.UTC(2029, 9, 7));
    assert.strictEqual(retentionExpiry([], now).getTime(), Date.UTC(2029, 9, 7));
  });
});

describe('buildRetainedRecord', () => {
  const source = (kind) => MEMBER_RETAINED_SOURCES.find((s) => s.kind === kind);

  it('회원 식별 정보와 자유 메모는 남기지 않는다', () => {
    const { id, doc } = buildRetainedRecord({
      source: source('pt_session'),
      sourceId: 's1',
      data: {
        id: 's1', centerId: 'c1', memberId: 'u1', memberName: '홍길동', note: '010-1234-5678 연락',
        trainerId: 't1', trainerName: '김트', scheduledAt: 'T', durationMinutes: 50, status: 'completed',
      },
      memberAlias: 'withdrawn_x',
      retainedAt: 'NOW',
      expireAt: 'EXP',
    });
    assert.strictEqual(id, 'pt_session_s1');
    assert.strictEqual(doc.memberAlias, 'withdrawn_x');
    assert.strictEqual(doc.centerId, 'c1');
    const serialized = JSON.stringify(doc);
    for (const leaked of ['u1', '홍길동', '010-1234-5678']) {
      assert.ok(!serialized.includes(leaked), `${leaked}가 남았다`);
    }
    assert.deepStrictEqual(doc.data, {
      centerId: 'c1', trainerId: 't1', trainerName: '김트', scheduledAt: 'T', durationMinutes: 50, status: 'completed',
    });
  });

  it('모든 보관 대상은 memberId·memberName·note를 남기지 않는다', () => {
    for (const s of MEMBER_RETAINED_SOURCES) {
      for (const field of ['memberId', 'memberName', 'note']) {
        assert.ok(!s.keep.includes(field), `${s.collection}.${field}`);
      }
    }
  });
});
