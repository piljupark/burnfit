import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import 'food_detail_sheet.dart';

/// 음식 목록 (영양소별·상황별 공용, 시안 MemB-FoodList): 설명 → 특성 필터 칩(40)
/// → 열 이름 줄 → 음식 줄(68: 이름 16/500 · 분량·특성 13 / 단백질 15/500 · kcal 13) → 상세 시트.
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
    final labels = ['전체', for (final tag in _tags) tag.label];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
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
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (_tags.isNotEmpty)
                    // 큰 칩(40)은 위아래 2 여백을 품으므로 14 + 2 = 시안 16
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        14,
                        AppSpacing.screenH,
                        0,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < labels.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            AppChip(
                              label: labels[i],
                              selected: i == _filterIndex,
                              large: true,
                              onTap: () => setState(() => _filterIndex = i),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // 열 이름 줄: 위 16, 화면 폭 위 선, 안쪽 10 40 6 20, 12 mute
                  const SizedBox(height: 14),
                  const AppRowDivider(),
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        10,
                        40,
                        6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('음식 · 1회 분량', style: AppTextStyles.captionSmall),
                          Text('단백질 · 열량', style: AppTextStyles.captionSmall),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < foods.length; i++) ...[
                    AppEntrance.slide(
                      // 필터를 바꾸면 줄이 다시 밀려 들어온다
                      key: ValueKey('$_filterIndex-${foods[i].id}'),
                      delay: Duration(milliseconds: 40 * i),
                      child: _FoodRow(
                        food: foods[i],
                        onTap: () => showFoodDetailSheet(
                          context,
                          foods[i],
                          addAction: widget.addAction,
                        ),
                      ),
                    ),
                    const AppRowDivider.inset(),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      14,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      '참고용 대략값이에요. 조리법·제품에 따라 달라져요.',
                      style: AppTextStyles.bodySm,
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

/// 음식 한 줄 (68, 좌우 20): 이름 16/500 + 위 3 '분량 · 특성'(13 mute, 한 줄)
/// / 오른쪽 '23g'(15/500 + g mute) · 위 2 kcal(13 mute) + 12 + 화살표 16.
class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const _FoodRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final protein = formatGrams(food.protein);
    final tags = food.tags.map((t) => t.label).join(', ');
    final detail = [
      food.serving,
      for (final t in food.tags) t.label,
    ].join(' · ');
    return Semantics(
      button: true,
      label:
          '${food.name} ${food.serving}, 단백질 $protein그램, ${food.kcal}킬로칼로리${tags.isEmpty ? '' : ', $tags'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: AppTextStyles.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: AppTextStyles.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: protein),
                        TextSpan(
                          text: 'g',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                    style: AppTextStyles.bodyMd.medium,
                  ),
                  const SizedBox(height: 2),
                  Text('${food.kcal}kcal', style: AppTextStyles.bodySm),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                AppIcons.chevronRightBold,
                size: 16,
                color: AppColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
