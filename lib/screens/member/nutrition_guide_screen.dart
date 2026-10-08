import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/food_guide_data.dart';
import '../../models/food_guide.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import 'food_detail_sheet.dart';
import 'food_list_screen.dart';

/// 영양 가이드 (시안 MemB-NutritionGuide): 상황별 추천(이럴 땐 이렇게) + 8 회색 띠 + 영양소별 2×2
/// → 음식 목록 → 상세 시트. 데이터는 앱 고정 파일([FoodGuideData]).
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
    final situations = FoodGuideData.situations;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
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
                    child: Text(
                      '부족한 게 있을 때 무엇을 먹으면 좋을지 가볍게 참고하세요.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.body,
                        height: 1.55,
                      ),
                    ),
                  ),
                  AppMonthHeader(
                    label: '이럴 땐 이렇게',
                    count: '${situations.length}',
                  ),
                  // 줄 높이 68, 좌우 20 안쪽 선, 마지막 줄 아래는 선 없음. 왼쪽에서 밀려 들어온다.
                  for (var i = 0; i < situations.length; i++) ...[
                    if (i > 0) const AppRowDivider.inset(),
                    AppEntrance.slide(
                      delay: Duration(milliseconds: 50 * i),
                      child: AppActionRow(
                        chevronSize: 16,
                        icon: situations[i].icon,
                        label: situations[i].title,
                        subtitle: FoodGuideData.resolve(
                          situations[i].foodIds,
                        ).take(3).map((f) => f.name).join(' · '),
                        onTap: () => _openList(
                          context,
                          title: situations[i].title,
                          description: situations[i].description,
                          foods: FoodGuideData.resolve(situations[i].foodIds),
                        ),
                      ),
                    ),
                  ],
                  const AppSectionBand(top: AppSpacing.md),
                  const AppMonthHeader(
                    label: '영양소별로 찾기',
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.lg,
                      AppSpacing.screenH,
                      AppSpacing.md,
                    ),
                  ),
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
                                        ? AppEntrance(
                                            delay: Duration(
                                              milliseconds: 60 * j,
                                            ),
                                            child: _CategoryTile(
                                              info: categories[j],
                                              onTap: () => _openList(
                                                context,
                                                title: categories[j]
                                                    .category
                                                    .label,
                                                description:
                                                    categories[j].description,
                                                foods: FoodGuideData.byCategory(
                                                  categories[j].category,
                                                ),
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

/// 영양소 칸 (회색 면, 반경 20, 안쪽 16, 테두리 없음):
/// 아이콘 26 → 12 → 이름 17/500 → 2 → 설명 14 body → 12 → 음식 수 13 mute.
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
        hasBorder: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(info.icon, size: 26, color: AppColors.ink),
            const SizedBox(height: AppSpacing.md),
            Text(name, style: AppTextStyles.section),
            const SizedBox(height: 2),
            Text(info.tagline, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Text('음식 $count개', style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }
}
