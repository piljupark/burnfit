const { describe, it } = require('node:test');
const assert = require('assert');
const { noticeRecipientRoles, isNoticeRecipient, buildNoticeMessage } = require('./notices');

const notice = { centerId: 'c1', audience: 'member', authorId: 'admin', title: '휴관', body: '내용', important: false };

describe('noticeRecipientRoles', () => {
  it('대상별 역할을 돌려주고 알 수 없는 값은 빈 배열', () => {
    assert.deepStrictEqual(noticeRecipientRoles('all'), ['member', 'trainer']);
    assert.deepStrictEqual(noticeRecipientRoles('member'), ['member']);
    assert.deepStrictEqual(noticeRecipientRoles('trainer'), ['trainer']);
    assert.deepStrictEqual(noticeRecipientRoles('admin'), []);
    assert.deepStrictEqual(noticeRecipientRoles(undefined), []);
  });
});

describe('isNoticeRecipient', () => {
  const member = { uid: 'm1', centerId: 'c1', status: 'approved', role: 'member' };
  it('같은 센터 승인 회원만 받는다', () => {
    assert.strictEqual(isNoticeRecipient(member, notice), true);
    assert.strictEqual(isNoticeRecipient({ ...member, centerId: 'c2' }, notice), false);
    assert.strictEqual(isNoticeRecipient({ ...member, status: 'pending' }, notice), false);
    assert.strictEqual(isNoticeRecipient({ ...member, role: 'trainer' }, notice), false);
    assert.strictEqual(isNoticeRecipient({ ...member, role: 'admin' }, { ...notice, audience: 'all' }), false);
    assert.strictEqual(isNoticeRecipient({ ...member, uid: 'admin' }, notice), false);
  });
});

describe('buildNoticeMessage', () => {
  it('중요 공지는 제목에 표시하고 본문은 60자로 자른다', () => {
    assert.deepStrictEqual(buildNoticeMessage(notice), { title: '새 공지: 휴관', body: '내용' });
    const long = buildNoticeMessage({ ...notice, important: true, body: 'a'.repeat(70) });
    assert.strictEqual(long.title, '[중요] 휴관');
    assert.strictEqual(long.body, `${'a'.repeat(60)}...`);
  });
});
