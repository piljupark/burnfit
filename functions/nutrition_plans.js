// 트레이너가 회원 식단 목표를 정하거나 바꿨을 때 회원에게 보낼 알림 (index.js onNutritionPlanWritten).

const CONTENT_KEYS = ['calories', 'carbs', 'protein', 'fat', 'mealGuides', 'note'];

/** 회원이 보는 내용이 바뀌었는지 (updatedAt만 바뀐 저장은 알리지 않는다). 새로 만들면 true. */
function planContentChanged(before, after) {
  if (!after) return false;
  if (!before) return true;
  return CONTENT_KEYS.some((k) => JSON.stringify(before[k] ?? null) !== JSON.stringify(after[k] ?? null));
}

/** '○○ 트레이너가 식단 목표를 정했어요' / 칼로리가 있으면 '하루 2,100kcal · 단백질 140g'. */
function nutritionPlanMessage(plan, { created }) {
  const trainer = typeof plan?.trainerName === 'string' && plan.trainerName.trim()
    ? `${plan.trainerName.trim()} 트레이너가`
    : '트레이너가';
  const title = `${trainer} 식단 목표를 ${created ? '정했어요' : '바꿨어요'}`;
  const parts = [];
  if (typeof plan?.calories === 'number') parts.push(`하루 ${plan.calories.toLocaleString('ko-KR')}kcal`);
  if (typeof plan?.protein === 'number') parts.push(`단백질 ${plan.protein}g`);
  const body = parts.length > 0 ? parts.join(' · ') : '식단 화면에서 확인해 보세요.';
  return { title, body };
}

module.exports = { planContentChanged, nutritionPlanMessage };
