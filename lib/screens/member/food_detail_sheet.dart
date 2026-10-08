import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/food_guide_data.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/app_tag.dart';

/// 고른 음식을 식단에 넣는 동작. 영양 가이드를 연 화면(식단 기록)이 정한다.
class FoodAddAction {
  /// 버튼 글자 (예: '오늘 식단에 추가')
  final String label;
  final Future<void> Function(FoodItem food) onAdd;

  const FoodAddAction({required this.label, required this.onAdd});
}

/// 음식 상세 시트 (시안 MemB-FoodDetailSheet): 제목 22 + '분량 · kcal · 특성' 줄
/// → 회색 상자 안 탄·단·지 막대 → 먹는 법 → 같이 먹으면 좋은 것 → 식단에 추가.
/// [addAction]이 없으면 추가 버튼을 그리지 않는다.
Future<void> showFoodDetailSheet(
  BuildContext context,
  FoodItem food, {
  FoodAddAction? addAction,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: _FoodDetail(
      food: food,
      addAction: addAction,
      onOpenPair: (pair) {
        Navigator.of(context).pop();
        showFoodDetailSheet(context, pair, addAction: addAction);
      },
      onAdd: addAction == null
          ? null
          : () {
              Navigator.of(context).pop();
              addAction.onAdd(food);
            },
    ),
  );
}

class _FoodDetail extends StatelessWidget {
  final FoodItem food;
  final FoodAddAction? addAction;
  final ValueChanged<FoodItem> onOpenPair;
  final VoidCallback? onAdd;

  const _FoodDetail({
    required this.food,
    required this.addAction,
    required this.onOpenPair,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = FoodGuideData.resolve(food.pairsWith);
    // 막대 길이는 열량 비중 (단백질·탄수화물 4kcal/g, 지방 9kcal/g)
    final energy = food.protein * 4 + food.carbs * 4 + food.fat * 9;
    double share(double grams, int kcalPerGram) =>
        energy == 0 ? 0 : grams * kcalPerGram / energy;
    final sectionLabel = AppTextStyles.fieldLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBottomSheetHeader(
          title: food.name,
          gap: 0,
          // '100g · 109kcal · 편의점' (14 mute, 열량 숫자만 ink 500)
          subtitleWidget: Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${food.serving} · '),
                    TextSpan(
                      text: '${food.kcal}',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: 'kcal'),
                  ],
                ),
                style: sectionLabel,
              ),
              if (food.tags.isNotEmpty)
                Flexible(
                  child: Text(
                    ' · ${food.tags.map((t) => t.label).join(' · ')}',
                    style: sectionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.base),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.base,
          ),
          decoration: BoxDecoration(
            color: AppColors.canvasCard,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Column(
            children: [
              _MacroRow(
                label: '단백질',
                grams: food.protein,
                share: share(food.protein, 4),
                highlight: true,
              ),
              _MacroRow(
                label: '탄수화물',
                grams: food.carbs,
                share: share(food.carbs, 4),
              ),
              _MacroRow(
                label: '지방',
                grams: food.fat,
                share: share(food.fat, 9),
              ),
            ],
          ),
        ),
        if (food.howToEat.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('먹는 법', style: sectionLabel),
          const SizedBox(height: 6),
          for (final line in food.howToEat)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '•',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.body,
                      height: 1.6,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.body,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
        ],
        if (pairs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('같이 먹으면 좋아요', style: sectionLabel),
          // 큰 칩은 위아래 2 여백을 품으므로 6 + 2 = 시안 8
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final pair in pairs)
                AppChip(
                  label: pair.name,
                  selected: false,
                  large: true,
                  inkLabel: true,
                  onTap: () => onOpenPair(pair),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('참고용 대략값이에요. 조리법·제품에 따라 달라져요.', style: AppTextStyles.bodySm),
        if (addAction != null) ...[
          const SizedBox(height: 14),
          AppButton(
            label: addAction!.label,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

/// 영양소 한 줄 (30): 이름(64, 15 body) + 12 + 6px 막대(열량 비중, 0.4초 뒤 차오름)
/// + 12 + 그램(48, '23'(15/500) + 'g'(mute)).
class _MacroRow extends StatelessWidget {
  final String label;
  final double grams;
  final double share;
  final bool highlight;

  const _MacroRow({
    required this.label,
    required this.grams,
    required this.share,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = formatGrams(grams);
    return Semantics(
      label: '$label $g그램',
      excludeSemantics: true,
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppProgressBar(
                value: share,
                height: 6,
                color: highlight ? AppColors.primary : null,
                delay: const Duration(milliseconds: 400),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 48,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: g),
                    TextSpan(
                      text: 'g',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMd.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
