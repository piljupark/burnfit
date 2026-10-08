import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../models/workout_stats.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_progress_bar.dart';

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
    final Widget body;
    if (_loading) {
      body = const AppLoadingView();
    } else if (_stats == null || _stats!.isEmpty) {
      body = ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        children: [
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xl3),
            AppErrorCard(message: _errorMessage!, onRetry: _load),
          ] else
            const AppEmptyState(
              icon: AppIcons.chartBar,
              message: '아직 운동 기록이 없어요',
              description: '운동을 기록하면 여기서 통계를 확인할 수 있어요.',
            ),
        ],
      );
    } else {
      final stats = _stats!;
      body = ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSize.navClearance),
        children: [
          _SummaryStrip(stats: stats),
          _InsightGrid(stats: stats),
          AppMonthHeader(label: '일별 볼륨', count: '단위 kg'),
          _VolumeBarChart(stats: stats, period: _period),
          AppMonthHeader(label: '부위별 세트', count: '${stats.totalSets}'),
          _CategoryBreakdown(stats: stats),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '운동 통계',
              subtitle: '나의 운동 현황을 한눈에',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: AppFilterTabs(
                tabs: const ['이번 주', '이번 달'],
                selectedIndex: _period == _Period.weekly ? 0 : 1,
                onChanged: (index) {
                  final next = index == 0 ? _Period.weekly : _Period.monthly;
                  if (next == _period) return;
                  setState(() => _period = next);
                  _load();
                },
              ),
            ),
            const AppRowDivider(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

String _volumeText(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}t';
  return '${value.toStringAsFixed(0)}kg';
}

/// 축 라벨용 짧은 숫자: 1200 → 1.2K
String _compactNumber(double value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(0);
}

const _weekdayCodes = ['월', '화', '수', '목', '금', '토', '일'];

// ── 요약 숫자 줄 ─────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final WorkoutStats stats;

  const _SummaryStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final volume = _volumeText(stats.totalVolume);
    final volumeValue = volume.replaceAll(RegExp(r'[a-z]+$'), '');
    final volumeUnit = volume.substring(volumeValue.length);

    return AppStatStrip(
      cells: [
        AppKpiCard(
          framed: false,
          label: '운동 일수',
          value: '${stats.totalWorkoutDays}',
          unit: '일',
        ),
        AppKpiCard(
          framed: false,
          label: '총 볼륨',
          value: volumeValue,
          unit: volumeUnit,
        ),
        AppKpiCard(
          framed: false,
          label: '총 세트',
          value: '${stats.totalSets}',
          unit: '세트',
        ),
      ],
    );
  }
}

// ── 보조 숫자 격자 ───────────────────────────────────────────────────────────

class _InsightGrid extends StatelessWidget {
  final WorkoutStats stats;

  const _InsightGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bestDay = stats.bestVolumeDay;
    final bestDate = bestDay == null
        ? null
        : DateFormat('MM.dd').format(DateTime.parse(bestDay.date));

    return AppStatGrid(
      cells: [
        AppKpiCard(
          framed: false,
          valueSize: 20,
          label: '최근 연속',
          value: '${stats.activeStreakDays}',
          unit: '일',
        ),
        AppKpiCard(
          framed: false,
          valueSize: 20,
          label: '운동 횟수',
          value: '${stats.totalSessions}',
          unit: '회',
        ),
        AppKpiCard(
          framed: false,
          valueSize: 20,
          label: '회당 평균',
          value: _volumeText(stats.avgVolumePerSession),
          unit: '',
        ),
        AppKpiCard(
          framed: false,
          valueSize: 20,
          label: '최고 볼륨일',
          value: bestDay == null ? '-' : _volumeText(bestDay.volume),
          unit: '',
          trend: bestDate,
        ),
      ],
    );
  }
}

// ── 일별 볼륨 막대 ───────────────────────────────────────────────────────────

/// 막대 = canvasMid 트랙 위 ink 채움, 격자 hairline, 축 라벨 counter.
class _VolumeBarChart extends StatelessWidget {
  final WorkoutStats stats;
  final _Period period;

