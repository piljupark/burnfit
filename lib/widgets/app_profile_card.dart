import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 상세 화면 사람 머리 (시안 TrainerMember·AdminMemberDetail): 이름 26/500 + (4) 보조 줄 14 mute.
/// 카드 면·이니셜 원·역할 태그 없이 캔버스 위에 놓는다. 좌우 여백은 부르는 쪽이 둔다.
/// [bold]: 이름 Bold — 기준 시안 계열(Trainer*·Admin*)
class AppProfileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool bold;

  const AppProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameBase = AppTextStyles.displayMd.natural.copyWith(
      fontSize: 26,
      letterSpacing: 26 * -0.019,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            name,
            style: bold ? nameBase.bold : nameBase,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.fieldLabel.natural,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// 마이 탭 맨 위 프로필 줄: 이름(20) + 보조 줄(센터·역할 등 글자) + 화살표.
/// 이니셜 원·역할 태그를 쓰지 않는다. [onTap]이 없으면 화살표 없이 정보만 보인다.
/// [large]: 시안 Ad-My — 위 20 · 아래 24, 이름 22, 보조 줄과 4 띄움.
class AppProfileRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final bool large;

  const AppProfileRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: large
          ? const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.xl,
            )
          : const EdgeInsets.symmetric(
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
                  style: large
                      ? AppTextStyles.sheetTitle.natural
                      : AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: large ? AppSpacing.xs : AppSpacing.xxs),
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
