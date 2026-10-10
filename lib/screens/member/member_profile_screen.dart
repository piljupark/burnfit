import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/constants.dart';
import '../../models/inbody.dart';
import '../../models/pt_info.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/password_reset_sheet.dart';
import '../../widgets/theme_setting_row.dart';
import '../../widgets/delete_account_sheet.dart';
import '../../widgets/app_loader.dart';
import '../common/notice_menu_row.dart';
import 'member_profile_detail_screen.dart';
import 'member_workout_stats_screen.dart';

/// 회원 마이 탭: 28 제목 → 프로필 줄 → PT 남은 횟수 카드 → 내 몸(신체 정보 · 인바디 추이 · 운동 통계) →
/// 센터(공지사항) → 계정(비밀번호 재설정 · 화면 테마 · 로그아웃) → 가운데 탈퇴 링크.
/// 트레이너·관리자 마이와 같은 메뉴 줄(아이콘 상자 60 · 오른쪽 값 + 화살표)을 쓴다.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => MemberProfileScreenState();
}

class MemberProfileScreenState extends State<MemberProfileScreen> {
  PtInfo? _ptInfo;
  List<Inbody> _inbodies = [];
  int? _workoutDaysThisMonth;

  /// 탭에 다시 들어올 때 부른다 (PT 잔여·인바디가 바뀌었을 수 있다).
  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final now = DateTime.now();
    final keyFormat = DateFormat('yyyy-MM-dd');
    final results = await Future.wait<Object?>([
      FirestoreService.getPtInfo(
        user.uid,
        centerId: user.centerId,
      ).catchError((_) => null),
      FirestoreService.getInbodiesByMember(
        user.uid,
        centerId: user.centerId,
        limit: 2,
      ).catchError((_) => <Inbody>[]),
      WorkoutService.getWorkoutsByDateRange(
        user.centerId,
        user.uid,
        keyFormat.format(DateTime(now.year, now.month)),
        keyFormat.format(DateTime(now.year, now.month + 1, 0)),
      ).then<List<Workout>?>((v) => v).catchError((_) => null),
    ]);
    if (!mounted) return;
    final workouts = results[2] as List<Workout>?;
    setState(() {
      _ptInfo = results[0] as PtInfo?;
      _inbodies = results[1] as List<Inbody>;
      _workoutDaysThisMonth = workouts
          ?.map((w) => w.workoutDate)
          .toSet()
          .length;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
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
    final ptInfo = _ptInfo;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSize.navClearance),
            children: [
              const AppHero(title: '마이'),
              AppProfileRow(
                name: user.name,
                subtitle: subtitle,
                onTap: () => _push(const MemberProfileDetailScreen()),
              ),
              if (ptInfo != null) _PtRemainingCard(info: ptInfo),
              // ── 내 몸 ─────────────────────────────────────────────────
              AppMenuGroup(
                label: '내 몸',
                bandTop: ptInfo != null ? AppSpacing.xl : 0,
                children: [
                  AppActionRow(
                    icon: AppIcons.profile,
                    label: '신체 정보',
                    menu: true,
                    value: _bodySummary(user.profile),
                    onTap: () => _push(const MemberProfileDetailScreen()),
                  ),
                  AppActionRow(
                    icon: AppIcons.chart,
                    label: '인바디 추이',
                    menu: true,
                    value: _inbodySummary(_inbodies),
                    onTap: () => _push(const MemberProfileDetailScreen()),
                  ),
                  AppActionRow(
                    icon: AppIcons.chartBar,
                    label: '운동 통계',
                    menu: true,
                    value: _workoutDaysThisMonth == null
                        ? null
                        : '이번 달 $_workoutDaysThisMonth회',
                    onTap: () => _push(const MemberWorkoutStatsScreen()),
                  ),
                ],
              ),
              // ── 센터 ─────────────────────────────────────────────────
              const AppMenuGroup(
                label: '센터',
                bandTop: AppSpacing.md,
                entranceStart: 3,
                children: [NoticeMenuRow()],
              ),
              // ── 계정 ─────────────────────────────────────────────────
              AppMenuGroup(
                label: '계정',
                bandTop: AppSpacing.md,
                entranceStart: 4,
                children: [
                  AppActionRow(
                    icon: AppIcons.lock,
                    label: '비밀번호 재설정 메일',
                    menu: true,
                    onTap: () => showPasswordResetSheet(
                      context,
                      initialEmail: user.email,
                    ),
                  ),
                  const ThemeSettingRow(),
                  AppActionRow(
                    icon: AppIcons.signOut,
                    label: '로그아웃',
                    menu: true,
                    showChevron: false,
                    onTap: () async {
                      await context.read<UserProvider>().signOut();
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.memberLogin);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const DeleteAccountLink(),
            ],
          ),
        ),
      ),
    );
  }

  /// '175cm · 72kg' (입력한 값만)
  static String? _bodySummary(UserProfile? profile) {
    final parts = [
      if (profile?.height != null) '${_fmt(profile!.height!)}cm',
      if (profile?.weight != null) '${_fmt(profile!.weight!)}kg',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// 최근 두 번의 골격근 차이: '골격근 +1.2kg'. 한 번뿐이면 '1회 측정'.
  static String? _inbodySummary(List<Inbody> items) {
    if (items.isEmpty) return null;
    final latest = items.first.muscleMass;
    final previous = items.length > 1 ? items[1].muscleMass : null;
    if (latest == null || previous == null) return '${items.length}회 측정';
    final diff = latest - previous;
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
    return '골격근 $sign${_fmt(diff.abs())}kg';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// PT 남은 횟수 카드 (주황, 반경 20): 'PT 남은 횟수' / 'M월 d일까지',
/// '7회 / 20회'(30), 8 높이 막대 = 쓴 횟수 비율.
class _PtRemainingCard extends StatelessWidget {
  final PtInfo info;

  const _PtRemainingCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final total = info.totalSessions;
    final used = total == 0
        ? 0.0
        : ((total - info.remainingSessions) / total).clamp(0.0, 1.0);
    final endDate = info.endDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: AppHighlightCard(
        label: 'PT 남은 횟수',
        trailingLabel: endDate == null
            ? null
            : DateFormat('M월 d일까지', 'ko').format(endDate),
        value: '${info.remainingSessions}회',
        unit: ' / $total회',
        progress: used,
        bold: true,
        semanticLabel: 'PT 남은 횟수 ${info.remainingSessions}회, 전체 $total회',
      ),
    );
  }
}
