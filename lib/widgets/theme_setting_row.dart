import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../services/theme_controller.dart';
import 'app_action_row.dart';
import 'app_bottom_sheet.dart';

/// 마이 → 계정의 '화면 테마' 줄 (회원·트레이너·관리자 공통). 누르면 선택 시트.
class ThemeSettingRow extends StatelessWidget {
  const ThemeSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final choice = context.watch<ThemeController>().choice;
    return AppActionRow(
      icon: AppIcons.theme,
      label: '화면 테마',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(choice.label, style: AppTextStyles.bodySm),
          const SizedBox(width: AppSpacing.xs),
          Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
        ],
      ),
      onTap: () => showAppBottomSheet<void>(
        context: context,
        child: const _ThemeSheet(),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(title: '화면 테마', subtitle: '이 기기에만 적용돼요.'),
        for (final c in AppThemeChoice.values)
          Semantics(
            inMutuallyExclusiveGroup: true,
            selected: c == controller.choice,
            button: true,
            label: c == AppThemeChoice.system
                ? '${c.label}, 기기의 다크 모드를 따릅니다'
                : c.label,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => controller.select(c),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(child: Text(c.label, style: AppTextStyles.bodyLg)),
                    if (c == controller.choice)
                      Icon(
                        AppIcons.checkBold,
                        size: AppSize.icon,
                        color: AppColors.ink,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
