import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_icon_box.dart';
import 'app_tag.dart';

/// 메뉴·목록 한 줄 (시안 공통): 최소 68, 좌우 20, 40 아이콘 상자 + 14 + 라벨 16/500 + 보조 13 mute(위 2)
/// + 오른쪽(배지·18 화살표 chevron).
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

  /// 화살표 크기 (기본 18, 시안 MemB-NutritionGuide는 16)
  final double chevronSize;

  /// 마이 탭 메뉴 줄 (시안 Tr-My·Ad-My): 높이 60, 라벨 16 Regular
  final bool menu;

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
    this.chevronSize = 18,
    this.menu = false,
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
          constraints: BoxConstraints(minHeight: menu ? 60 : 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (isDestructive)
                  SizedBox(
                    width: 40,
                    child: Icon(icon, size: AppSize.icon, color: fg),
                  )
                else
                  AppIconBox(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style:
                            (isDestructive
                                    ? AppTextStyles.bodyMd
                                    : AppTextStyles.listTitle)
                                .copyWith(
                                  color: fg,
                                  fontWeight: menu ? FontWeight.w400 : null,
                                ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTextStyles.bodySm),
                      ],
                    ],
                  ),
                ),
                if (badge != null) ...[
                  AppTag(badge!, strong: true),
                  const SizedBox(width: AppSpacing.sm),
                ],
                ?trailing,
                if (showChevron && !isDestructive && trailing == null)
                  Icon(
                    AppIcons.chevronRightBold,
                    size: chevronSize,
                    color: AppColors.chevron,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록 구분선 (1px hairline). 시안 목록은 대개 좌우 20 안쪽 → [AppRowDivider.inset].
class AppRowDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const AppRowDivider({super.key, this.indent = 0, this.endIndent = 0});

  /// 좌우 20 안쪽에만 긋는 선 (시안 목록 줄 `padding: 0 20` + 아래 선).
  const AppRowDivider.inset({super.key})
    : indent = AppSpacing.screenH,
      endIndent = AppSpacing.screenH;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: indent,
    endIndent: endIndent,
    color: AppColors.hairline,
  );
}

/// 묶음 사이 8 회색 띠 (#F6F6F7, 시안 공통). [top]은 띠 위 여백.
class AppSectionBand extends StatelessWidget {
  final double top;

  const AppSectionBand({super.key, this.top = 0});

  @override
  Widget build(BuildContext context) => Container(
    height: AppSpacing.sm,
    margin: EdgeInsets.only(top: top),
    color: AppColors.canvasCard,
  );
}

/// 글자만 있는 목록 줄 (시안 Main 계열 My): 56 높이, 왼쪽 16 라벨 · 오른쪽 15 mute 값.
/// 아이콘 상자와 화살표를 두지 않는다. 좌우 20 여백을 스스로 둔다.
class AppPlainRow extends StatelessWidget {
  final String label;
  final String? value;

  /// 값 대신 오른쪽에 둘 위젯 (예: 새 글 점 + 글자)
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppPlainRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          height: AppSize.listRow,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.listTitle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (value != null && value!.isNotEmpty)
                Text(value!, style: AppTextStyles.eyebrow),
            ],
          ),
        ),
      ),
    );
  }
}
