import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../models/workout_stats.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

class MemberWorkoutStatsScreen extends StatefulWidget {
  const MemberWorkoutStatsScreen({super.key});

  @override
  State<MemberWorkoutStatsScreen> createState() =>
      _MemberWorkoutStatsScreenState();
}

enum _Period { weekly, monthly }

class _MemberWorkoutStatsScreenState extends State<MemberWorkoutStatsScreen> {
  _Period _period = _Period.weekly;
  WorkoutStats? _stats;
  bool _loading = true;
  String? _errorMessage;

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

    final now = DateTime.now();
    final String startDate;
    final String endDate;

    if (_period == _Period.weekly) {
      final start = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(start.year, start.month, start.day));
      endDate = DateFormat('yyyy-MM-dd').format(now);
    } else {
      startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month, 1));
      endDate = DateFormat('yyyy-MM-dd').format(now);
    }

    try {
      final stats = await WorkoutService.getWorkoutStats(
        user.centerId,
        user.uid,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _errorMessage = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppFeedback.errorMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppScreenHeader(
                      title: '운동 통계',
                      subtitle: '나의 운동 현황을 한눈에.',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const Gap(20),
                    _PeriodTab(
                      period: _period,
                      onChanged: (p) {
                        setState(() => _period = p);
                        _load();
                      },
                    ),
                    const Gap(20),
                  ],
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
          else if (_stats == null || _stats!.isEmpty)
            SliverFillRemaining(
              child: _errorMessage != null
                  ? AppErrorCard(message: _errorMessage!, onRetry: _load)
                  : const AppEmptyState(
                      icon: Icons.bar_chart_rounded,
                      message: '아직 운동 기록이 없어요\n운동을 기록하면 여기서 통계를 확인할 수 있어요.',
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 0, AppSpacing.screenH, 120,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _SummaryRow(stats: _stats!),
                    const Gap(16),
                    _InsightGrid(stats: _stats!),
                    const Gap(16),
                    _VolumeBarChart(stats: _stats!, period: _period),
                    const Gap(16),
                    _CategoryDonutChart(stats: _stats!),
                    const Gap(16),
                    _CategoryDetailList(stats: _stats!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 기간 탭 ───────────────────────────────────────────────────────────────────

class _PeriodTab extends StatelessWidget {
  final _Period period;
  final ValueChanged<_Period> onChanged;

  const _PeriodTab({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _Tab(
            label: '이번 주',
            selected: period == _Period.weekly,
            onTap: () => onChanged(_Period.weekly),
          ),
          _Tab(
            label: '이번 달',
            selected: period == _Period.monthly,
            onTap: () => onChanged(_Period.monthly),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected
                  ? AppColors.textOnAccent
                  : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 요약 카드 행 ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final WorkoutStats stats;

  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final volStr = stats.totalVolume >= 1000
        ? '${(stats.totalVolume / 1000).toStringAsFixed(1)}t'
        : '${stats.totalVolume.toStringAsFixed(0)}kg';

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: '운동 일수',
            value: '${stats.totalWorkoutDays}',
            suffix: '일',
          ),
        ),
        const Gap(10),
        Expanded(
          child: _MetricCard(label: '총 볼륨', value: volStr, suffix: null),
        ),
        const Gap(10),
        Expanded(
          child: _MetricCard(
            label: '총 세트',
            value: '${stats.totalSets}',
            suffix: '세트',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.numberLarge.copyWith(
                  color: AppColors.brand,
                  fontSize: 28,
                ),
              ),
              if (suffix != null) ...[
                const Gap(3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    suffix!,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── 인사이트 카드 ────────────────────────────────────────────────────────────

class _InsightGrid extends StatelessWidget {
  final WorkoutStats stats;

  const _InsightGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bestDay = stats.bestVolumeDay;
    final bestDate = bestDay == null
        ? '-'
        : DateFormat('M/d', 'ko').format(DateTime.parse(bestDay.date));
    final bestVolume = bestDay == null ? '-' : _volumeText(bestDay.volume);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.local_fire_department_rounded,
                label: '최근 연속',
                value: '${stats.activeStreakDays}',
                suffix: '일',
              ),
            ),
            const Gap(10),
            Expanded(
              child: _InsightCard(
                icon: Icons.fitness_center_rounded,
                label: '운동 횟수',
                value: '${stats.totalSessions}',
                suffix: '회',
              ),
            ),
          ],
        ),
        const Gap(10),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.trending_up_rounded,
                label: '회당 평균',
                value: _volumeText(stats.avgVolumePerSession),
                suffix: null,
              ),
            ),
            const Gap(10),
            Expanded(
              child: _InsightCard(
                icon: Icons.emoji_events_rounded,
                label: '최고 볼륨일',
                value: bestVolume,
                suffix: bestDate == '-' ? null : ' · $bestDate',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _volumeText(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}t';
    return '${value.toStringAsFixed(0)}kg';
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.workout.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.workout, size: 20),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(4),
                Text(
                  suffix == null ? value : '$value$suffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
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

// ── 볼륨 바 차트 ──────────────────────────────────────────────────────────────

class _VolumeBarChart extends StatelessWidget {
  final WorkoutStats stats;
  final _Period period;

  const _VolumeBarChart({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final days = stats.dailyVolumes;
    final maxY = days.isEmpty
        ? 100.0
        : days.map((d) => d.volume).reduce((a, b) => a > b ? a : b) * 1.25;

    final groups = days.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d.volume,
            color: AppColors.brand,
            width: period == _Period.weekly ? 28 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '일별 볼륨',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '무게 × 반복 횟수 합계 (kg)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barGroups: groups,
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
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(days[idx].date);
                        final label = period == _Period.weekly
                            ? _weekdayLabel(date.weekday)
                            : '${date.day}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
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
                    getTooltipColor: (_) => AppColors.card,
                    getTooltipItem: (group, _, rod, __) {
                      final vol = rod.toY;
                      final label = vol >= 1000
                          ? '${(vol / 1000).toStringAsFixed(1)}t'
                          : '${vol.toStringAsFixed(0)}kg';
                      return BarTooltipItem(
                        label,
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
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[(weekday - 1) % 7];
  }
}

// ── 카테고리 도넛 차트 ────────────────────────────────────────────────────────

class _CategoryDonutChart extends StatefulWidget {
  final WorkoutStats stats;

  const _CategoryDonutChart({required this.stats});

  @override
  State<_CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<_CategoryDonutChart> {
  int? _touchedIndex;

  static const List<Color> _palette = [
    Color(0xFFFAFF69), // primary (yellow)
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFEF4444), // red
    Color(0xFFA855F7), // purple
    Color(0xFFF97316), // orange
    Color(0xFF14B8A6), // teal
  ];

  @override
  Widget build(BuildContext context) {
    final catMap = widget.stats.categorySetCounts;
    if (catMap.isEmpty) return const SizedBox.shrink();

    final entries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (sum, e) => sum + e.value);

    final sections = entries.asMap().entries.map((e) {
      final i = e.key;
      final count = e.value.value;
      final isTouched = _touchedIndex == i;
      final pct = total > 0 ? count / total * 100 : 0.0;

      return PieChartSectionData(
        value: count.toDouble(),
        color: _palette[i % _palette.length],
        radius: isTouched ? 64 : 56,
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: AppTextStyles.label.copyWith(
          color: AppColors.textOnAccent,
          fontSize: 11,
        ),
        borderSide: isTouched
            ? const BorderSide(color: AppColors.textPrimary, width: 1.5)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '부위별 세트 분포',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '탭해서 비율을 확인하세요',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(20),
          Row(
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 44,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const Gap(20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.asMap().entries.map((e) {
                    final i = e.key;
                    final cat = e.value.key;
                    final count = e.value.value;
                    final pct = total > 0 ? count / total * 100 : 0.0;
                    final color = _palette[i % _palette.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              cat.label,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryDetailList extends StatelessWidget {
  final WorkoutStats stats;

  const _CategoryDetailList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.categorySetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSets = stats.totalSets;
    if (entries.isEmpty || totalSets == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '부위별 세트 상세',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(14),
          for (final entry in entries) ...[
            _CategoryProgressRow(
              category: entry.key,
              count: entry.value,
              percent: entry.value / totalSets,
            ),
            const Gap(12),
          ],
        ],
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  final WorkoutCategory category;
  final int count;
  final double percent;

  const _CategoryProgressRow({
    required this.category,
    required this.count,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count세트 · ${(percent * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Gap(6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: percent.clamp(0.0, 1.0),
            color: color,
            backgroundColor: AppColors.bg,
          ),
        ),
      ],
    );
  }

  Color _colorFor(WorkoutCategory category) {
    return switch (category) {
      WorkoutCategory.shoulder => const Color(0xFFA855F7),
      WorkoutCategory.chest => AppColors.categoryUpper,
      WorkoutCategory.back => AppColors.categoryLower,
      WorkoutCategory.lower => AppColors.categoryCore,
      WorkoutCategory.arms => const Color(0xFFF97316),
      WorkoutCategory.abs => const Color(0xFF14B8A6),
      WorkoutCategory.cardio => AppColors.categoryCardio,
    };
  }
}

