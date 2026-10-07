// 에뮬레이터 통합 테스트: setPtSessionStatus (PT 완료·완료 취소·예약 취소와 잔여 횟수)
// 실행: functions/ 에서 `npm run test:integration`

const { after, before, beforeEach, describe, it } = require('node:test');
const assert = require('assert');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-burnfit';
const REGION = 'us-central1';
const app = initializeApp({ projectId: PROJECT_ID }, 'pt-integration');
const db = getFirestore(app);
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';

async function call(name, data, idToken) {
  const res = await fetch(`http://${functionsHost}/${PROJECT_ID}/${REGION}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (body.error) {
    const err = new Error(body.error.message);
    err.status = body.error.status;
    throw err;
  }
  return body.result;
}

async function signUp(email) {
  const res = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'password123', returnSecureToken: true }),
  });
  const body = await res.json();
  return { uid: body.localId, idToken: body.idToken };
}

async function clearAll() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
}

let trainer;
let otherTrainer;
let member;

async function seed({ remaining = 3 } = {}) {
  trainer = await signUp('t1@example.com');
  otherTrainer = await signUp('t2@example.com');
  member = await signUp('m1@example.com');
  const user = (uid, role, extra = {}) => ({ uid, role, status: 'approved', centerId: 'c1', name: role, ...extra });
  await db.doc(`users/${trainer.uid}`).set(user(trainer.uid, 'trainer', { name: '김도윤' }));
  await db.doc(`users/${otherTrainer.uid}`).set(user(otherTrainer.uid, 'trainer'));
  await db.doc(`users/${member.uid}`).set(user(member.uid, 'member', { trainerId: trainer.uid }));
  await db.doc('pt_infos/p1').set({ id: 'p1', centerId: 'c1', memberId: member.uid, memberName: '회원', trainerId: trainer.uid, totalSessions: 10, remainingSessions: remaining });
  await db.doc('pt_sessions/s1').set({ id: 's1', centerId: 'c1', memberId: member.uid, memberName: '회원', trainerId: trainer.uid, trainerName: '김도윤', status: 'scheduled', durationMinutes: 50, scheduledAt: new Date() });
}

const remaining = async () => (await db.doc('pt_infos/p1').get()).data().remainingSessions;
const status = async () => (await db.doc('pt_sessions/s1').get()).data().status;

describe('setPtSessionStatus', () => {
  beforeEach(async () => {
    await clearAll();
    await seed();
  });

  it('담당 트레이너가 완료하면 1회 차감하고 기록을 남기며, 다시 불러도 한 번만 차감한다', async () => {
    await call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, trainer.idToken);
    await call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, trainer.idToken);
    assert.strictEqual(await status(), 'completed');
    assert.strictEqual(await remaining(), 2);
    const logs = await db.collection('pt_info_logs').get();
    assert.strictEqual(logs.size, 1);
    assert.strictEqual(logs.docs[0].data().changedById, trainer.uid);
    assert.strictEqual(logs.docs[0].data().type, 'sessionCompleted');
  });

  it('완료를 취소하면 1회 복구한다', async () => {
    await call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, trainer.idToken);
    await call('setPtSessionStatus', { sessionId: 's1', status: 'scheduled' }, trainer.idToken);
    assert.strictEqual(await status(), 'scheduled');
    assert.strictEqual(await remaining(), 3);
  });

  it('다른 트레이너·회원 본인은 바꿀 수 없다', async () => {
    await assert.rejects(call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, otherTrainer.idToken), (e) => e.status === 'PERMISSION_DENIED');
    await assert.rejects(call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, member.idToken), (e) => e.status === 'PERMISSION_DENIED');
    assert.strictEqual(await remaining(), 3);
  });

  it('잔여 0회면 완료할 수 없다', async () => {
    await db.doc('pt_infos/p1').update({ remainingSessions: 0 });
    await assert.rejects(call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }, trainer.idToken), (e) => e.status === 'FAILED_PRECONDITION');
    assert.strictEqual(await status(), 'scheduled');
  });

  it('로그인하지 않으면 거부한다', async () => {
    await assert.rejects(call('setPtSessionStatus', { sessionId: 's1', status: 'completed' }), (e) => e.status === 'UNAUTHENTICATED');
  });
});

before(async () => {
  for (let i = 0; i < 30; i += 1) {
    try {
      const res = await fetch(`http://${functionsHost}/${PROJECT_ID}/${REGION}/setPtSessionStatus`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"data":{}}' });
      if (res.status !== 404) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 1000));
  }
});

after(clearAll);
