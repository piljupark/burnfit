// 회원이 식단을 올렸을 때 담당 트레이너에게 보낼 알림 문구 (index.js onMealCreated).

const MEAL_LABELS = {
  breakfast: '아침',
  lunch: '점심',
  dinner: '저녁',
  snack: '간식',
};

/** '김민지님이 점심 식단을 올렸어요' / 메모가 있으면 앞부분, 없으면 피드백 안내. */
function mealCreatedMessage(meal) {
  const name = typeof meal?.memberName === 'string' && meal.memberName.trim()
    ? meal.memberName.trim()
    : '회원';
  const label = MEAL_LABELS[meal?.mealType] ?? '';
  const title = label ? `${name}님이 ${label} 식단을 올렸어요` : `${name}님이 식단을 올렸어요`;
  const memo = typeof meal?.description === 'string' ? meal.description.trim() : '';
  const body = memo
    ? (memo.length > 40 ? `${memo.slice(0, 40)}...` : memo)
    : '식단 탭에서 피드백을 남겨 주세요.';
  return { title, body };
}

module.exports = { mealCreatedMessage };
