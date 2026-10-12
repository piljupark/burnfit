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
/// [onEdit]이면 오른쪽 '고치기') → 4칸(칼로리 · 탄수 · 단백질 · 지방, 빈 값은 '–') →
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

/// 4칸: 칼로리 · 탄수 · 단백질 · 지방 (값 20/700 + 단위 13 mute, 이름 12 mute).
class _Numbers extends StatelessWidget {
  final NutritionPlan plan;

  const _Numbers({required this.plan});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,##0');
    final cells = [
      ('칼로리', plan.calories, 'kcal'),
      ('탄수화물', plan.carbs, 'g'),
      ('단백질', plan.protein, 'g'),
      ('지방', plan.fat, 'g'),
    ];
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: cells[i].$2 == null
                  ? '${cells[i].$1} 정하지 않음'
                  : '${cells[i].$1} ${cells[i].$2}${cells[i].$3 == 'g' ? '그램' : '킬로칼로리'}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppRadius.iconBox),
                ),
                child: Column(
                  children: [
                    Text(cells[i].$1, style: AppTextStyles.captionSmall),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: cells[i].$2 == null
                                  ? '–'
                                  : number.format(cells[i].$2),
                            ),
                            if (cells[i].$2 != null)
                              TextSpan(
                                text: cells[i].$3,
                                style: AppTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                        style: AppTextStyles.section.bold.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
