import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/theme_setting_row.dart';
import '../../widgets/delete_account_sheet.dart';
import '../../widgets/orb_loader.dart';
import '../common/notice_menu_row.dart';
import 'member_profile_detail_screen.dart';
import 'member_share_settings_screen.dart';
import 'member_workout_stats_screen.dart';

/// 회원 마이 탭: '나'에 대한 것만 둔다 — 프로필 · 내 몸 · 계정.
/// PT 잔여·일정은 PT 탭, 식단 기록·트레이너 피드백은 홈 바로가기, PT 운동 기록은 PT 탭에 있다.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: AppLoadingView(),
      );
    }
    final trainer = user.trainerName?.trim() ?? '';
    final subtitle = [
      if (user.centerName.isNotEmpty) user.centerName,
      if (trainer.isNotEmpty) '담당 $trainer',
    ].join(' · ');
    final weight = user.profile?.weight;
    final shared = _sharedCount(user.shareSettings);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSize.navClearance),
          children: [
            const AppHero(title: '마이', divider: false),
            AppProfileRow(
              name: user.name,
              subtitle: subtitle,
              onTap: () => _push(context, const MemberProfileDetailScreen()),
            ),

            // ── 내 몸 ─────────────────────────────────────────────────────
            const AppMonthHeader(label: '내 몸'),
            AppActionRow(
              icon: AppIcons.inbody,
              label: '신체 정보 · 인바디',
              trailing: weight == null ? null : _value('${_fmt(weight)} kg'),
              onTap: () => _push(context, const MemberProfileDetailScreen()),
            ),
            const AppRowDivider(),
            // 운동 탭을 정리할 때까지 여기 둔다.
            AppActionRow(
              icon: AppIcons.chartBar,
              label: '운동 통계',
              onTap: () => _push(context, const MemberWorkoutStatsScreen()),
            ),
            const AppRowDivider(),

            // ── 센터 ──────────────────────────────────────────────────────
            const AppMonthHeader(label: '센터'),
            const NoticeMenuRow(),
            const AppRowDivider(),

            // ── 계정 ──────────────────────────────────────────────────────
            const AppMonthHeader(label: '계정'),
            AppActionRow(
              icon: AppIcons.share,
              label: '기록 공유 설정',
              trailing: _value('$shared / 3 공개'),
              onTap: () => _push(context, const MemberShareSettingsScreen()),
            ),
            const AppRowDivider(),
            const ThemeSettingRow(),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.signOut,
              label: '로그아웃',
              showChevron: false,
              onTap: () async {
                await context.read<UserProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.memberLogin);
              },
            ),
            const AppRowDivider(),
            const SizedBox(height: AppSpacing.lg),
            const DeleteAccountLink(),
          ],
        ),
      ),
    );
  }

  static int _sharedCount(ShareSettings s) =>
      [s.workout, s.meal, s.body].where((on) => on).length;

  /// 오른쪽 값 + 화살표 (AppActionRow는 trailing이 있으면 화살표를 그리지 않는다).
  static Widget _value(String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, style: AppTextStyles.bodySm),
      const SizedBox(width: AppSpacing.xs),
      Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
    ],
  );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
