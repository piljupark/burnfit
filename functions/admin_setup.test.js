const { describe, it } = require('node:test');
const assert = require('assert');
const {
  THROTTLE,
  InputError,
  parseAdminSetupInput,
  setupCodeMatches,
  throttleKey,
  isThrottled,
  nextFailureRecord,
  buildAdminUserDoc,
} = require('./admin_setup');

const valid = {
  name: ' 홍길동 ',
  email: ' Admin@Example.COM ',
  password: 'longpassword',
  centerName: ' 강남 센터 ',
  centerAddress: '  ',
  setupCode: ' secret-code ',
};

describe('parseAdminSetupInput', () => {
  it('공백을 다듬고 이메일을 소문자로 정규화한다', () => {
    const parsed = parseAdminSetupInput(valid);
    assert.deepStrictEqual(parsed, {
      name: '홍길동',
      email: 'admin@example.com',
      password: 'longpassword',
      centerName: '강남 센터',
      centerAddress: null,
      setupCode: 'secret-code',
    });
  });

  it('비밀번호는 다듬지 않는다', () => {
    assert.strictEqual(parseAdminSetupInput({ ...valid, password: ' pass word ' }).password, ' pass word ');
  });

  for (const [field, value] of [
    ['name', ''],
    ['name', 'a'.repeat(31)],
    ['email', 'not-an-email'],
    ['password', 'short'],
    ['password', 'a'.repeat(129)],
    ['centerName', '   '],
    ['setupCode', undefined],
    ['email', 123],
  ]) {
    it(`${field}=${JSON.stringify(value)?.slice(0, 20)} 은 거부한다`, () => {
      assert.throws(() => parseAdminSetupInput({ ...valid, [field]: value }), InputError);
    });
  }

  it('데이터가 없으면 거부한다', () => {
    assert.throws(() => parseAdminSetupInput(undefined), InputError);
  });
});

describe('setupCodeMatches', () => {
  it('같은 코드만 통과한다', () => {
    assert.strictEqual(setupCodeMatches('abc', 'abc'), true);
    assert.strictEqual(setupCodeMatches('abd', 'abc'), false);
    assert.strictEqual(setupCodeMatches('abcd', 'abc'), false);
  });

  it('서버 코드가 비어 있으면 항상 거부한다 (설정 누락 방어)', () => {
    assert.strictEqual(setupCodeMatches('', ''), false);
    assert.strictEqual(setupCodeMatches('x', undefined), false);
  });
});

describe('throttle', () => {
  const now = 1_000_000_000;

  it('IP를 그대로 저장하지 않는다', () => {
    const key = throttleKey('1.2.3.4');
    assert.match(key, /^[0-9a-f]{64}$/);
    assert.notStrictEqual(key, throttleKey('1.2.3.5'));
  });

  it('기간 안에서 최대 실패 횟수에 도달하면 차단한다', () => {
    let record = null;
    for (let i = 0; i < THROTTLE.maxFailures; i += 1) {
      assert.strictEqual(isThrottled(record, now), false);
      record = nextFailureRecord(record, now);
    }
    assert.strictEqual(isThrottled(record, now), true);
  });

  it('기간이 지나면 다시 허용하고 횟수를 새로 센다', () => {
    const later = now + THROTTLE.windowMs + 1;
    const record = { failures: THROTTLE.maxFailures, windowStartMs: now };
    assert.strictEqual(isThrottled(record, later), false);
    assert.deepStrictEqual(nextFailureRecord(record, later), { failures: 1, windowStartMs: later });
  });
});

describe('buildAdminUserDoc', () => {
  it('승인된 관리자 문서를 만든다', () => {
    const doc = buildAdminUserDoc({
      uid: 'u1', email: 'a@b.co', name: '홍', centerId: 'c1', centerName: '센터', now: 'NOW',
    });
    assert.strictEqual(doc.role, 'admin');
    assert.strictEqual(doc.status, 'approved');
    assert.strictEqual(doc.trainerId, null);
    assert.deepStrictEqual(doc.shareSettings, { workout: true, meal: true, body: true });
  });
});
