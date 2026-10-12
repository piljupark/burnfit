const { describe, it } = require('node:test');
const assert = require('assert');
const { planContentChanged, nutritionPlanMessage } = require('./nutrition_plans');

describe('planContentChanged', () => {
  const plan = { calories: 2100, protein: 140, mealGuides: { lunch: '밥 2/3' }, note: null };

  it('새로 만들면 알린다, 지우면 알리지 않는다', () => {
    assert.strictEqual(planContentChanged(null, plan), true);
    assert.strictEqual(planContentChanged(plan, null), false);
  });

  it('저장 시각만 바뀌면 알리지 않고, 숫자 · 가이드 · 한마디가 바뀌면 알린다', () => {
    assert.strictEqual(planContentChanged(plan, { ...plan, updatedAt: 1 }), false);
    assert.strictEqual(planContentChanged(plan, { ...plan, calories: 1900 }), true);
    assert.strictEqual(planContentChanged(plan, { ...plan, mealGuides: { lunch: '밥 반 공기' } }), true);
    assert.strictEqual(planContentChanged(plan, { ...plan, note: '물 2L' }), true);
  });
});

describe('nutritionPlanMessage', () => {
  it('트레이너 이름과 칼로리 · 단백질', () => {
    const m = nutritionPlanMessage({ trainerName: '박코치', calories: 2100, protein: 140 }, { created: true });
    assert.deepStrictEqual(m, { title: '박코치 트레이너가 식단 목표를 정했어요', body: '하루 2,100kcal · 단백질 140g' });
  });

  it('바꾼 경우, 숫자가 없으면 확인 안내', () => {
    const m = nutritionPlanMessage({ trainerName: '', mealGuides: { lunch: '밥 반 공기' } }, { created: false });
    assert.deepStrictEqual(m, { title: '트레이너가 식단 목표를 바꿨어요', body: '식단 화면에서 확인해 보세요.' });
  });
});
