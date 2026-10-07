// 에뮬레이터 통합 테스트: registerCenterAdmin, deleteMyAccount
// 실행: functions/ 에서 `npm run test:integration` (demo- 프로젝트라 실제 Firebase에 접근하지 않는다)

const { after, before, beforeEach, describe, it } = require('node:test');
const assert = require('assert');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { purgeExpired } = require('../retention_store');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-burnfit';
const REGION = 'us-central1';
const SETUP_CODE = 'integration-test-setup-code';
const BUCKET = `${PROJECT_ID}.appspot.com`;

const app = initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET }, 'integration');
const db = getFirestore(app);
const auth = getAuth(app);

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';

async function call(name, data = {}, idToken) {
  const res = await fetch(`http://${functionsHost}/${PROJECT_ID}/${REGION}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (body.error) {
    const err = new Error(body.error.message);
    err.status = body.error.status;
    err.details = body.error.details;
    throw err;
  }
  return body.result;
}

async function signUp(email, password = 'password123') {
  const res = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = await res.json();
  return { uid: body.localId, idToken: body.idToken };
}

async function clearAll() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
}

const set = (path, data) => db.doc(path).set(data);
const exists = async (path) => (await db.doc(path).get()).exists;

describe('registerCenterAdmin', () => {
  beforeEach(clearAll);

  const input = {
    name: '관리자',
    email: 'admin@example.com',
    password: 'adminpass123',
    centerName: '강남 센터',
    centerAddress: null,
    setupCode: SETUP_CODE,
  };

  it('틀린 설정 코드는 거부하고 아무것도 만들지 않는다', async () => {
    await assert.rejects(call('registerCenterAdmin', { ...input, setupCode: 'wrong' }), (e) => {
      assert.strictEqual(e.status, 'PERMISSION_DENIED');
      assert.strictEqual(e.details.userMessage, '설정 코드가 올바르지 않습니다.');
      return true;
    });
    assert.strictEqual((await db.collection('centers').get()).size, 0);
    await assert.rejects(auth.getUserByEmail(input.email));
  });

  it('맞는 코드면 센터와 승인된 관리자를 만든다', async () => {
    const { uid, centerId } = await call('registerCenterAdmin', input);
    const user = (await db.doc(`users/${uid}`).get()).data();
    const center = (await db.doc(`centers/${centerId}`).get()).data();
    assert.strictEqual(user.role, 'admin');
    assert.strictEqual(user.status, 'approved');
    assert.strictEqual(user.centerId, centerId);
    assert.strictEqual(center.adminId, uid);
    assert.strictEqual(center.status, 'active');
  });

  it('이미 가입된 이메일은 거부한다', async () => {
    await call('registerCenterAdmin', input);
    await assert.rejects(call('registerCenterAdmin', input), (e) => e.status === 'ALREADY_EXISTS');
  });
});

describe('deleteMyAccount', () => {
  beforeEach(clearAll);

  it('로그인하지 않으면 거부한다', async () => {
    await assert.rejects(call('deleteMyAccount'), (e) => e.status === 'UNAUTHENTICATED');
  });

  it('관리자는 탈퇴할 수 없다', async () => {
    const { uid } = await call('registerCenterAdmin', {
      name: '관리자', email: 'a@example.com', password: 'adminpass123',
      centerName: '센터', setupCode: SETUP_CODE,
    });
    const token = (await signInToken('a@example.com', 'adminpass123'));
    await assert.rejects(call('deleteMyAccount', {}, token), (e) => e.status === 'FAILED_PRECONDITION');
    assert.ok(await exists(`users/${uid}`));
  });

  it('회원: 건강 기록·사진·계정은 지우고 PT 이력은 익명으로 보관한다', async () => {
    const { uid, idToken } = await signUp('member@example.com');
    const other = 'other-member';
    await set(`users/${uid}`, { uid, role: 'member', status: 'approved', centerId: 'c1', trainerId: 't1' });
    await set(`users/${other}`, { uid: other, role: 'member', status: 'approved', centerId: 'c1' });
    const deleted = ['workouts', 'meals', 'cardios', 'feedbacks', 'inbodies'];
    for (const c of deleted) {
      await set(`${c}/${c}-mine`, { memberId: uid, centerId: 'c1' });
      await set(`${c}/${c}-other`, { memberId: other, centerId: 'c1' });
    }
    const ptEnd = new Date(Date.UTC(2027, 0, 31));
    await set('pt_infos/info-mine', {
      id: 'info-mine', memberId: uid, memberName: '홍길동', centerId: 'c1', trainerId: 't1',
      totalSessions: 30, remainingSessions: 12, endDate: Timestamp.fromDate(ptEnd),
    });
    await set('pt_sessions/session-mine', {
      memberId: uid, memberName: '홍길동', centerId: 'c1', trainerId: 't1', status: 'completed',
      note: '010-1234-5678', durationMinutes: 50,
    });
    await set('pt_info_logs/log-mine', {
      memberId: uid, memberName: '홍길동', centerId: 'c1', ptInfoId: 'info-mine', type: 'session_completed',
      previousRemainingSessions: 13, nextRemainingSessions: 12, note: '메모',
    });
    await set('pt_sessions/session-other', { memberId: other, centerId: 'c1', status: 'scheduled' });
    await set('custom_exercises/mine', { memberId: uid });
    await set('join_requests/mine', { userId: uid, centerId: 'c1' });

    const bucket = getStorage(app).bucket(BUCKET);
    await bucket.file(`c1/meals/${uid}/a.jpg`).save(Buffer.from('x'));
    await bucket.file(`c1/meals/${other}/b.jpg`).save(Buffer.from('y'));

    assert.deepStrictEqual(await call('deleteMyAccount', {}, idToken), { deleted: true });

    for (const c of deleted) {
      assert.strictEqual(await exists(`${c}/${c}-mine`), false, `${c} 본인 기록`);
      assert.strictEqual(await exists(`${c}/${c}-other`), true, `${c} 다른 회원 기록`);
    }
    for (const path of ['pt_infos/info-mine', 'pt_sessions/session-mine', 'pt_info_logs/log-mine']) {
      assert.strictEqual(await exists(path), false, `${path} 원본은 지운다`);
    }
    assert.ok(await exists('pt_sessions/session-other'));

    const retained = (await db.collection('retained_pt_records').get()).docs.map((d) => d.data());
    assert.deepStrictEqual(retained.map((r) => r.kind).sort(), ['pt_info', 'pt_info_log', 'pt_session']);
    const aliases = new Set(retained.map((r) => r.memberAlias));
    assert.strictEqual(aliases.size, 1, '한 회원의 기록은 한 별칭으로 묶인다');
    assert.match([...aliases][0], /^withdrawn_/);
    const serialized = JSON.stringify(retained);
    for (const leaked of [uid, '홍길동', '010-1234-5678', '메모']) {
      assert.ok(!serialized.includes(leaked), `보관 기록에 "${leaked}"가 남았다`);
    }
    const info = retained.find((r) => r.kind === 'pt_info');
    assert.strictEqual(info.data.remainingSessions, 12);
    assert.strictEqual(info.centerId, 'c1');
    // PT 종료일(2027-01-31)이 탈퇴일보다 늦으므로 종료일 + 3년
    assert.strictEqual(info.expireAt.toDate().toISOString(), '2030-01-31T00:00:00.000Z');

    assert.strictEqual(await exists('custom_exercises/mine'), false);
    assert.strictEqual(await exists('join_requests/mine'), false);
    assert.strictEqual(await exists(`users/${uid}`), false);
    assert.strictEqual(await exists(`users/${other}`), true);
    assert.strictEqual((await bucket.file(`c1/meals/${uid}/a.jpg`).exists())[0], false);
    assert.strictEqual((await bucket.file(`c1/meals/${other}/b.jpg`).exists())[0], true);
    await assert.rejects(auth.getUser(uid));
  });

  it('재시도: 이전 시도에서 정한 별칭과 만료일을 그대로 쓴다', async () => {
    const { uid, idToken } = await signUp('retry@example.com');
    const prep = {
      memberAlias: 'withdrawn_previous-attempt',
      expireAt: Timestamp.fromDate(new Date(Date.UTC(2031, 2, 1))),
    };
    await set(`users/${uid}`, { uid, role: 'member', status: 'approved', centerId: 'c1', deletionPrep: prep });
    // 이전 시도에서 이미 옮겨진 기록 + 아직 남은 원본
    await set('retained_pt_records/pt_session_moved', {
      kind: 'pt_session', sourceId: 'moved', centerId: 'c1', memberAlias: prep.memberAlias, data: {}, expireAt: prep.expireAt,
    });
    await set('pt_sessions/left', { memberId: uid, centerId: 'c1', status: 'completed' });

    await call('deleteMyAccount', {}, idToken);

    const left = (await db.doc('retained_pt_records/pt_session_left').get()).data();
    assert.strictEqual(left.memberAlias, prep.memberAlias);
    assert.strictEqual(left.expireAt.toMillis(), prep.expireAt.toMillis());
  });

  it('트레이너: 담당 해제·예정 PT 취소, 회원 기록은 보존한다', async () => {
    const { uid, idToken } = await signUp('trainer@example.com');
    await set(`users/${uid}`, { uid, role: 'trainer', status: 'approved', centerId: 'c1' });
    await set('users/m1', { uid: 'm1', role: 'member', centerId: 'c1', trainerId: uid, trainerName: '트레이너' });
    await set('pt_sessions/upcoming', { memberId: 'm1', trainerId: uid, status: 'scheduled' });
    await set('pt_sessions/done', { memberId: 'm1', trainerId: uid, status: 'completed' });
    await set('pt_infos/p1', { memberId: 'm1', trainerId: uid, remainingSessions: 3 });
    await set('workouts/w1', { memberId: 'm1', trainerId: uid });
    await set('feedbacks/f1', { memberId: 'm1', trainerId: uid });

    await call('deleteMyAccount', {}, idToken);

    const member = (await db.doc('users/m1').get()).data();
    assert.strictEqual(member.trainerId, null);
    assert.strictEqual(member.trainerName, null);
    assert.strictEqual((await db.doc('pt_sessions/upcoming').get()).data().status, 'cancelled');
    assert.strictEqual((await db.doc('pt_sessions/done').get()).data().status, 'completed');
    assert.strictEqual((await db.doc('pt_infos/p1').get()).data().trainerId, null);
    assert.ok(await exists('workouts/w1'));
    assert.ok(await exists('feedbacks/f1'));
    assert.strictEqual(await exists(`users/${uid}`), false);
    await assert.rejects(auth.getUser(uid));
  });
});

async function waitFor(check, { timeoutMs = 10000, intervalMs = 250 } = {}) {
  const started = Date.now();
  for (;;) {
    const value = await check();
    if (value) return value;
    if (Date.now() - started > timeoutMs) return value;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
}

const inboxOf = (uid) => db.collection(`users/${uid}/notifications`).get();

describe('알림함 (notifyUser)', () => {
  beforeEach(clearAll);

  it('PT 일정 등록 알림이 회원 알림함에 읽지 않음으로 쌓인다', async () => {
    // 트리거는 비동기라 다른 테스트의 늦은 알림과 섞이지 않게 이 테스트만의 회원을 쓴다.
    const memberId = 'inbox-member';
    await set(`users/${memberId}`, { uid: memberId, role: 'member', status: 'approved', centerId: 'c1' });
    await set('pt_sessions/inbox-session', {
      memberId, trainerId: 't1', trainerName: '김트', centerId: 'c1',
      status: 'scheduled', durationMinutes: 50, scheduledAt: Timestamp.fromDate(new Date(Date.UTC(2026, 9, 9, 5))),
    });

    const item = await waitFor(async () => {
      const s = await inboxOf(memberId);
      return s.docs.map((d) => d.data()).find((n) => n.targetId === 'inbox-session') ?? null;
    });
    assert.ok(item, '알림함에 기록이 생기지 않았다');
    assert.strictEqual(item.type, 'pt_session_created');
    assert.strictEqual(item.readAt, null);
    assert.match(item.body, /김트 트레이너/);
  });

  it('없는 사용자(탈퇴 등)에게는 알림함을 만들지 않는다', async () => {
    await set('pt_sessions/s2', { memberId: 'gone', trainerId: 't1', centerId: 'c1', status: 'scheduled' });
    // 트리거가 끝날 시간을 준 뒤 확인한다.
    await new Promise((r) => setTimeout(r, 3000));
    assert.strictEqual((await inboxOf('gone')).size, 0);
  });

  it('탈퇴하면 알림함도 지운다', async () => {
    const { uid, idToken } = await signUp('inbox@example.com');
    await set(`users/${uid}`, { uid, role: 'member', status: 'approved', centerId: 'c1' });
    await set(`users/${uid}/notifications/n1`, { type: 'feedback_created', title: 't', body: 'b', readAt: null });

    await call('deleteMyAccount', {}, idToken);

    assert.strictEqual((await inboxOf(uid)).size, 0);
  });
});

describe('purgeExpired (매일 파기 작업)', () => {
  beforeEach(clearAll);

  it('만료일이 지난 보관 기록만 지운다', async () => {
    const now = new Date(Date.UTC(2030, 0, 1));
    await set('retained_pt_records/expired', { centerId: 'c1', expireAt: Timestamp.fromDate(new Date(Date.UTC(2029, 11, 31))) });
    await set('retained_pt_records/today', { centerId: 'c1', expireAt: Timestamp.fromDate(now) });
    await set('retained_pt_records/future', { centerId: 'c1', expireAt: Timestamp.fromDate(new Date(Date.UTC(2030, 0, 2))) });

    assert.strictEqual(await purgeExpired(db, now), 2);
    assert.strictEqual(await exists('retained_pt_records/expired'), false);
    assert.strictEqual(await exists('retained_pt_records/today'), false);
    assert.strictEqual(await exists('retained_pt_records/future'), true);
  });
});

async function signInToken(email, password) {
  const res = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  return (await res.json()).idToken;
}

before(async () => {
  // 에뮬레이터의 함수 로딩을 기다린다.
  for (let i = 0; i < 30; i += 1) {
    try {
      await call('deleteMyAccount');
    } catch (e) {
      if (e.status) return;
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
});

after(async () => {
  await clearAll();
});
