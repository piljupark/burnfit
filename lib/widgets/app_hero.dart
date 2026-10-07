import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_tag.dart';

/// 탭 화면(홈·운동·PT·마이 등) 상단: 오른쪽 아이콘 버튼 줄 + 큰 제목.
/// 하위 화면은 AppScreenHeader(뒤로 버튼 앱바)를 쓴다.
///
/// 머리말([eyebrow])은 쓰지 않는다 (앱 이름·날짜를 제목 위에 반복하지 않는다).
/// 날짜·상태는 본문 첫 AppMonthHeader에 둔다.
class AppHero extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final Widget? leading;
  final bool divider;

  const AppHero({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.leading,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSize.touchMin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: AppSpacing.xs),
                ...actions,
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.base,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.base),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          monoCase(eyebrow!),
                          style: monoOrSans(
                            eyebrow!,
                            mono: AppTextStyles.eyebrow,
                            sans: AppTextStyles.bodySm,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        title,
                        style: AppTextStyles.displayMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 섹션 구분 머리말: 라벨 + 카운터 + 남은 폭을 채우는 hairline.
/// 영문·숫자 라벨은 모노 대문자, 한글 라벨은 sans 13.
class AppMonthHeader extends StatelessWidget {
  final String label;
  final String? count;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const AppMonthHeader({
    super.key,
    required this.label,
    this.count,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      AppSpacing.xl,
      AppSpacing.screenH,
      AppSpacing.sm,
    ),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = monoOrSans(
      label,
      mono: AppTextStyles.eyebrow.copyWith(color: AppColors.ink),
      sans: AppTextStyles.bodySm.copyWith(color: AppColors.ink),
    );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(monoCase(label), style: labelStyle),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              monoCase(count!),
              style: monoOrSans(
                count!,
                mono: AppTextStyles.eyebrow,
                sans: AppTextStyles.bodySm,
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(height: 1, color: AppColors.hairline)),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
