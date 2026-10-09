import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/admin_stats.dart';
import '../../models/pt_info.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_charts.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

/// 대시보드 (기준 시안 AdminDashboard): 제목 오른쪽 '‹ 10월 ›' → 완료율 고리 카드 →
/// 주별 PT(완료 기준) → 트레이너별 → (지금 기준) PT 잔여 3회 이하 · PT 만료 14일 이내.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// 뒤로 볼 수 있는 달 수 (지금 달 포함 24개월)
  static const _monthsBack = 23;

  AdminStats? _stats;
  bool _loading = true;
  String? _loadError;
  late DateTime _month = _thisMonth;

  /// 마지막으로 요청한 달 — 빨리 넘기다 늦게 온 응답이 화면을 덮지 않게 한다.
  int _requestId = 0;

  static DateTime get _thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _isThisMonth => _month == _thisMonth;

  bool get _canGoBack {
    final t = _thisMonth;
    return _month.isAfter(DateTime(t.year, t.month - _monthsBack));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final user = context.read<UserProvider>().user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final stats = await FirestoreService.getAdminStats(
        user.centerId,
        month: _month,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _stats = stats;
        _loadError = null;
      });
    } catch (e) {
      AppLogger.debug('[AdminDashboard] 관리자 대시보드 로드 실패: $e');
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _stats = null;
        _loadError = '데이터를 불러올 수 없습니다.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: '대시보드',
              bold: true,
              onBack: () => Navigator.of(context).pop(),
              titleTrailing: _MonthSwitcher(
                month: _month,
                onPrev: _canGoBack ? () => _moveMonth(-1) : null,
                onNext: _isThisMonth ? null : () => _moveMonth(1),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.ink,
                backgroundColor: AppColors.canvasCard,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppLoadingView(),
                      )
                    else if (stats == null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: AppErrorCard(
                            message: _loadError ?? '데이터를 불러올 수 없습니다.',
                            onRetry: _load,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom:
                              AppSpacing.xl2 +
                              MediaQuery.of(context).padding.bottom,
                        ),
                        sliver: SliverList.list(children: _content(stats)),
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

  List<Widget> _content(AdminStats stats) {
    final weeks = stats.weeklyCompleted;
    final now = DateTime.now();
    // 이번 달이면 오늘이 든 주를 주황으로
    final firstOffset = stats.month.weekday - DateTime.monday;
    final currentWeek = _isThisMonth ? (now.day + firstOffset - 1) ~/ 7 : null;
    final maxTrainer = stats.trainerStats.isEmpty
        ? 0
        : stats.trainerStats.first.completedCount;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.base,
          AppSpacing.screenH,
          0,
        ),
        child: _CompletionCard(stats: stats),
      ),

      // ── 주별 PT (완료 기준) ──────────────────────────────────────────
      AppMonthHeader(
        label: '주별 PT',
        bold: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.xl,
          AppSpacing.screenH,
          0,
        ),
        trailing: Text('완료 기준', style: AppTextStyles.bodySm),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          0,
        ),
        child: AppColumnChart(
          bold: true,
          labels: [for (var i = 0; i < weeks.length; i++) '${i + 1}주'],
          values: weeks,
          highlightIndex: currentWeek,
        ),
      ),

      // ── 트레이너별 ───────────────────────────────────────────────────
      AppMonthHeader(
        label: '트레이너별',
        bold: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          28,
          AppSpacing.screenH,
          AppSpacing.xs,
        ),
      ),
      if (stats.trainerStats.isEmpty)
        const AppEmptyLine('이 달에 완료된 수업이 없습니다.')
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            children: [
              for (var i = 0; i < stats.trainerStats.length; i++)
                AppRankBar(
                  bold: true,
                  label: stats.trainerStats[i].trainerName,
                  value: '${stats.trainerStats[i].completedCount}',
                  unit: '회',
                  ratio: maxTrainer == 0
                      ? 0
                      : stats.trainerStats[i].completedCount / maxTrainer,
                  delay: Duration(milliseconds: 200 + 80 * i),
                ),
            ],
          ),
        ),

      // ── 지금 기준: 갱신이 필요한 회원 ────────────────────────────────
      const AppSectionBand(top: AppSpacing.base),
      AppMonthHeader(
        label: 'PT 잔여 3회 이하',
        bold: true,
        count: '${stats.lowPtMembers.length}',
        unit: '명',
      ),
      _LowPtList(members: stats.lowPtMembers),
      const AppSectionBand(top: AppSpacing.base),
      AppMonthHeader(
        label: 'PT 만료 14일 이내',
        bold: true,
        count: '${stats.expiringPtMembers.length}',
        unit: '명',
      ),
      _ExpiringPtList(members: stats.expiringPtMembers),
    ];
  }
}

