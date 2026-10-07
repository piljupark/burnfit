import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_tag.dart';

/// 메뉴·목록 한 줄: 아이콘 상자 + 라벨(17) + 보조 줄 + 오른쪽(배지·화살표).
/// 파괴적 행([isDestructive])은 맨 아래, 라벨과 아이콘 모두 danger.
/// [iconColor]·[badgeColor]는 기존 호출부 호환용이며 색으로 구분하지 않는다.
class AppActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
  final bool isDestructive;
  final Color? iconColor;
  final Widget? trailing;
  final bool showChevron;

  const AppActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.isDestructive = false,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? AppColors.danger : AppColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            child: Row(
              children: [
                if (isDestructive)
                  SizedBox(width: 40, child: Icon(icon, size: AppSize.icon, color: fg))
                else
                  _IconTile(icon: icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: (isDestructive ? AppTextStyles.bodyMd : AppTextStyles.bodyLg).copyWith(color: fg)),
                      if (subtitle != null) Text(subtitle!, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                if (badge != null) ...[AppTag(badge!, strong: true), const SizedBox(width: AppSpacing.sm)],
                ?trailing,
                if (showChevron && !isDestructive && trailing == null)
                  const Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Icon(icon, size: AppSize.icon, color: AppColors.ink),
    );
  }
}

/// 목록 구분선 (1px hairline, 화면 폭).
class AppRowDivider extends StatelessWidget {
  final double indent;

  const AppRowDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, indent: indent, color: AppColors.hairline);
}
