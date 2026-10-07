import 'package:flutter/material.dart';

import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_avatar.dart';
import 'app_tag.dart';

/// 프로필 머리: 56px 이니셜 아바타 + 이름(28) + 역할 태그 + 보조 줄. 카드 면 없이 캔버스 위에 놓는다.
/// [avatarColor]·gradient 인자는 기존 호출부 호환용이며 무시된다 (아바타 색은 [seed]로 정해진다).
class AppProfileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String roleLabel;
  final Color? avatarColor;
  final String? seed;

  const AppProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.roleLabel,
    this.avatarColor,
    this.seed,
    Color? gradientStart,
    Color? gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(name: name, seed: seed, size: 56),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(name, style: AppTextStyles.displayMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppTag(roleLabel),
                ],
              ),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
