import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/admin_stats.dart';
import '../../models/pt_info.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_screen_header.dart';

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
    final monthLabel = DateFormat('M월').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.brand,
        backgroundColor: AppColors.card,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.screenH,
                    AppSpacing.screenH,
                    0,
                  ),
                  child: AppScreenHeader(
                    title: '대시보드',
                    subtitle: '센터 현황을 한눈에.',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brand,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_stats == null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _loadError ?? '데이터를 불러올 수 없습니다.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  120,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KpiRow(stats: _stats!),
                      const Gap(16),
                      _OperationInsightCard(stats: _stats!),
                      const Gap(16),
                      _TrainerBarChart(
                        trainerStats: _stats!.trainerStats,
                        monthLabel: monthLabel,
                      ),
                      const Gap(16),
                      _LowPtList(members: _stats!.lowPtMembers),
                      const Gap(16),
                      _ExpiringPtList(members: _stats!.expiringPtMembers),
                      const Gap(16),
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

// ── KPI 카드 2×2 그리드 ────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final AdminStats stats;

  const _KpiRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('M월').format(DateTime.now());

    final items = [
      _KpiData(label: '승인 회원', value: '${stats.memberCount}', suffix: '명'),
      _KpiData(label: '트레이너', value: '${stats.trainerCount}', suffix: '명'),
      _KpiData(
        label: '$monthLabel PT 완료',
        value: '${stats.monthlyCompletedSessions}',
        suffix: '회',
        highlight: true,
      ),
      _KpiData(
        label: '예정 세션',
        value: '${stats.upcomingSessionCount}',
        suffix: '건',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items.map((kpi) => _KpiCard(data: kpi)).toList(),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final String suffix;
  final bool highlight;

  const _KpiData({
    required this.label,
    required this.value,
    required this.suffix,
    this.highlight = false,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: data.highlight
            ? AppColors.brand.withValues(alpha: 0.08)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: data.highlight
              ? AppColors.brand.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data.label,
            style: AppTextStyles.caption.copyWith(
              color: data.highlight
                  ? AppColors.brand
                  : AppColors.textSecondary,
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: data.value,
                  style: AppTextStyles.h2.copyWith(
                    color: data.highlight
                        ? AppColors.brand
                        : AppColors.textPrimary,
                    fontSize: 28,
                  ),
                ),
                TextSpan(
                  text: ' ${data.suffix}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 운영 인사이트 ────────────────────────────────────────────────────────────

class _OperationInsightCard extends StatelessWidget {
  final AdminStats stats;

  const _OperationInsightCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = (stats.monthlyCompletionRate * 100).clamp(0, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '운영 인사이트',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: _MiniInsight(
                  label: '오늘 예정',
                  value: '${stats.todayScheduledSessions}건',
                  icon: Icons.event_available_rounded,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _MiniInsight(
                  label: '오늘 완료',
                  value: '${stats.todayCompletedSessions}건',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: stats.monthlyCompletionRate.clamp(0.0, 1.0),
                    color: AppColors.brand,
                    backgroundColor: AppColors.bg,
                  ),
                ),
              ),
              const Gap(12),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            '이번 달 PT 완료율',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniInsight({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand, size: 18),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(
                  value,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 트레이너별 PT 완료 바 차트 ─────────────────────────────────────────────────

class _TrainerBarChart extends StatelessWidget {
  final List<TrainerSessionStat> trainerStats;
  final String monthLabel;

  const _TrainerBarChart({
    required this.trainerStats,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthLabel 트레이너별 완료 세션',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(4),
          if (trainerStats.isEmpty) ...[
            const Gap(12),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '이번 달 완료된 세션이 없습니다.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              '완료 세션 수 기준 정렬',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY:
                      trainerStats
                          .map((t) => t.completedCount.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.3,
                  minY: 0,
                  barGroups: trainerStats.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.completedCount.toDouble(),
                          color: AppColors.brand,
                          width: trainerStats.length <= 3 ? 36 : 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= trainerStats.length) {
                            return const SizedBox.shrink();
                          }
                          final name = trainerStats[idx].trainerName;
                          final short = name.length > 3
                              ? name.substring(0, 3)
                              : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              short,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.bg,
                      getTooltipItem: (group, _, rod, __) {
                        final stat = trainerStats[group.x];
                        return BarTooltipItem(
                          '${stat.trainerName}\n${stat.completedCount}회',
                          AppTextStyles.label.copyWith(
                            color: AppColors.brand,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── PT 잔여 횟수 경고 리스트 ──────────────────────────────────────────────────

class _LowPtList extends StatelessWidget {
  final List<PtInfo> members;

  const _LowPtList({required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.diet,
              ),
              const Gap(6),
              Text(
                'PT 잔여 3회 이하',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${members.length}명',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(12),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '잔여 횟수 경고 대상이 없습니다.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...members.asMap().entries.map((e) {
              final info = e.value;
              final isLast = e.key == members.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.diet.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${info.remainingSessions}',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.diet,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.memberName,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '잔여 ${info.remainingSessions}회',
                                style: AppTextStyles.caption.copyWith(
                                  color: info.remainingSessions == 1
                                      ? AppColors.destructive
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (info.endDate != null)
                          Text(
                            '만료 ${DateFormat('MM/dd').format(info.endDate!)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: AppColors.border),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ── PT 만료 임박 리스트 ───────────────────────────────────────────────────────

class _ExpiringPtList extends StatelessWidget {
  final List<PtInfo> members;

  const _ExpiringPtList({required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 16,
                color: AppColors.destructive,
              ),
              const Gap(6),
              Text(
                'PT 만료 14일 이내',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${members.length}명',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(12),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '만료 임박 회원이 없습니다.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...members.asMap().entries.map((e) {
              final info = e.value;
              final isLast = e.key == members.length - 1;
              final endDate = info.endDate;
              final dDay = endDate
                  ?.difference(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  )
                  .inDays;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.destructive.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            dDay == null ? '-' : 'D-$dDay',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.destructive,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.memberName,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                endDate == null
                                    ? '만료일 없음'
                                    : '만료 ${DateFormat('yyyy.MM.dd').format(endDate)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '잔여 ${info.remainingSessions}회',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: AppColors.border),
                ],
              );
            }),
        ],
      ),
    );
  }
}
