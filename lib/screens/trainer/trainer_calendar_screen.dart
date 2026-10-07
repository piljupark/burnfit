import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/orb_loader.dart';
import 'trainer_member_detail_screen.dart';
import 'trainer_pt_workout_screen.dart';

class TrainerCalendarScreen extends StatefulWidget {
  final bool showGreeting;

  const TrainerCalendarScreen({super.key, this.showGreeting = false});

  @override
  State<TrainerCalendarScreen> createState() => TrainerCalendarScreenState();
}

class TrainerCalendarScreenState extends State<TrainerCalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  List<AppUser> _members = [];
  List<Workout> _workouts = [];
  List<PtSession> _ptSessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadId = 0;

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void refresh() => _loadMonth();

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final loadId = ++_loadId;
    setState(() => _isLoading = true);

    try {
      final focusedMonth = _focusedMonth;
      final start = DateTime(focusedMonth.year, focusedMonth.month);
      final end = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
      final startKey = _key(start);
      final endKey = _key(end);

      final members = await FirestoreService.getMembersByTrainer(user.centerId, user.uid);

      if (!mounted || loadId != _loadId) return;

      final results = await Future.wait([
        Future.wait(
          members.isEmpty
              ? <Future<List<Workout>>>[]
              : members.map(
                  (m) => WorkoutService.getWorkoutsByDateRange(
                    user.centerId,
                    m.uid,
                    startKey,
                    endKey,
                  ),
                ),
        ),
        FirestoreService.getPtSessionsByTrainer(
          user.centerId,
          user.uid,
          from: start,
          to: DateTime(focusedMonth.year, focusedMonth.month + 1, 0, 23, 59, 59),
        ),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted || loadId != _loadId) return;

      final allWorkouts =
          (results[0] as List<List<Workout>>).expand((l) => l).toList();
      final ptSessions = results[1] as List<PtSession>;

      setState(() {
        _members = members;
        _workouts = allWorkouts;
        _ptSessions =
            ptSessions.where((s) => s.status != PtSessionStatus.cancelled).toList();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted && loadId == _loadId) setState(() => _isLoading = false);
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
    _loadMonth();
  }

  List<Workout> get _selectedWorkouts {
    final key = _key(_selectedDay);
    return _workouts
        .where((w) => w.workoutDate == key && w.workoutType == WorkoutType.personal)
        .toList();
  }

  List<PtSession> get _selectedPtSessions {
    return _ptSessions
        .where((s) => _sameDate(s.scheduledAt, _selectedDay))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Map<String, int> get _personalCountByDay {
    final map = <String, int>{};
    for (final w in _workouts.where((w) => w.workoutType == WorkoutType.personal)) {
      map[w.workoutDate] = (map[w.workoutDate] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _ptCountByDay {
    final map = <String, int>{};
    for (final s in _ptSessions) {
      final key = _key(s.scheduledAt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _openPt(PtSession session) async {
    final member = _members.where((m) => m.uid == session.memberId).firstOrNull;
    if (member == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerPtWorkoutScreen(session: session, member: member),
      ),
    );
    _loadMonth();
  }

  void _openMember(AppUser member) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrainerMemberDetailScreen(member: member)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final ptSessions = _selectedPtSessions;
    final workouts = _selectedWorkouts;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadMonth,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (widget.showGreeting)
                AppHero(
                  eyebrow: 'BURNFIT · TRAINER',
                  title: '${user?.name ?? ''} 트레이너님',
                  actions: const [NotificationBellButton()],
                )
              else
                const AppHero(eyebrow: 'BURNFIT · TRAINER', title: '캘린더'),
              _MonthNav(
                month: _focusedMonth,
                onPrev: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _TrainerCalendarGrid(
                  focusedMonth: _focusedMonth,
                  selectedDay: _selectedDay,
                  personalCountByDay: _personalCountByDay,
                  ptCountByDay: _ptCountByDay,
                  onSelect: (day) => setState(() => _selectedDay = day),
                ),
              ),
              const _CalendarLegend(),
              AppMonthHeader(
                label: DateFormat('MM.dd EEE', 'en_US').format(_selectedDay),
                count: 'PT ${ptSessions.length} · SELF ${workouts.length}',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.base, AppSpacing.screenH, AppSpacing.xs,
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                  child: Center(child: OrbLoader.screen()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: AppErrorCard(message: _errorMessage!, onRetry: _loadMonth),
                )
              else if (workouts.isEmpty && ptSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
                  child: Center(child: Text('이 날의 기록이 없습니다', style: AppTextStyles.bodySm)),
                )
              else ...[
                for (final session in ptSessions)
                  _PtSessionRow(
                    session: session,
                    onRecord: session.status == PtSessionStatus.scheduled
                        ? () => _openPt(session)
                        : null,
                  ),
                for (final workout in workouts)
                  _WorkoutRow(
                    workout: workout,
                    onTap: () {
                      final member =
                          _members.where((m) => m.uid == workout.memberId).firstOrNull;
                      if (member != null) _openMember(member);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 월 이동: 모노 '2026.10' + 이전/다음 아이콘 버튼
// ─────────────────────────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNav({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: DateFormat('yyyy년 M월', 'ko').format(month),
              excludeSemantics: true,
              child: Text(
                DateFormat('yyyy.MM').format(month),
                style: AppTextStyles.eyebrow.copyWith(color: AppColors.ink, fontSize: 13),
              ),
            ),
          ),
          AppIconButton(icon: AppIcons.back, label: '이전 달', onPressed: onPrev),
          AppIconButton(icon: AppIcons.forward, label: '다음 달', onPressed: onNext),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 트레이너용 캘린더 그리드
// 선택일 = 흰 원, 오늘 = 외곽선 원, PT = 채운 점, 개인운동 = 외곽선 점
// ─────────────────────────────────────────────────────────────────────────────

class _TrainerCalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, int> personalCountByDay;
  final Map<String, int> ptCountByDay;
  final ValueChanged<DateTime> onSelect;

  const _TrainerCalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.personalCountByDay,
    required this.ptCountByDay,
    required this.onSelect,
  });

  String _key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final leading = firstDay.weekday - 1;
    final cells = leading + lastDay.day;
    final totalCells = cells <= 35 ? 35 : 42;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(label, style: AppTextStyles.bodySm.copyWith(fontSize: 12, height: 16 / 12)),
                  ),
                ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: AppSize.touchMin,
            mainAxisSpacing: AppSpacing.xxs,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > lastDay.day) {
              return const SizedBox.shrink();
            }

            final day = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
            final key = _key(day);
            final isToday = _sameDate(day, today);
            final isSelected = _sameDate(day, selectedDay);
            final isFuture = day.isAfter(today);
            final personalCount = personalCountByDay[key] ?? 0;
            final ptCount = ptCountByDay[key] ?? 0;

            final semantic = [
              '${focusedMonth.month}월 $dayNumber일',
              if (isToday) '오늘',
              if (ptCount > 0) 'PT $ptCount건',
              if (personalCount > 0) '개인운동 $personalCount건',
            ].join(', ');

            return Semantics(
              button: true,
              selected: isSelected,
              label: semantic,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onSelect(day),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: isToday && !isSelected ? Border.all(color: AppColors.ink) : null,
                      ),
                      child: Text(
                        '$dayNumber',
                        style: AppTextStyles.bodyMd.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          color: isSelected
                              ? AppColors.onPrimary
                              : isFuture
                                  ? AppColors.body
                                  : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (ptCount > 0) const _Dot(filled: true),
                          if (ptCount > 0 && personalCount > 0) const SizedBox(width: 3),
                          if (personalCount > 0) const _Dot(filled: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;

  const _Dot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.ink : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.ink),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
      child: Row(
        children: [
          const _Dot(filled: true),
          const SizedBox(width: 6),
          Text('PT', style: AppTextStyles.counter),
          const SizedBox(width: AppSpacing.base),
          const _Dot(filled: false),
          const SizedBox(width: 6),
          Text('개인운동', style: AppTextStyles.bodySm.copyWith(fontSize: 12, height: 16 / 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 선택된 날짜 기록 — 화면 폭 행 + hairline
// ─────────────────────────────────────────────────────────────────────────────

class _PtSessionRow extends StatelessWidget {
  final PtSession session;

  /// 예약 상태일 때만 기록 화면으로 들어간다 (완료·취소는 null).
  final VoidCallback? onRecord;

  const _PtSessionRow({required this.session, this.onRecord});

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == PtSessionStatus.completed;
    final timeStr = DateFormat('HH:mm').format(session.scheduledAt);

    return _MemberRow(
      name: session.memberName,
      seed: session.memberId,
      meta: '$timeStr · PT · ${session.durationMinutes}분',
      onTap: onRecord,
      trailing: isCompleted
          ? const AppTag('DONE', strong: true)
          : onRecord != null
              ? AppButton(
                  label: '기록',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: onRecord,
                )
              : null,
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _WorkoutRow({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final minutes = workout.durationSeconds ~/ 60;
    final detail = [
      '개인운동',
      workout.category.label,
      if (minutes > 0) '$minutes분',
      '${workout.totalSets}세트',
      '볼륨 ${NumberFormat('#,###').format(workout.totalVolume.round())}kg',
    ].join(' · ');

    return _MemberRow(
      name: workout.memberName,
      seed: workout.memberId,
      meta: detail,
      onTap: onTap,
      trailing: const Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
    );
  }
}

/// 아바타 + 이름(17) + 메타(13) + 오른쪽 요소. 아래 hairline.
class _MemberRow extends StatelessWidget {
  final String name;
  final String seed;
  final String meta;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MemberRow({
    required this.name,
    required this.seed,
    required this.meta,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
            child: Row(
              children: [
                AppAvatar(name: name, seed: seed),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(meta, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
              ],
            ),
          ),
        ),
        const AppRowDivider(),
      ],
    );
  }
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
