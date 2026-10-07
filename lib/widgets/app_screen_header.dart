import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_icon_button.dart';

/// 하위 화면 앱바: 뒤로 버튼 + 제목(20) + 오른쪽 행동. 높이 56, 그림자 없음.
///
/// - [subtitle]은 제목 아래 보조 줄(body-sm).
/// - [divider]가 true면 아래에 1px hairline (화면 폭으로 놓을 때).
/// - 오른쪽 행동은 AppIconButton 최대 3개 또는 글자 버튼(AppButton ghost).
class AppScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool divider;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.appBar),
      decoration: divider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline)))
          : null,
      child: Row(
        children: [
          if (onBack != null) ...[
            // 앱바 안에서는 아이콘을 시각적으로 화면 가장자리에 맞춘다
            Transform.translate(
              offset: const Offset(-12, 0),
              child: AppIconButton(icon: AppIcons.back, label: '뒤로', onPressed: onBack),
            ),
          ],
          Expanded(
            child: Transform.translate(
              offset: Offset(onBack != null ? -12 : 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
