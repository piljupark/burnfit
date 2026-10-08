import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import 'food_detail_sheet.dart';

/// 음식 목록 (영양소별·상황별 공용): 설명 → 특성 필터 칩 → 음식 줄(1회 분량 · 단백질 · kcal) → 상세 시트.
class FoodListScreen extends StatefulWidget {
  final String title;
  final String description;
  final List<FoodItem> foods;
  final FoodAddAction? addAction;

  const FoodListScreen({
    super.key,
    required this.title,
    required this.description,
    required this.foods,
    this.addAction,
  });

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  /// 목록에 실제로 있는 특성만 칩으로 보인다 (빈 결과가 나오지 않게).
  late final List<FoodTag> _tags = [
    for (final tag in FoodTag.values)
      if (widget.foods.any((f) => f.tags.contains(tag))) tag,
  ];

  /// 0 = 전체, i = _tags[i - 1]
  int _filterIndex = 0;

  List<FoodItem> get _filtered {
    if (_filterIndex == 0) return widget.foods;
    final tag = _tags[_filterIndex - 1];
    return widget.foods.where((f) => f.tags.contains(tag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final foods = _filtered;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: widget.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: AppSpacing.xl2 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      widget.description,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.body,
                      ),
                    ),
                  ),
                  if (_tags.isNotEmpty)
                    AppScrollableChips(
                      labels: ['전체', for (final tag in _tags) tag.label],
                      selectedIndex: _filterIndex,
                      onSelected: (i) => setState(() => _filterIndex = i),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm,
                        AppSpacing.screenH,
                        AppSpacing.xs,
                      ),
                    ),
                  const AppRowDivider(),
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm,
                        44,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '음식 · 1회 분량',
                              style: AppTextStyles.captionSmall,
                            ),
                          ),
                          Text('단백질 · 열량', style: AppTextStyles.captionSmall),
                        ],
                      ),
                    ),
                  ),
                  for (final food in foods) ...[
                    _FoodRow(
                      food: food,
                      onTap: () => showFoodDetailSheet(
                        context,
                        food,
                        addAction: widget.addAction,
                      ),
                    ),
                    const AppRowDivider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.md,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      '참고용 대략값이에요. 조리법·제품에 따라 달라져요.',
                      style: AppTextStyles.captionSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 음식 한 줄: 이름(17) + 분량·특성 태그 / 오른쪽 단백질 g · kcal + 화살표.
class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const _FoodRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final protein = formatGrams(food.protein);
    final tags = food.tags.map((t) => t.label).join(', ');
    return Semantics(
      button: true,
      label:
          '${food.name} ${food.serving}, 단백질 $protein그램, ${food.kcal}킬로칼로리${tags.isEmpty ? '' : ', $tags'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: AppTextStyles.bodyLg),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(food.serving, style: AppTextStyles.bodySm),
                        for (final tag in food.tags) AppTag(tag.label),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${protein}g',
                    style: AppTextStyles.counter.copyWith(
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('${food.kcal}kcal', style: AppTextStyles.counter),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
            ],
          ),
        ),
      ),
    );
  }
}
