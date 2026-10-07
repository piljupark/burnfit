// 센터 관리자 가입(registerCenterAdmin)의 순수 로직.
// Firebase에 의존하지 않아 단위 테스트할 수 있다.

const crypto = require('crypto');

const LIMITS = {
  nameMax: 30,
  emailMax: 254,
  passwordMin: 8,
  passwordMax: 128,
  centerNameMax: 50,
  centerAddressMax: 100,
  setupCodeMax: 200,
};

// 같은 IP에서 설정 코드를 연속으로 틀릴 수 있는 횟수와 그 기간.
const THROTTLE = {
  maxFailures: 5,
  windowMs: 60 * 60 * 1000,
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

class InputError extends Error {}

function requireText(value, label, max, { optional = false } = {}) {
  if (value == null || (typeof value === 'string' && value.trim() === '')) {
    if (optional) return null;
    throw new InputError(`${label}을(를) 입력해주세요.`);
  }
  if (typeof value !== 'string') throw new InputError(`${label} 형식이 올바르지 않습니다.`);
  const trimmed = value.trim();
  if (trimmed.length > max) throw new InputError(`${label}은(는) ${max}자 이하로 입력해주세요.`);
  return trimmed;
}

// 클라이언트 입력을 정규화하고 검증한다. 실패하면 InputError를 던진다.
function parseAdminSetupInput(data) {
  const input = data ?? {};
  const name = requireText(input.name, '이름', LIMITS.nameMax);
  const email = requireText(input.email, '이메일', LIMITS.emailMax).toLowerCase();
  if (!EMAIL_PATTERN.test(email)) throw new InputError('이메일 형식이 올바르지 않습니다.');

  const password = input.password;
  if (typeof password !== 'string' || password.length < LIMITS.passwordMin) {
    throw new InputError(`비밀번호는 ${LIMITS.passwordMin}자 이상이어야 합니다.`);
  }
  if (password.length > LIMITS.passwordMax) {
    throw new InputError(`비밀번호는 ${LIMITS.passwordMax}자 이하로 입력해주세요.`);
  }

  const centerName = requireText(input.centerName, '센터 이름', LIMITS.centerNameMax);
  const centerAddress = requireText(input.centerAddress, '주소', LIMITS.centerAddressMax, {
    optional: true,
  });
  const setupCode = requireText(input.setupCode, '설정 코드', LIMITS.setupCodeMax);

  return { name, email, password, centerName, centerAddress, setupCode };
}

// 길이·내용과 무관하게 같은 시간에 비교한다 (타이밍 공격 방지).
function setupCodeMatches(provided, expected) {
  if (typeof provided !== 'string' || typeof expected !== 'string' || expected.length === 0) {
    return false;
  }
  const hash = (v) => crypto.createHash('sha256').update(v, 'utf8').digest();
  return crypto.timingSafeEqual(hash(provided), hash(expected));
}

// 원본 IP를 저장하지 않도록 해시한 값을 문서 ID로 쓴다.
function throttleKey(ip) {
  return crypto.createHash('sha256').update(`admin-setup:${ip ?? 'unknown'}`).digest('hex');
}

// 현재 시도 기록으로 차단 여부를 판단한다.
function isThrottled(record, nowMs) {
  if (!record) return false;
  if (nowMs - record.windowStartMs > THROTTLE.windowMs) return false;
  return record.failures >= THROTTLE.maxFailures;
}

// 실패 1회를 반영한 다음 기록을 만든다.
function nextFailureRecord(record, nowMs) {
  if (!record || nowMs - record.windowStartMs > THROTTLE.windowMs) {
    return { failures: 1, windowStartMs: nowMs };
  }
  return { failures: record.failures + 1, windowStartMs: record.windowStartMs };
}

function buildCenterDoc({ centerId, adminId, centerName, centerAddress, now }) {
  return {
    id: centerId,
    name: centerName,
    address: centerAddress,
    adminId,
    status: 'active',
    createdAt: now,
  };
}

// lib/models/user.dart의 AppUser.toMap()과 같은 모양을 유지한다.
function buildAdminUserDoc({ uid, email, name, centerId, centerName, now }) {
  return {
    uid,
    email,
    name,
    role: 'admin',
    status: 'approved',
    centerId,
    centerName,
    trainerId: null,
    trainerName: null,
    birthDate: null,
    gender: null,
    profile: null,
    shareSettings: { workout: true, meal: true, body: true },
    createdAt: now,
    updatedAt: now,
  };
}

module.exports = {
  LIMITS,
  THROTTLE,
  InputError,
  parseAdminSetupInput,
  setupCodeMatches,
  throttleKey,
  isThrottled,
  nextFailureRecord,
  buildCenterDoc,
  buildAdminUserDoc,
};
