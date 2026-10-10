const fs = require('fs');
const path = require('path');
const { after, before, beforeEach, describe, it } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');
const { ref, uploadBytes, getMetadata } = require('firebase/storage');

let testEnv;

const centerId = 'center-a';
const memberId = 'member-a';
const pendingMemberId = 'member-pending';
const trainerId = 'trainer-a';
const pendingTrainerId = 'trainer-pending';
const adminId = 'admin-a';
const photoPath = `${centerId}/meals/${memberId}/photo.jpg`;
const image = new Uint8Array([0xff, 0xd8, 0xff]);
const jpeg = { contentType: 'image/jpeg' };

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', memberId), {
      uid: memberId, role: 'member', status: 'approved', centerId, trainerId,
    });
    await setDoc(doc(db, 'users', pendingMemberId), {
      uid: pendingMemberId, role: 'member', status: 'pending', centerId,
    });
    await setDoc(doc(db, 'users', trainerId), {
      uid: trainerId, role: 'trainer', status: 'approved', centerId,
    });
    await setDoc(doc(db, 'users', adminId), {
      uid: adminId, role: 'admin', status: 'approved', centerId,
    });
    await uploadBytes(ref(context.storage(), photoPath), image, jpeg);
  });
}

async function setUser(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), { uid, centerId, ...data });
  });
}

const storageOf = (uid) => testEnv.authenticatedContext(uid).storage();

describe('storage rules — 식단 사진', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      // Storage 규칙의 firestore.get()은 에뮬레이터 프로젝트의 Firestore를 읽으므로 같은 ID를 써야 한다.
      projectId: process.env.GCLOUD_PROJECT || 'demo-burnfit',
      firestore: { rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') },
      storage: { rules: fs.readFileSync(path.resolve(__dirname, '../../storage.rules'), 'utf8') },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await seed();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('승인된 회원은 자기 경로에 사진을 올릴 수 있다', async () => {
    await assertSucceeds(uploadBytes(
      ref(storageOf(memberId), `${centerId}/meals/${memberId}/new.jpg`), image, jpeg,
    ));
  });

  it('승인 대기 회원은 사진을 올릴 수 없다', async () => {
    await assertFails(uploadBytes(
      ref(storageOf(pendingMemberId), `${centerId}/meals/${pendingMemberId}/new.jpg`), image, jpeg,
    ));
  });

  it('승인된 담당 트레이너는 회원 사진을 볼 수 있다', async () => {
    await assertSucceeds(getMetadata(ref(storageOf(trainerId), photoPath)));
  });

  it('승인되지 않은 트레이너는 담당으로 지정돼 있어도 볼 수 없다', async () => {
    await setUser(pendingTrainerId, { role: 'trainer', status: 'pending' });
    await setUser(memberId, { role: 'member', status: 'approved', trainerId: pendingTrainerId });
    await assertFails(getMetadata(ref(storageOf(pendingTrainerId), photoPath)));
  });

  it('승인된 센터 관리자는 볼 수 있고, 거절된 관리자는 볼 수 없다', async () => {
    await assertSucceeds(getMetadata(ref(storageOf(adminId), photoPath)));
    await setUser(adminId, { role: 'admin', status: 'rejected' });
    await assertFails(getMetadata(ref(storageOf(adminId), photoPath)));
  });

  it('예전에 식단 공유를 꺼 둔 회원이어도 담당 트레이너는 사진을 본다 (늘 공유)', async () => {
    await setUser(memberId, {
      role: 'member', status: 'approved', trainerId,
      shareSettings: { workout: true, meal: false, body: true },
    });
    await assertSucceeds(getMetadata(ref(storageOf(trainerId), photoPath)));
  });
});
