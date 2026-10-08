// 사용자 문서의 예전 신체 정보(profile)를 users/{uid}/body_profile/current로 옮긴다.
//
// 신체 정보를 사용자 문서에 두면 회원이 '신체 정보 공유'를 꺼도 담당 트레이너가 읽을 수 있어
// 별도 문서로 나눴다 (firestore.rules). 앱도 회원이 접속할 때 하나씩 옮기지만,
// 접속하지 않는 회원까지 바로 막으려면 이 스크립트를 한 번 실행한다. 여러 번 실행해도 안전하다.
//
// 실행 (기본은 미리보기 — 아무것도 쓰지 않는다):
//   cd functions && gcloud auth application-default login
//   GCLOUD_PROJECT=burnfit-v01 node scripts/migrate_body_profiles.js
//   GCLOUD_PROJECT=burnfit-v01 node scripts/migrate_body_profiles.js --apply

const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const apply = process.argv.includes('--apply');
const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) {
  console.error('GCLOUD_PROJECT(대상 프로젝트 ID)를 지정해주세요.');
  process.exit(1);
}

initializeApp({ projectId });
const db = getFirestore();

const BODY_KEYS = ['height', 'weight', 'muscleMass', 'bodyFat', 'goal'];

async function main() {
  const snap = await db.collection('users').where('profile', '!=', null).get();
  console.log(`[${projectId}] 예전 신체 정보가 남은 사용자: ${snap.size}명 ${apply ? '' : '(미리보기)'}`);

  let moved = 0;
  let cleared = 0;
  for (const userDoc of snap.docs) {
    const legacy = userDoc.get('profile');
    const bodyRef = userDoc.ref.collection('body_profile').doc('current');
    const existing = await bodyRef.get();

    if (apply) {
      const batch = db.batch();
      // 새 위치에 이미 값이 있으면 그쪽이 최신이므로 덮어쓰지 않고 예전 필드만 지운다.
      if (!existing.exists) {
        const body = Object.fromEntries(BODY_KEYS.map((k) => [k, legacy?.[k] ?? null]));
        batch.set(bodyRef, { ...body, updatedAt: FieldValue.serverTimestamp() });
      }
      batch.update(userDoc.ref, { profile: FieldValue.delete() });
      await batch.commit();
    }
    if (existing.exists) cleared += 1;
    else moved += 1;
  }

  console.log(`옮김 ${moved}명 · 예전 필드만 지움 ${cleared}명${apply ? '' : ' (--apply로 실제 반영)'}`);
}

main().catch((e) => {
  console.error('실패:', e);
  process.exit(1);
});
