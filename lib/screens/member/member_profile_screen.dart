import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
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
import '../../widgets/theme_setting_row.dart';
import '../../widgets/delete_account_sheet.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../common/notice_menu_row.dart';
import 'member_profile_detail_screen.dart';
import 'member_share_settings_screen.dart';
import 'member_workout_stats_screen.dart';

/// 회원 마이 탭 (시안 My.html): 28 제목 → 프로필 줄 → PT 남은 횟수 카드 →
/// 내 몸(신체 정보 · 인바디 추이 · 운동 통계) → 계정(공지사항 · 기록 공유 · 화면 테마 · 로그아웃) → 탈퇴 링크.
/// 줄은 아이콘 없이 글자만, 오른쪽에 요약 값.
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
              _ProfileLine(
                name: user.name,
                subtitle: subtitle,
                onTap: () => _push(const MemberProfileDetailScreen()),
              ),
              if (ptInfo != null) _PtRemainingCard(info: ptInfo),
              const _Band(top: AppSpacing.xl),

              // ── 내 몸 ─────────────────────────────────────────────────
              const _GroupLabel('내 몸'),
              AppPlainRow(
                label: '신체 정보',
                trailing: _value(_bodySummary(user.profile)),
                onTap: () => _push(const MemberProfileDetailScreen()),
              ),
              AppPlainRow(
                label: '인바디 추이',
                trailing: _value(_inbodySummary(_inbodies)),
                onTap: () => _push(const MemberProfileDetailScreen()),
              ),
              AppPlainRow(
                label: '운동 통계',
                trailing: _value(
                  _workoutDaysThisMonth == null
                      ? null
                      : '이번 달 $_workoutDaysThisMonth회',
                ),
                onTap: () => _push(const MemberWorkoutStatsScreen()),
              ),
              const _Band(top: AppSpacing.md),

              // ── 계정 ─────────────────────────────────────────────────
              const _GroupLabel('계정'),
              const NoticeMenuRow(plain: true),
              AppPlainRow(
                label: '기록 공유',
                trailing: _value(
                  '3개 중 ${_sharedCount(user.shareSettings)}개 공개',
                ),
                onTap: () => _push(const MemberShareSettingsScreen()),
              ),
              const ThemeSettingRow(plain: true),
              AppPlainRow(
                label: '로그아웃',
                onTap: () async {
                  await context.read<UserProvider>().signOut();
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.memberLogin);
                },
              ),
              // 시안: 로그아웃 아래 12 → 글자 버튼 자체 위 여백(약 14)으로 맞춘다
              const DeleteAccountLink(leading: true),
            ],
          ),
        ),
      ),
    );
  }

  /// 줄 오른쪽 요약 값: 15, Main 계열 캡션 색(#767676).
  static Widget? _value(String? text) => text == null || text.isEmpty
      ? null
      : Text(
          text,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.caption),
        );

  static int _sharedCount(ShareSettings s) =>
      [s.workout, s.meal, s.body].where((on) => on).length;

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

/// 프로필 줄: 이름 20/700 + 보조 줄 14 캡션 + 화살표 20. 최소 64 높이.
class _ProfileLine extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileLine({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 탭 제목(AppHero) 아래 16은 제목이 둔다
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: AppTextStyles.title.bold),
                      if (subtitle.isNotEmpty) ...[
                        const Gap(2),
                        Text(
                          subtitle,
                          style: AppTextStyles.note.copyWith(
                            color: AppColors.caption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  AppIcons.chevronRightBold,
                  size: 20,
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

/// PT 남은 횟수 카드 (주황, 반경 20): 'PT 남은 횟수' / 'M월 d일까지',
/// '7회 / 20회'(30), 8 높이 막대 = 쓴 횟수 비율.
class _PtRemainingCard extends StatelessWidget {
  final PtInfo info;

  const _PtRemainingCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onPrimary;
    final total = info.totalSessions;
    final used = total == 0
        ? 0.0
        : ((total - info.remainingSessions) / total).clamp(0.0, 1.0);
    final big = AppTextStyles.displayMd.bold.copyWith(
      fontSize: 30,
      height: 36 / 30,
      letterSpacing: 30 * -0.019,
      color: fg,
    );
    final endDate = info.endDate;
    return Semantics(
      label: 'PT 남은 횟수 ${info.remainingSessions}회, 전체 $total회',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'PT 남은 횟수',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (endDate != null)
                  Text(
                    DateFormat('M월 d일까지', 'ko').format(endDate),
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const Gap(6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${info.remainingSessions}회'),
                  TextSpan(
                    text: ' / $total회',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: fg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              style: big,
            ),
            const Gap(14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: fg.withValues(alpha: 0.15)),
                    // 시안 `fill`: 1초 동안 왼쪽에서 차오름 (cubic-bezier(.2,.8,.2,1))
                    FractionallySizedBox(
                      widthFactor: used,
                      child: AppGrow(
                        duration: const Duration(milliseconds: 1000),
                        child: Container(
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 사이 8 회색 띠.
class _Band extends StatelessWidget {
  final double top;

  const _Band({required this.top});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.sm,
      margin: EdgeInsets.only(top: top),
      color: AppColors.canvasCard,
    );
  }
}

/// 묶음 이름: 15 캡션 색, 위 20 · 아래 4.
class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.caption),
        ),
      ),
    );
  }
}
