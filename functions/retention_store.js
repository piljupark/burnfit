// 탈퇴 회원 PT 이력 보관소(retained_pt_records) 읽기·쓰기.
// db를 인자로 받아 Cloud Functions와 통합 테스트가 같은 코드를 쓴다.

const crypto = require('crypto');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const {
  RETAINED_COLLECTION,
  retentionExpiry,
  buildRetainedRecord,
} = require('./account_deletion');

// 원본 이동은 (보관 문서 쓰기 + 원본 삭제) 2건씩 한 배치로 묶는다. 배치 한도 500건.
const MOVE_PAGE_SIZE = 200;
const PURGE_PAGE_SIZE = 300;
const MAX_PAGES = 200;

/**
 * 탈퇴 준비값(별칭, 만료일)을 처음 한 번만 정해 사용자 문서에 적어 둔다.
 * 재시도할 때 같은 값을 써야 한 회원의 보관 기록이 한 별칭으로 묶이고 만료일도 흔들리지 않는다.
 */
async function prepareRetention(db, userRef, uid, nowMs = Date.now()) {
  const snap = await userRef.get();
  const existing = snap.data()?.deletionPrep;
  if (existing?.memberAlias && existing?.expireAt) return existing;

  const ptInfos = await db.collection('pt_infos').where('memberId', '==', uid).get();
  const prep = {
    memberAlias: `withdrawn_${crypto.randomUUID()}`,
    expireAt: Timestamp.fromDate(retentionExpiry(ptInfos.docs.map((d) => d.data()), nowMs)),
  };
  if (snap.exists) await userRef.update({ deletionPrep: prep });
  return prep;
}

/** 원본을 회원을 알 수 없는 보관 문서로 옮긴다. 문서마다 쓰기와 삭제가 같은 배치라 어중간한 상태가 없다. */
async function moveToRetention(db, source, uid, prep) {
  let moved = 0;
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const snap = await db.collection(source.collection)
      .where('memberId', '==', uid)
      .limit(MOVE_PAGE_SIZE)
      .get();
    if (snap.empty) return moved;

    const batch = db.batch();
    for (const doc of snap.docs) {
      const { id, doc: record } = buildRetainedRecord({
        source,
        sourceId: doc.id,
        data: doc.data(),
        memberAlias: prep.memberAlias,
        retainedAt: FieldValue.serverTimestamp(),
        expireAt: prep.expireAt,
      });
      batch.set(db.collection(RETAINED_COLLECTION).doc(id), record);
      batch.delete(doc.ref);
    }
    await batch.commit();
    moved += snap.size;
  }
  throw new Error(`moveToRetention(${source.collection}): ${MAX_PAGES} 페이지를 넘었습니다`);
}

/** 만료된 보관 기록을 지운다. 지운 건수를 돌려준다. */
async function purgeExpired(db, now = new Date()) {
  let purged = 0;
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const snap = await db.collection(RETAINED_COLLECTION)
      .where('expireAt', '<=', Timestamp.fromDate(now))
      .limit(PURGE_PAGE_SIZE)
      .select()
      .get();
    if (snap.empty) return purged;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    purged += snap.size;
  }
  return purged;
}

module.exports = { prepareRetention, moveToRetention, purgeExpired };
