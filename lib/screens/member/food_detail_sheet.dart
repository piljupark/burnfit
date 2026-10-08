import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/food_guide_data.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_action_row.dart';
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

/// 음식 상세 시트: 1회 분량·kcal → 탄·단·지 막대 → 먹는 법 → 같이 먹으면 좋은 것 → 식단에 추가.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBottomSheetHeader(
          title: food.name,
          subtitle: '${food.serving} · ${food.kcal}kcal',
        ),
        if (food.tags.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final tag in food.tags) AppTag(tag.label)],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
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
        _MacroRow(label: '지방', grams: food.fat, share: share(food.fat, 9)),
        const SizedBox(height: AppSpacing.base),
        const AppRowDivider(),
        if (food.howToEat.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            '먹는 법',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in food.howToEat)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '· $line',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
            ),
        ],
        if (pairs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            '같이 먹으면 좋아요',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final pair in pairs)
                AppChip(
                  label: pair.name,
                  selected: false,
                  onTap: () => onOpenPair(pair),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          '참고용 대략값이에요. 조리법·제품에 따라 달라져요.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
        ),
        if (addAction != null) ...[
          const SizedBox(height: AppSpacing.base),
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

/// 영양소 한 줄: 이름 + 4px 막대(열량 비중) + 그램.
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
        height: 32,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
            ),
            Expanded(
              child: AppProgressBar(
                value: share,
                height: 4,
                color: highlight ? AppColors.primary : null,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${g}g',
                textAlign: TextAlign.right,
                style: AppTextStyles.counter.copyWith(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
