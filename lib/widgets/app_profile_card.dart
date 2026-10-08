import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_tag.dart';

/// 프로필 머리: 이름(28) + 역할 태그 + 보조 줄. 카드 면 없이 캔버스 위에 놓는다 (이니셜 원 없음).
class AppProfileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String roleLabel;

  const AppProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: AppTextStyles.displayMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppTag(roleLabel),
                ],
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 마이 탭 맨 위 프로필 줄: 이름(20) + 보조 줄(센터·역할 등 글자) + 화살표.
/// 이니셜 원·역할 태그를 쓰지 않는다. [onTap]이 없으면 화살표 없이 정보만 보인다.
class AppProfileRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;

  const AppProfileRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    // 시안 Tr-My·Ad-My: 14 mute
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 14,
                      letterSpacing: 14 * -0.019,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
        ],
      ),
    );
    if (onTap == null) return Semantics(container: true, child: content);
    return Semantics(
      button: true,
      label: '$name, $subtitle',
      hint: '프로필 열기',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
