const { describe, it } = require('node:test');
const assert = require('assert');
const { mealCreatedMessage } = require('./meals');

describe('mealCreatedMessage', () => {
  it('회원 이름과 끼니, 메모 앞부분', () => {
    const m = mealCreatedMessage({ memberName: '김민지', mealType: 'lunch', description: '닭가슴살 덮밥' });
    assert.deepStrictEqual(m, { title: '김민지님이 점심 식단을 올렸어요', body: '닭가슴살 덮밥' });
  });

  it('메모가 없으면 피드백 안내, 끼니를 모르면 끼니 없이', () => {
    const m = mealCreatedMessage({ memberName: '이서준', mealType: 'brunch' });
    assert.deepStrictEqual(m, { title: '이서준님이 식단을 올렸어요', body: '식단 탭에서 피드백을 남겨 주세요.' });
  });

  it('긴 메모는 40자에서 자르고, 이름이 없으면 회원', () => {
    const m = mealCreatedMessage({ mealType: 'snack', description: '가'.repeat(50) });
    assert.strictEqual(m.title, '회원님이 간식 식단을 올렸어요');
    assert.strictEqual(m.body, `${'가'.repeat(40)}...`);
  });
});
