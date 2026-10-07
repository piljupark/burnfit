const { describe, it } = require('node:test');
const assert = require('assert');
const { INBOX_RETENTION_DAYS, buildInboxDoc, inboxCutoff } = require('./notifications');

describe('buildInboxDoc', () => {
  it('알림 종류와 대상 문서 ID를 꺼내고 읽지 않음으로 만든다', () => {
    const doc = buildInboxDoc({
      title: '제목',
      body: '내용',
      data: { type: 'feedback_created', feedbackId: 'f1' },
      createdAt: 'NOW',
    });
    assert.deepStrictEqual(doc, {
      type: 'feedback_created', title: '제목', body: '내용', targetId: 'f1', createdAt: 'NOW', readAt: null,
    });
  });

  it('대상이 없거나 종류가 없어도 문서를 만든다', () => {
    const doc = buildInboxDoc({ title: undefined, body: 3, data: undefined, createdAt: 'NOW' });
    assert.strictEqual(doc.type, 'unknown');
    assert.strictEqual(doc.targetId, null);
    assert.strictEqual(doc.title, '');
    assert.strictEqual(doc.body, '3');
  });
});

describe('inboxCutoff', () => {
  it(`${INBOX_RETENTION_DAYS}일 전 시각을 돌려준다`, () => {
    const now = new Date(Date.UTC(2026, 9, 7));
    assert.strictEqual(inboxCutoff(now).toISOString(), '2026-07-09T00:00:00.000Z');
  });
});
