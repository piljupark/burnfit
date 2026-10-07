import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info.dart';
import '../../models/pt_session.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/orb_loader.dart';
import '../../widgets/app_progress_bar.dart';
import 'member_pt_workout_screen.dart';

class MemberPtScheduleScreen extends StatefulWidget {
  final bool showBackButton;

  const MemberPtScheduleScreen({super.key, this.showBackButton = true});

  @override
  State<MemberPtScheduleScreen> createState() => MemberPtScheduleScreenState();
}

class MemberPtScheduleScreenState extends State<MemberPtScheduleScreen> {
  PtInfo? _ptInfo;
  List<PtSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 알림 등으로 탭에 들어올 때 최신 일정을 다시 불러온다.
  void refresh() => _load();

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        FirestoreService.getPtInfo(user.uid, centerId: user.centerId),
        FirestoreService.getPtSessionsByMember(
          user.uid,
          centerId: user.centerId,
          from: now.subtract(const Duration(days: 90)),
          to: now.add(const Duration(days: 180)),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _ptInfo = results[0] as PtInfo?;
        _sessions =
            (results[1] as List<PtSession>)
                .where((item) => item.status != PtSessionStatus.cancelled)
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// '예정' = 아직 진행 중이거나 다가올 예약 세션 (끝나기 전까지). 그 밖은 모두 '지난 일정'.
  /// 같은 세션이 두 목록에 동시에 나오지 않도록 한 기준으로 나눈다.
  bool _isUpcoming(PtSession item, DateTime now) =>
      item.status == PtSessionStatus.scheduled &&
      item.scheduledAt
          .add(Duration(minutes: item.durationMinutes))
          .isAfter(now);

  List<PtSession> get _upcoming {
    final now = DateTime.now();
    return _sessions.where((item) => _isUpcoming(item, now)).toList();
  }

  List<PtSession> get _past {
    final now = DateTime.now();
    return _sessions
        .where(
          (item) =>
              !_isUpcoming(item, now) &&
              // 취소된 일정은 날짜가 지난 것만 기록으로 남긴다.
              (item.status != PtSessionStatus.cancelled ||
                  item.scheduledAt.isBefore(now)),
        )
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  @override
  Widget build(BuildContext context) {
    final trainerName = context.watch<UserProvider>().user?.trainerName;
    final upcoming = _upcoming;
    final past = _past;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.ink,
          backgroundColor: AppColors.canvasCard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: widget.showBackButton
                    ? AppScreenHeader(
                        title: 'PT 일정',
                        onBack: () => Navigator.of(context).pop(),
                      )
                    : AppHero(title: 'PT 일정'),
              ),
              if (widget.showBackButton)
                const SliverToBoxAdapter(child: AppRowDivider()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    0,
                  ),
                  child: _RemainingCard(
                    info: _ptInfo,
                    trainerName: trainerName,
                  ),
                ),
              ),
              // 트레이너가 남긴 PT 운동 기록 (세트·무게·메모)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    children: [
                      const AppRowDivider(),
                      AppActionRow(
                        icon: AppIcons.workout,
                        label: 'PT 운동 기록',
                        subtitle: '트레이너가 남긴 세트·무게·메모',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MemberPtWorkoutScreen(),
                          ),
                        ),
                      ),
                      const AppRowDivider(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                    child: Center(
                      child: OrbLoader(semanticLabel: 'PT 일정 불러오는 중'),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xl,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: AppErrorCard(
                      message: _errorMessage!,
                      onRetry: _load,
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: AppMonthHeader(
                    label: '예정',
                    count: '${upcoming.length}',
                  ),
                ),
                if (upcoming.isEmpty)
                  const SliverToBoxAdapter(
                    child: _EmptyLine('예정된 PT 일정이 없습니다.'),
                  )
                else
                  SliverList.separated(
                    itemCount: upcoming.length,
                    separatorBuilder: (_, _) =>
                        const AppRowDivider(indent: AppSpacing.screenH),
                    itemBuilder: (_, i) =>
                        _SessionRow(session: upcoming[i], isPast: false),
                  ),
                SliverToBoxAdapter(
                  child: AppMonthHeader(
                    label: '지난 일정',
                    count: '${past.length}',
                  ),
                ),
                if (past.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyLine('지난 PT 일정이 없습니다.'))
                else
                  SliverList.separated(
                    itemCount: past.length,
                    separatorBuilder: (_, _) =>
                        const AppRowDivider(indent: AppSpacing.screenH),
                    itemBuilder: (_, i) =>
                        _SessionRow(session: past[i], isPast: true),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 잔여 횟수 카드: 모노 머리말 + 큰 숫자 + 2px 진행 막대 + 트레이너·갱신일 + D-N.
class _RemainingCard extends StatelessWidget {
  final PtInfo? info;
  final String? trainerName;

  const _RemainingCard({required this.info, required this.trainerName});

  @override
  Widget build(BuildContext context) {
    final renewalDate = info?.renewalDate;
    final remaining = info?.remainingSessions ?? 0;
    final total = info?.totalSessions ?? 0;
    final ratio = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;

    String? dDay;
    if (renewalDate != null) {
      final today = DateUtils.dateOnly(DateTime.now());
      final days = DateUtils.dateOnly(renewalDate).difference(today).inDays;
      dDay = days == 0 ? '오늘' : (days > 0 ? 'D-$days' : 'D+${-days}');
    }

    final metaParts = [
      if ((trainerName ?? '').trim().isNotEmpty) '${trainerName!.trim()} 트레이너',
      '갱신일 ${renewalDate == null ? '-' : DateFormat('M월 d일', 'ko').format(renewalDate)}',
    ];

    return Semantics(
      container: true,
      label: 'PT 잔여 $remaining회, 전체 $total회',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '남은 횟수',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  ),
                ),
                if (dDay != null) AppTag(dDay),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$remaining', style: AppTextStyles.displayLg),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '/ $total회 남음',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(value: ratio, semanticLabel: 'PT 잔여 비율'),
            const SizedBox(height: AppSpacing.md),
            Text(
              metaParts.join(' · '),
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일정 한 줄: 모노 날짜 칸(10.09 / 목) + 제목 + 시간 메타 + 상태 태그.
class _SessionRow extends StatelessWidget {
  final PtSession session;
  final bool isPast;

  const _SessionRow({required this.session, required this.isPast});

  static const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final start = session.scheduledAt;
    final end = start.add(Duration(minutes: session.durationMinutes));
    final cancelled = session.status == PtSessionStatus.cancelled;
    final completed = session.status == PtSessionStatus.completed;
    final timeFmt = DateFormat('HH:mm');
    final trainer = session.trainerName.trim();

    final meta = cancelled
        ? '취소됨'
        : [
            '${timeFmt.format(start)} – ${timeFmt.format(end)}',
            if (trainer.isNotEmpty) trainer,
          ].join(' · ');

    final Widget tag;
    if (!isPast) {
      final days = DateUtils.dateOnly(
        start,
      ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
      tag = AppTag(days <= 0 ? '오늘' : 'D-$days');
    } else if (completed) {
      tag = const AppTag('완료', strong: true);
    } else if (cancelled) {
      tag = const AppTag('취소', muted: true);
    } else {
      tag = const AppTag('기록 전', muted: true);
    }

    final semanticDate = DateFormat('M월 d일 E요일 a h시 mm분', 'ko').format(start);

    return Semantics(
      container: true,
      label: '$semanticDate PT 세션',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MM.dd').format(start),
                      style: AppTextStyles.eyebrow.copyWith(
                        color: cancelled ? AppColors.mute : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _weekdayKo[start.weekday - 1],
                      style: AppTextStyles.counter,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PT 세션',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: cancelled ? AppColors.mute : AppColors.ink,
                    ),
                  ),
                  Text(
                    meta,
                    style: AppTextStyles.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            tag,
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      child: Text(text, style: AppTextStyles.bodySm),
    );
  }
}