/// 제목 오른쪽 '‹ 10월 ›' (기준 시안 AdminDashboard): 화살표 칸 36×44 · 16 Bold, 가운데 달 16 Bold.
class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _MonthSwitcher({required this.month, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 올해가 아니면 연도까지 (예: '2025년 12월')
    final label = month.year == now.year
        ? DateFormat('M월').format(month)
        : DateFormat('yyyy년 M월').format(month);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavArrow(
          icon: AppIcons.chevronLeftBold,
          label: '이전 달',
          width: 36,
          onTap: onPrev,
        ),
        Semantics(
          liveRegion: true,
          child: Text(label, style: AppTextStyles.input.bold),
        ),
        AppNavArrow(
          icon: AppIcons.chevronRightBold,
          label: '다음 달',
          width: 36,
          onTap: onNext,
        ),
      ],
    );
  }
}

/// 완료율 카드 (기준 시안 AdminDashboard): 회색 카드(반경 20 · 안쪽 22 20) 안에
/// 고리 112 + 'PT 완료율' 14 mute / (4) '342회 / 371회' 20 Bold / (6) '취소 18 · 남음 29' 13 mute.
/// 완료율은 취소를 빼고 센다 (완료 / (완료 + 남은 예약)).
class _CompletionCard extends StatelessWidget {
  final AdminStats stats;

  const _CompletionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final ratio = stats.monthlyCompletionRate.clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final done = stats.monthlyCompletedSessions;
    final total = done + stats.monthlyScheduledSessions;
    final valueStyle = AppTextStyles.title.bold.natural;

    return Semantics(
      label:
          'PT 완료율 $percent퍼센트, 완료 $done회 / 전체 $total회, '
          '취소 ${stats.monthlyCancelledSessions}회, 남음 ${stats.monthlyScheduledSessions}회',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 22,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            AppRing(value: ratio, label: '$percent%', bold: true),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PT 완료율', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: AppSpacing.xs),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$done회'),
                        TextSpan(
                          text: ' / $total회',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                    style: valueStyle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '취소 ${stats.monthlyCancelledSessions} · 남음 ${stats.monthlyScheduledSessions}',
                    style: AppTextStyles.bodySm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PT 잔여 3회 이하 ──────────────────────────────────────────────────────────

class _LowPtList extends StatelessWidget {
  final List<PtInfo> members;

  const _LowPtList({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const AppEmptyLine('잔여 횟수 경고 대상이 없습니다.');
    return Column(
      children: [
        for (final info in members)
          _MemberRow(
            name: info.memberName,
            meta: info.endDate == null
                ? '만료일 없음'
                : '${DateFormat('M월 d일').format(info.endDate!)} 만료',
            status: '${info.remainingSessions}회 남음',
            urgent: info.remainingSessions <= 1,
          ),
      ],
    );
  }
}

// ── PT 만료 14일 이내 ─────────────────────────────────────────────────────────

class _ExpiringPtList extends StatelessWidget {
  final List<PtInfo> members;

  const _ExpiringPtList({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const AppEmptyLine('만료 임박 회원이 없습니다.');
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      children: [
        for (final info in members)
          Builder(
            builder: (_) {
              final endDate = info.endDate;
              final dDay = endDate == null
                  ? null
                  : DateUtils.dateOnly(endDate).difference(today).inDays;
              return _MemberRow(
                name: info.memberName,
                meta: endDate == null
                    ? '만료일 없음 · 잔여 ${info.remainingSessions}회'
                    : '${DateFormat('M월 d일').format(endDate)} 만료 · 잔여 ${info.remainingSessions}회',
                status: dDay == null
                    ? null
                    : dDay == 0
                    ? '오늘 만료'
                    : 'D-$dDay',
                urgent: dDay != null && dDay <= 7,
              );
            },
          ),
      ],
    );
  }
}

/// 갱신 대상 회원 줄 (시안 Ad-Dashboard): 64 · 이름 16/500 · 보조 13 mute ·
/// 오른쪽 상태 글자 15 (급하면 500 noticeText, 아니면 400 body).
class _MemberRow extends StatelessWidget {
  final String name;
  final String meta;
  final String? status;
  final bool urgent;

  const _MemberRow({
    required this.name,
    required this.meta,
    this.status,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: name,
      subtitle: meta,
      height: 64,
      bold: true,
      trailing: status == null
          ? null
          : Text(
              status!,
              style: urgent
                  ? AppTextStyles.bodyMd.bold.copyWith(
                      color: AppColors.noticeText,
                    )
                  : AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
    );
  }
}
