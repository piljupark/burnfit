import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/admin_stats.dart';
import '../../models/pt_info.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/orb_loader.dart';
import '../../widgets/app_progress_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<UserProvider>().user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final stats = await FirestoreService.getAdminStats(user.centerId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loadError = null;
        });
      }
    } catch (e) {
      AppLogger.debug('[AdminDashboard] 관리자 대시보드 로드 실패: $e');
      if (mounted) {
        setState(() {
          _stats = null;
          _loadError = '데이터를 불러올 수 없습니다.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: '대시보드',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const AppRowDivider(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.ink,
                backgroundColor: AppColors.canvasCard,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_loading)
                      const SliverFillRemaining(hasScrollBody: false, child: AppLoadingView())
                    else if (stats == null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xl),
                          child: AppErrorCard(
                            message: _loadError ?? '데이터를 불러올 수 없습니다.',
                            onRetry: _load,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: AppSpacing.xl2 + MediaQuery.of(context).padding.bottom,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _CompletionHero(stats: stats),
                            AppStatStrip(
                              topBorder: true,
                              cells: [
                                AppKpiCard(
                                  framed: false,
                                  label: '오늘 예정',
                                  value: '${stats.todayScheduledSessions}',
                                  unit: '회',
                                ),
                                AppKpiCard(
                                  framed: false,
                                  label: '오늘 완료',
                                  value: '${stats.todayCompletedSessions}',
                                  unit: '회',
                                ),
                                AppKpiCard(
                                  framed: false,
                                  label: '승인 회원',
                                  value: '${stats.memberCount}',
                                  unit: '명',
                                ),
                              ],
                            ),
                            const AppMonthHeader(label: '트레이너', count: '완료 횟수'),
                            _TrainerBars(trainerStats: stats.trainerStats),
                            AppMonthHeader(label: 'PT 잔여 3회 이하', count: '${stats.lowPtMembers.length}'),
                            _LowPtList(members: stats.lowPtMembers),
                            AppMonthHeader(label: 'PT 만료 14일 이내', count: '${stats.expiringPtMembers.length}'),
                            _ExpiringPtList(members: stats.expiringPtMembers),
                          ],
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

// ── 이번 달 PT 완료율 ─────────────────────────────────────────────────────────

/// 모노 머리말 + 40 큰 숫자 + 캡션 + 2px 진행 막대.
class _CompletionHero extends StatelessWidget {
  final AdminStats stats;

  const _CompletionHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final ratio = stats.monthlyCompletionRate.clamp(0.0, 1.0);
    final percent = (ratio * 100).toStringAsFixed(0);
    final month = DateFormat('yyyy.MM').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
      child: Semantics(
        label: '이번 달 PT 완료율 $percent퍼센트, 완료 ${stats.monthlyCompletedSessions}회',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$month · PT 완료율', style: AppTextStyles.bodySm),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$percent%', style: AppTextStyles.displayLg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '이번 달 완료 ${stats.monthlyCompletedSessions}회',
                    style: AppTextStyles.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            AppProgressBar(value: ratio, height: 2),
          ],
        ),
      ),
    );
  }
}

// ── 트레이너별 완료 세션 (가로 막대) ──────────────────────────────────────────

class _TrainerBars extends StatelessWidget {
  final List<TrainerSessionStat> trainerStats;

  const _TrainerBars({required this.trainerStats});

  @override
  Widget build(BuildContext context) {
    if (trainerStats.isEmpty) {
      return const _EmptyLine('이번 달 완료된 세션이 없습니다.');
    }
    final maxCount = trainerStats.map((t) => t.completedCount).fold<int>(0, (a, b) => b > a ? b : a);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        children: [
          for (final stat in trainerStats)
            Semantics(
              label: '${stat.trainerName} ${stat.completedCount}회',
              excludeSemantics: true,
              child: SizedBox(
                height: AppSize.touchMin,
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        stat.trainerName,
                        style: AppTextStyles.bodyMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppProgressBar(
                        value: maxCount == 0 ? 0 : stat.completedCount / maxCount,
                        height: 4,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${stat.completedCount}',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.counter.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
    if (members.isEmpty) return const _EmptyLine('잔여 횟수 경고 대상이 없습니다.');
    return Column(
      children: [
        for (int i = 0; i < members.length; i++) ...[
          if (i > 0) const AppRowDivider(indent: AppSpacing.screenH),
          _CompactMemberRow(
            name: members[i].memberName,
            seed: members[i].memberId,
            meta: members[i].endDate == null
                ? '만료일 없음'
                : '${DateFormat('M월 d일').format(members[i].endDate!)} 만료',
            tag: AppTag('${members[i].remainingSessions}회 남음', strong: members[i].remainingSessions <= 1),
          ),
        ],
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
    if (members.isEmpty) return const _EmptyLine('만료 임박 회원이 없습니다.');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      children: [
        for (int i = 0; i < members.length; i++) ...[
          if (i > 0) const AppRowDivider(indent: AppSpacing.screenH),
          Builder(builder: (_) {
            final info = members[i];
            final endDate = info.endDate;
            final dDay = endDate?.difference(today).inDays;
            return _CompactMemberRow(
              name: info.memberName,
              seed: info.memberId,
              meta: endDate == null
                  ? '만료일 없음 · 잔여 ${info.remainingSessions}회'
                  : '${DateFormat('M월 d일').format(endDate)} 만료 · 잔여 ${info.remainingSessions}회',
              tag: dDay == null ? null : AppTag('D-$dDay', strong: dDay <= 7),
            );
          }),
        ],
      ],
    );
  }
}

/// 대시보드용 짧은 회원 줄: 32 아바타 + 이름 + 보조 줄 + 오른쪽 태그.
class _CompactMemberRow extends StatelessWidget {
  final String name;
  final String seed;
  final String meta;
  final Widget? tag;

  const _CompactMemberRow({required this.name, required this.seed, required this.meta, this.tag});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
        child: Row(
          children: [
            AppAvatar(name: name, seed: seed, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(meta, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (tag != null) ...[const SizedBox(width: AppSpacing.sm), tag!],
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
      child: Text(text, style: AppTextStyles.bodySm),
    );
  }
}
