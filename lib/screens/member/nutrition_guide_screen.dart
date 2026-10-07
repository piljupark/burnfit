import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/food_guide_data.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import 'food_detail_sheet.dart';
import 'food_list_screen.dart';

/// 영양 가이드: 상황별 추천(이럴 땐 이렇게) + 영양소별 2×2 → 음식 목록 → 상세 시트.
/// 데이터는 앱 고정 파일([FoodGuideData]).
class NutritionGuideScreen extends StatelessWidget {
  final FoodAddAction? addAction;

  const NutritionGuideScreen({super.key, this.addAction});

  void _openList(
    BuildContext context, {
    required String title,
    required String description,
    required List<FoodItem> foods,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodListScreen(
          title: title,
          description: description,
          foods: foods,
          addAction: addAction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = FoodGuideData.categories;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '영양 가이드',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '부족한 게 있을 때 무엇을 먹으면 좋을지 가볍게 참고하세요.',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppMonthHeader(
                    label: '이럴 땐 이렇게',
                    count: '${FoodGuideData.situations.length}',
                  ),
                  for (final s in FoodGuideData.situations) ...[
                    AppActionRow(
                      icon: s.icon,
                      label: s.title,
                      subtitle: FoodGuideData.resolve(
                        s.foodIds,
                      ).take(3).map((f) => f.name).join(' · '),
                      onTap: () => _openList(
                        context,
                        title: s.title,
                        description: s.description,
                        foods: FoodGuideData.resolve(s.foodIds),
                      ),
                    ),
                    const AppRowDivider(),
                  ],
                  const AppMonthHeader(label: '영양소별로 찾기'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < categories.length; i += 2) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.sm),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var j = i; j < i + 2; j++) ...[
                                  if (j > i)
                                    const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: j < categories.length
                                        ? _CategoryTile(
                                            info: categories[j],
                                            onTap: () => _openList(
                                              context,
                                              title:
                                                  categories[j].category.label,
                                              description:
                                                  categories[j].description,
                                              foods: FoodGuideData.byCategory(
                                                categories[j].category,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
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

/// 영양소 칸: 아이콘 + 이름(17) + 짧은 설명 + 음식 수.
class _CategoryTile extends StatelessWidget {
  final NutrientCategoryInfo info;
  final VoidCallback onTap;

  const _CategoryTile({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = FoodGuideData.byCategory(info.category).length;
    final name = info.category.label;
    return Semantics(
      button: true,
      label: '$name, ${info.tagline}, 음식 $count개',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(info.icon, size: AppSize.icon, color: AppColors.ink),
            const SizedBox(height: AppSpacing.sm),
            Text(name, style: AppTextStyles.bodyLg),
            Text(
              info.tagline,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('음식 $count개', style: AppTextStyles.captionSmall),
          ],
        ),
      ),
    );
  }
}
