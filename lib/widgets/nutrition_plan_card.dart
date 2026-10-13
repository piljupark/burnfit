import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/meal.dart';
import '../models/nutrition_plan.dart';

/// 식단 목표 카드 (회원 식단 화면 맨 위 · 트레이너 회원 상세 식단 탭 맨 위).
///
/// 회색 카드(반경 20, 좌우 20 바깥 여백): 머리('식단 목표' 15/700 + '○○ 트레이너 · 10월 12일' 13 mute,
/// [onEdit]이면 오른쪽 '고치기') → 칼로리 한 줄 + 탄수 · 단백질 · 지방 3칸 →
/// 트레이너 한마디(흰 상자) → 끼니별 가이드 줄(끼니 52 + 글).
/// 목표가 없으면 [emptyMessage] 한 줄 (+ [onEdit]이면 '식단 목표 정하기').
class NutritionPlanCard extends StatelessWidget {
  final NutritionPlan? plan;
  final bool loading;
  final String emptyMessage;

  /// 트레이너만: '고치기' / '식단 목표 정하기'
  final VoidCallback? onEdit;

  const NutritionPlanCard({
    super.key,
    required this.plan,
    required this.emptyMessage,
    this.loading = false,
    this.onEdit,
  });

  static const _mealOrder = [
    MealType.breakfast,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: loading
          ? const SizedBox(height: 72)
          : plan == null
          ? _empty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(plan),
                if (plan.hasNumbers) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Numbers(plan: plan),
                ],
                if (plan.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Text(
                      plan.note!,
                      style: AppTextStyles.note.copyWith(
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (plan.mealGuides.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (final type in _mealOrder)
                    if (plan.mealGuides[type] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(
                                type.label,
                                style: AppTextStyles.bodyMd.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                plan.mealGuides[type]!,
                                style: AppTextStyles.note.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            ),
    );
  }

  Widget _header(NutritionPlan plan) {
    final updated = plan.updatedAt;
    final by = [
      if (plan.trainerName.isNotEmpty) '${plan.trainerName} 트레이너',
      if (updated != null) DateFormat('M월 d일', 'ko').format(updated),
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('식단 목표', style: AppTextStyles.bodyMd.bold),
              if (by.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(by, style: AppTextStyles.bodySm),
              ],
            ],
          ),
        ),
        if (onEdit != null)
          Semantics(
            button: true,
            label: '식단 목표 고치기',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: AppSize.touchMin,
                child: Center(
                  child: Text(
                    '고치기',
                    style: AppTextStyles.bodyMd.medium.copyWith(
                      color: AppColors.body,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty() {
    return Row(
      children: [
        Icon(AppIcons.meal, size: AppSize.icon, color: AppColors.mute),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(emptyMessage, style: AppTextStyles.note)),
        if (onEdit != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.ink,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onEdit,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '정하기',
                  style: AppTextStyles.bodySm.bold.copyWith(
                    color: AppColors.canvas,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 숫자: 칼로리는 한 줄(흰 상자 52 · '하루 칼로리' 14 body … 22/700 + 'kcal'),
/// 탄수 · 단백질 · 지방은 3칸(이름 12 mute · 20/700 + 'g'). 트레이너 입력 화면과 같은 짜임.
/// 4칸을 한 줄에 두면 작은 화면 · 큰 글씨에서 긴 칼로리 값만 줄어들어 이렇게 나눴다.
/// 값이 없는 줄(칼로리 없음 / 탄단지 모두 없음)은 두지 않고, 3칸 중 빈 칸은 '–'.
class _Numbers extends StatelessWidget {
  final NutritionPlan plan;

  const _Numbers({required this.plan});

  static final _number = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final macros = [
      ('탄수화물', plan.carbs),
      ('단백질', plan.protein),
      ('지방', plan.fat),
    ];
    final hasMacros = macros.any((m) => m.$2 != null);
    final unitStyle = AppTextStyles.bodySm.copyWith(
      fontWeight: FontWeight.w400,
    );
    final numberStyle = AppTextStyles.section.bold.copyWith(
      fontSize: 20,
      height: 26 / 20,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.calories != null)
          Semantics(
            label: '하루 칼로리 ${plan.calories}킬로칼로리',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppRadius.iconBox),
              ),
              child: Row(
                children: [
                  Text('하루 칼로리', style: AppTextStyles.bodySmall),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: _number.format(plan.calories)),
                            TextSpan(text: ' kcal', style: unitStyle),
                          ],
                        ),
                        style: numberStyle.copyWith(
                          fontSize: 22,
                          height: 28 / 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (plan.calories != null && hasMacros) const SizedBox(height: 6),
        if (hasMacros)
          Row(
            children: [
              for (var i = 0; i < macros.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    label: macros[i].$2 == null
                        ? '${macros[i].$1} 정하지 않음'
                        : '${macros[i].$1} ${macros[i].$2}그램',
                    excludeSemantics: true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(AppRadius.iconBox),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            macros[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.captionSmall,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: macros[i].$2 == null
                                        ? '–'
                                        : _number.format(macros[i].$2),
                                  ),
                                  if (macros[i].$2 != null)
                                    TextSpan(text: ' g', style: unitStyle),
                                ],
                              ),
                              style: numberStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// 식단 탭의 목표 줄 (회원 알약을 골랐을 때 피드 맨 위, 시안 08 '목표 잇기').
///
/// 회색 상자(반경 18, 안쪽 12 14): 첫째 줄 = '하루 2,450kcal' 15/700, 칼로리가 없으면 작은 머리
/// '하루 목표' / '끼니 가이드' 14/500 + 오른쪽 '고치기 ›' → 탄단지(정한 것만, 늘 따로 한 줄 14/500)
/// → 끼니 가이드 줄(끼니 700 + 글 13 body). 정하지 않은 값은 '–'도 없이 뺀다.
/// 목표가 없으면 '식단 목표가 없어요' + 검정 '정하기'.
/// 누구 목표인지는 바로 위에서 고른 회원 알약이 보여 주므로 이름은 넣지 않는다.
class NutritionGoalStrip extends StatelessWidget {
  final NutritionPlan? plan;
  final VoidCallback onEdit;

  const NutritionGoalStrip({
    super.key,
    required this.plan,
    required this.onEdit,
  });

  static final _number = NumberFormat('#,##0');

  static const _mealOrder = [
    MealType.breakfast,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];

  /// 탄단지 한 줄 조각들 ('탄수화물 325g'). 정한 것만.
  static List<String> macroParts(NutritionPlan plan) => [
    if (plan.carbs != null) '탄수화물 ${_number.format(plan.carbs)}g',
    if (plan.protein != null) '단백질 ${_number.format(plan.protein)}g',
    if (plan.fat != null) '지방 ${_number.format(plan.fat)}g',
  ];

  /// 첫째 줄 글자와 굵게 쓸지.
  static (String, bool) headline(NutritionPlan plan) {
    if (plan.calories != null) {
      return ('하루 ${_number.format(plan.calories)}kcal', true);
    }
    return (macroParts(plan).isNotEmpty ? '하루 목표' : '끼니 가이드', false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final box = BoxDecoration(
      color: AppColors.canvasCard,
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: box,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '식단 목표가 없어요',
                style: AppTextStyles.note.copyWith(color: AppColors.body),
              ),
            ),
            Material(
              color: AppColors.ink,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onEdit,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '정하기',
                    style: AppTextStyles.bodySm.bold.copyWith(
                      color: AppColors.canvas,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final (title, strong) = headline(plan);
    final macros = macroParts(plan);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: strong
                      ? AppTextStyles.bodyMd.bold
                      : AppTextStyles.bodySmall.medium.copyWith(
                          color: AppColors.ink,
                        ),
                ),
              ),
              Semantics(
                button: true,
                label: '식단 목표 고치기',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '고치기',
                          style: AppTextStyles.bodySmall.medium.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRightBold,
                          size: 16,
                          color: AppColors.chevron,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (macros.isNotEmpty)
            // 한 항목('지방 60g')은 쪼개지 않고, 넘치면 항목 사이에서 다음 줄로.
            Wrap(
              children: [
                for (var i = 0; i < macros.length; i++)
                  Text(
                    i == 0 ? macros[i] : ' · ${macros[i]}',
                    style: AppTextStyles.bodySmall.medium.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
              ],
            ),
          for (final type in _mealOrder)
            if (plan.mealGuides[type] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${type.label}  ',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: plan.mealGuides[type]),
                    ],
                  ),
                  style: AppTextStyles.caption,
                ),
              ),
        ],
      ),
    );
  }
}