  const _VolumeBarChart({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final days = stats.dailyVolumes;
    final peak = days.isEmpty
        ? 0.0
        : days.map((d) => d.volume).reduce((a, b) => a > b ? a : b);
    final maxY = peak <= 0 ? 100.0 : peak * 1.25;
    final barWidth = period == _Period.weekly ? 16.0 : 6.0;
    final axisStyle = AppTextStyles.counter.copyWith(fontSize: 10);

    final groups = [
      for (var i = 0; i < days.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: days[i].volume,
              color: AppColors.ink,
              width: barWidth,
              borderRadius: BorderRadius.circular(barWidth / 2),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: AppColors.canvasMid,
              ),
            ),
          ],
        ),
    ];

    final summary = days.isEmpty
        ? '기록 없음'
        : '${days.length}일 기록, 최고 ${_volumeText(peak)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('무게 × 반복 횟수 합계', style: AppTextStyles.bodySm),
          const SizedBox(height: AppSpacing.base),
          Semantics(
            label: '일별 볼륨 막대 차트: $summary',
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  barGroups: groups,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.hairline, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(_compactNumber(value), style: axisStyle);
                        },
                      ),
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
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime.parse(days[idx].date);
                          if (period == _Period.monthly &&
                              days.length > 8 &&
                              date.day != 1 &&
                              date.day % 5 != 0) {
                            return const SizedBox.shrink();
                          }
                          final label = period == _Period.weekly
                              ? _weekdayCodes[(date.weekday - 1) % 7]
                              : date.day.toString().padLeft(2, '0');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label, style: axisStyle),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.canvasCard,
                      tooltipBorder: BorderSide(color: AppColors.hairline),
                      tooltipRoundedRadius: AppRadius.card,
                      getTooltipItem: (group, _, rod, __) {
                        final date = DateTime.parse(days[group.x].date);
                        return BarTooltipItem(
                          '${DateFormat('MM.dd').format(date)}  ${NumberFormat('#,###').format(rod.toY.round())}kg',
                          AppTextStyles.counter.copyWith(color: AppColors.ink),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 부위별 세트: 도넛 + 줄 목록 ─────────────────────────────────────────────

/// 도넛 조각은 chartSeries 색, 각 줄에 같은 색 표시 + 이름 + 세트 수 + 비율 + 4px 막대를 함께 둔다
/// (색만으로 구분하지 않는다). 조각을 누르면 가운데에 부위·비율이 나온다.
class _CategoryBreakdown extends StatefulWidget {
  final WorkoutStats stats;

  const _CategoryBreakdown({required this.stats});

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  int? _touchedIndex;

  Color _colorAt(int i) =>
      AppColors.chartSeries[i % AppColors.chartSeries.length];

  @override
  Widget build(BuildContext context) {
    final entries = widget.stats.categorySetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (entries.isEmpty || total == 0) return const SizedBox.shrink();

    final touched =
        _touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < entries.length
        ? entries[_touchedIndex!]
        : null;

    final sections = [
      for (var i = 0; i < entries.length; i++)
        PieChartSectionData(
          value: entries[i].value.toDouble(),
          color: _colorAt(i),
          radius: _touchedIndex == i ? 22 : 16,
          title: '',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              '부위별 세트 분포: ${entries.map((e) => '${e.key.label} ${(e.value / total * 100).toStringAsFixed(0)}%').join(', ')}',
          child: SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 64,
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
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: touched == null
                        ? [
                            Text('$total', style: AppTextStyles.displayMd),
                            Text('세트', style: AppTextStyles.captionSmall),
                          ]
                        : [
                            Text(
                              '${(touched.value / total * 100).toStringAsFixed(0)}%',
                              style: AppTextStyles.displayMd,
                            ),
                            Text(
                              touched.key.label,
                              style: AppTextStyles.bodySm,
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        const AppRowDivider(),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const AppRowDivider(indent: AppSpacing.screenH),
          _CategoryRow(
            color: _colorAt(i),
            category: entries[i].key,
            count: entries[i].value,
            percent: entries[i].value / total,
          ),
        ],
        const AppRowDivider(),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Color color;
  final WorkoutCategory category;
  final int count;
  final double percent;

  const _CategoryRow({
    required this.color,
    required this.category,
    required this.count,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).toStringAsFixed(0);
    return Semantics(
      label: '${category.label} $count세트, $pct퍼센트',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 도넛 조각과 같은 색 표시 (차트 범례)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(category.label, style: AppTextStyles.bodyMd),
                ),
                Text('$count세트', style: AppTextStyles.bodySm),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.end,
                    style: AppTextStyles.counter.copyWith(
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(value: percent, height: 4),
          ],
        ),
      ),
    );
  }
}
