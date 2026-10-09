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

/// 마이 탭 맨 위 프로필 줄 (회원·트레이너·관리자 공통): 최소 72 · 좌우 20 · 위아래 12,
/// 이름 20 Bold + (2) 보조 줄 14 mute (센터·역할·담당 글자). 이니셜 원·역할 태그 없음.
/// [onTap]이 있으면 오른쪽 20 Bold 화살표(chevron)와 함께 누를 수 있다 (회원 → 내 프로필).
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
                  style: AppTextStyles.title.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTextStyles.fieldLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              AppIcons.chevronRightBold,
              size: AppSize.icon,
              color: AppColors.chevron,
            ),
        ],
      ),
    );
    if (onTap == null) return Semantics(container: true, child: content);
    return Semantics(
      button: true,
      label: '$name, $subtitle',
      hint: '프로필 열기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: content,
      ),
    );
  }
}
