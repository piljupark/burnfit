import 'dart:math' as math;

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
import '../../widgets/app_hero.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_progress_bar.dart';

/// 운동 통계 (시안 MemA-Stats · Stats-Monthly · Stats-Empty).
/// 가운데 17 머리 + 보조 12 → 이번 주/이번 달 나눔 버튼 → 숫자 칸 3 + 보조 칸 4 →
/// (띠) 일별 볼륨 막대 → (띠) 부위별 세트 도넛 + 범례 줄.
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
        children: [
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xl3),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: AppErrorCard(message: _errorMessage!, onRetry: _load),
            ),
          ] else
            const AppEmptyState(
              icon: AppIcons.chartBar,
              card: true,
              margin: EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xl4,
                AppSpacing.screenH,
                0,
              ),
              illustration: _EmptyBars(),
              message: '아직 운동 기록이 없어요',
              description: '운동을 기록하면 여기서 통계를 확인할 수 있어요.',
            ),
        ],
      );
    } else {
      final stats = _stats!;
      final weekly = _period == _Period.weekly;
      body = ListView(
        // 기간을 바꾸면 움직임을 처음부터 다시 보여 준다
        key: ValueKey(_period),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl3),
        children: [
          const SizedBox(height: AppSpacing.base),
          _SummaryStrip(stats: stats, animate: weekly),
          const SizedBox(height: AppSpacing.sm),
          _InsightGrid(stats: stats, animate: weekly),
          const AppSectionBand(top: AppSpacing.xl),
          const AppMonthHeader(
            label: '일별 볼륨',
            count: '단위 kg',
            strong: true,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xxs,
              AppSpacing.screenH,
              0,
            ),
            child: Text('무게 × 반복 횟수 합계', style: AppTextStyles.bodySm),
          ),
          _VolumeBarChart(stats: stats, period: _period),
          const AppSectionBand(top: AppSpacing.xl),
          AppMonthHeader(
            label: '부위별 세트',
            count: '${stats.totalSets}',
            strong: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              0,
            ),
          ),
          _CategoryBreakdown(stats: stats, period: _period),
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
            AppScreenHeader.centered(
              title: '운동 통계',
              subtitle: '나의 운동 현황을 한눈에',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xs,
                AppSpacing.screenH,
                0,
              ),
              child: _PeriodTabs(
                weekly: _period == _Period.weekly,
                onChanged: (weekly) {
                  final next = weekly ? _Period.weekly : _Period.monthly;
                  if (next == _period) return;
                  setState(() => _period = next);
                  _load();
                },
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// 기간 나눔 버튼 (시안: 2칸, 높이 44, 반경 14, 15 글자, 선택 = ink 채움 + 흰 500, 비선택 = canvasSoft).
class _PeriodTabs extends StatelessWidget {
  final bool weekly;
  final ValueChanged<bool> onChanged;

  const _PeriodTabs({required this.weekly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, bool value) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => onChanged(value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: AppSize.touchMin,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.canvasSoft,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Text(
                label,
                style: selected
                    ? AppTextStyles.bodyMd.medium.copyWith(
                        color: AppColors.canvas,
                      )
                    : AppTextStyles.bodyMd,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('이번 주', weekly, true),
        const SizedBox(width: AppSpacing.sm),
        tab('이번 달', !weekly, false),
      ],
    );
  }
}

String _volumeText(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}t';
  return '${value.toStringAsFixed(0)}kg';
}

/// '18.2t' → ('18.2', 't'): 값과 단위를 나눠 굵기를 달리 그린다.
(String, String) _splitVolume(double value) {
  final text = _volumeText(value);
  final number = text.replaceAll(RegExp(r'[a-z]+$'), '');
  return (number, text.substring(number.length));
}

/// 막대 위 짧은 숫자: 3200 → 3.2K
String _compactNumber(double value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(0);
}

const _weekdayCodes = ['월', '화', '수', '목', '금', '토', '일'];

// ── 요약 숫자 칸 (시안: 안쪽 14, 반경 18, 라벨 13, 값 22/500 + 단위) ──────────

class _SummaryStrip extends StatelessWidget {
  final WorkoutStats stats;
  final bool animate;

  const _SummaryStrip({required this.stats, required this.animate});

  @override
  Widget build(BuildContext context) {
    final (volumeValue, volumeUnit) = _splitVolume(stats.totalVolume);
    AppKpiCard cell(String label, String value, String unit) => AppKpiCard(
      framed: false,
      label: label,
      value: value,
      unit: unit,
      valueSize: 22,
      padding: const EdgeInsets.all(14),
    );

    return AppStatStrip(
      // 시안 `up`: .5s, 0 / .08 / .16초
      entrance: animate ? const AppStatEntrance() : null,
      cells: [
        cell('운동 일수', '${stats.totalWorkoutDays}', '일'),
        cell('총 볼륨', volumeValue, volumeUnit),
        cell('총 세트', '${stats.totalSets}', '세트'),
      ],
    );
  }
}

// ── 보조 숫자 칸 (시안: 안쪽 12 14, 반경 14, 라벨 12, 값 20/500) ────────────

class _InsightGrid extends StatelessWidget {
  final WorkoutStats stats;
  final bool animate;

  const _InsightGrid({required this.stats, required this.animate});

  @override
  Widget build(BuildContext context) {
    final bestDay = stats.bestVolumeDay;
    final bestDate = bestDay == null
        ? null
        : DateFormat('MM.dd').format(DateTime.parse(bestDay.date));
    final (avgValue, avgUnit) = _splitVolume(stats.avgVolumePerSession);
    final best = bestDay == null ? null : _splitVolume(bestDay.volume);

    AppKpiCard cell(String label, String value, String unit) => AppKpiCard(
      framed: false,
      label: label,
      value: value,
      unit: unit,
      valueSize: 20,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.md,
      ),
      labelSize: 12,
      labelGap: AppSpacing.xxs,
      valueColor: value == '-' ? AppColors.faint : null,
    );

    return AppStatGrid(
      radius: AppRadius.field,
      // 시안 `up`: .2 / .24 / .28 / .32초
      entrance: animate
          ? const AppStatEntrance(
              start: Duration(milliseconds: 200),
              step: Duration(milliseconds: 40),
            )
          : null,
      cells: [
        cell('최근 연속', '${stats.activeStreakDays}', '일'),
        cell('운동 횟수', '${stats.totalSessions}', '회'),
        cell('회당 평균', avgValue, avgUnit),
        cell(
          '최고 볼륨일',
          best == null ? '-' : best.$1,
          best == null ? '' : '${best.$2} · $bestDate',
        ),
      ],
    );
  }
}

// ── 일별 볼륨 막대 ───────────────────────────────────────────────────────────

/// 시안 막대 차트 (높이 200, 위 16): 격자 y 20·70·120(hairline) + 바닥선 170(track),
/// 칸 사이 10, 막대 최대 폭 22(이번 달 14)·반경 8(7), 최고값 막대만 주황.
/// 막대 위 값 11/500(최고값은 noticeText), 아래 요일·날짜 12 mute(오늘은 ink).
/// 이번 주는 월~일 7칸, 이번 달은 기록 있는 날만. 막대는 아래에서 자란다(`grow` .8s, 차례로).
class _VolumeBarChart extends StatelessWidget {
  final WorkoutStats stats;
  final _Period period;

  const _VolumeBarChart({required this.stats, required this.period});

  static const _height = 200.0;
  static const _barArea = 140.0;
  static const _baseline = 170.0;

  @override
  Widget build(BuildContext context) {
    final weekly = period == _Period.weekly;
    final today = DateUtils.dateOnly(DateTime.now());
    final byDate = {for (final d in stats.dailyVolumes) d.date: d.volume};

    // (라벨, 볼륨, 오늘인지)
    final columns = <(String, double, bool)>[];
    if (weekly) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        columns.add((
          _weekdayCodes[i],
          byDate[DateFormat('yyyy-MM-dd').format(day)] ?? 0,
          day == today,
        ));
      }
    } else {
      for (final d in stats.dailyVolumes) {
        final date = DateTime.parse(d.date);
        columns.add((
          DateFormat('dd').format(date),
          d.volume,
          DateUtils.dateOnly(date) == today,
        ));
      }
    }

    final peak = columns.fold<double>(0, (m, c) => c.$2 > m ? c.$2 : m);
    final peakIndex = columns.indexWhere((c) => c.$2 == peak && peak > 0);
    final barWidth = weekly ? 22.0 : 14.0;
    final barRadius = weekly ? 8.0 : 7.0;
    final gap = columns.length > 12 ? 4.0 : 10.0;
    // 칸이 많으면 최고값만 숫자를 단다
    final crowded = columns.length > 10;
    final step = weekly ? 60 : 50;

    final summary = stats.dailyVolumes.isEmpty
        ? '기록 없음'
        : '${stats.dailyVolumes.length}일 기록, 최고 ${_volumeText(peak)}';

    Widget gridLine(double top, Color color) => Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Container(height: 1, color: color),
    );

    return Semantics(
      label: '일별 볼륨 막대 차트: $summary',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.base,
          AppSpacing.screenH,
          0,
        ),
        child: SizedBox(
          height: _height,
          child: Stack(
            children: [
              gridLine(20, AppColors.hairline),
              gridLine(70, AppColors.hairline),
              gridLine(120, AppColors.hairline),
              gridLine(_baseline, AppColors.track),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(
                        child: Column(
                          children: [
                            // 막대 + 위 값 (바닥선 170에 붙는다)
                            SizedBox(
                              height: _baseline,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (columns[i].$2 > 0 &&
                                      (!crowded || i == peakIndex)) ...[
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _compactNumber(columns[i].$2),
                                        maxLines: 1,
                                        style: AppTextStyles.badge.copyWith(
                                          color: i == peakIndex
                                              ? AppColors.noticeText
                                              : AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  if (columns[i].$2 > 0)
                                    AppGrow(
                                      axis: Axis.vertical,
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      delay: Duration(milliseconds: step * i),
                                      child: Container(
                                        width: barWidth,
                                        height: math.max(
                                          2,
                                          _barArea * columns[i].$2 / peak,
                                        ),
                                        decoration: BoxDecoration(
                                          color: i == peakIndex
                                              ? AppColors.primary
                                              : AppColors.ink,
                                          borderRadius: BorderRadius.circular(
                                            barRadius,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 22,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  columns[i].$1,
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: columns[i].$3
                                        ? AppColors.ink
                                        : AppColors.mute,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 부위별 세트: 도넛 + 줄 목록 ─────────────────────────────────────────────

/// 도넛 조각 색 (시안: ink · 주황 · faint · 연주황 · canvasMid). 줄마다 같은 색 점 + 이름 + 세트 수 + 비율 +
/// 4px 막대를 함께 둬서 색만으로 구분하지 않는다. 조각을 누르면 가운데에 그 부위·비율이 나온다.
List<Color> get _donutColors => [
  AppColors.ink,
  AppColors.primary,
  AppColors.faint,
  const Color(0xFFFFC29E),
  AppColors.canvasMid,
];

class _CategoryBreakdown extends StatefulWidget {
  final WorkoutStats stats;
  final _Period period;

  const _CategoryBreakdown({required this.stats, required this.period});

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;

  /// 시안 `spin`: -120° → 0°, 투명 → 불투명 (.9s, cubic-bezier(.2,.8,.2,1))
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _spin.value = 1;
    } else {
      _spin.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Color _colorAt(int i) => _donutColors[i % _donutColors.length];

  void _onTap(TapDownDetails d, List<int> counts, int total) {
    const center = Offset(90, 90);
    final v = d.localPosition - center;
    final r = v.distance;
    if (r < 61 - 6 || r > 79 + 6) {
      setState(() => _touchedIndex = null);
      return;
    }
    // 12시 방향에서 시계 방향 각도 (0~2π)
    var angle = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var acc = 0.0;
    for (var i = 0; i < counts.length; i++) {
      acc += counts[i] / total * 2 * math.pi;
      if (angle <= acc) {
        setState(() => _touchedIndex = _touchedIndex == i ? null : i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.stats.categorySetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (entries.isEmpty || total == 0) return const SizedBox.shrink();
    final counts = [for (final e in entries) e.value];
    final monthly = widget.period == _Period.monthly;

    // 가운데: 누른 조각 > (이번 달) 가장 많은 부위 > (이번 주) 전체 세트 수
    final focus =
        _touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < entries.length
        ? _touchedIndex
        : (monthly ? 0 : null);
    final centerValue = focus == null
        ? '$total'
        : '${(entries[focus].value / total * 100).toStringAsFixed(0)}%';
    final centerLabel = focus == null ? '세트' : entries[focus].key.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.base),
        Semantics(
          label:
              '부위별 세트 분포: ${entries.map((e) => '${e.key.label} ${(e.value / total * 100).toStringAsFixed(0)}%').join(', ')}',
          child: Center(
            child: GestureDetector(
              onTapDown: (d) => _onTap(d, counts, total),
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) {
                        final t = AppMotion.fill.transform(_spin.value);
                        return Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: -2 * math.pi / 3 * (1 - t),
                            child: CustomPaint(
                              size: const Size(180, 180),
                              painter: _DonutPainter(
                                counts: counts,
                                colors: [
                                  for (var i = 0; i < counts.length; i++)
                                    _colorAt(i),
                                ],
                                track: AppColors.canvasSoft,
                                highlight: _touchedIndex,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerValue,
                            style: AppTextStyles.displayMd.copyWith(
                              fontSize: 30,
                              height: 36 / 30,
                              letterSpacing: 30 * -0.019,
                            ),
                          ),
                          Text(centerLabel, style: AppTextStyles.bodySm),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < entries.length; i++)
          _CategoryRow(
            color: _colorAt(i),
            category: entries[i].key,
            count: entries[i].value,
            percent: entries[i].value / total,
            emphasize: monthly && i == 0,
            delay: Duration(milliseconds: 200 + 80 * (i < 8 ? i : 8)),
          ),
      ],
    );
  }
}

/// 도넛 (지름 180, 반지름 70, 두께 18): 바탕 고리 위에 조각을 시계 방향으로, 조각 사이 약 3 띄움.
class _DonutPainter extends CustomPainter {
  final List<int> counts;
  final List<Color> colors;
  final Color track;
  final int? highlight;

  const _DonutPainter({
    required this.counts,
    required this.colors,
    required this.track,
    this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 70.0;
    const stroke = 18.0;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final total = counts.fold<int>(0, (s, c) => s + c);
    if (total == 0) return;
    // 조각 사이 틈: 둘레 3 (한 조각뿐이면 틈 없음)
    final gap = counts.length > 1 ? 3 / radius : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      final sweep = counts[i] / total * 2 * math.pi;
      final drawn = math.max(0.0, sweep - gap);
      canvas.drawArc(
        rect,
        start,
        drawn,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlight == i ? stroke + 4 : stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.counts != counts || old.highlight != highlight;
}

/// 범례 한 줄 (위아래 12, 아래 선 좌우 20 안쪽): 색 점 8 + 이름 15 + 세트 14 mute + 비율 14/500(폭 40) +
/// (위 8) 4 높이 막대(바탕 navLine, 채움 ink, 시안 `growx` .9s 차례로).
class _CategoryRow extends StatelessWidget {
  final Color color;
  final WorkoutCategory category;
  final int count;
  final double percent;
  final bool emphasize;
  final Duration delay;

  const _CategoryRow({
    required this.color,
    required this.category,
    required this.count,
    required this.percent,
    required this.emphasize,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).toStringAsFixed(0);
    return Semantics(
      label: '${category.label} $count세트, $pct퍼센트',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                    child: Text(
                      category.label,
                      style: emphasize
                          ? AppTextStyles.bodyMd.medium
                          : AppTextStyles.bodyMd,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$count세트',
                    style: AppTextStyles.note.copyWith(color: AppColors.mute),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.note.medium.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(
                value: percent,
                height: 4,
                trackColor: AppColors.navLine,
                delay: delay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 빈 화면 그림: 막대 4개(10 폭, 반경 5)가 숨 쉬듯 늘었다 줄어듦
/// (시안 `grow`: 1.8s ease-in-out 반복, 0 / .3 / .6 / .9초 차례로, 높이 40% ↔ 100%).
class _EmptyBars extends StatefulWidget {
  const _EmptyBars();

  @override
  State<_EmptyBars> createState() => _EmptyBarsState();
}

class _EmptyBarsState extends State<_EmptyBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC8C8CC);
    final bars = <(double, Color, double)>[
      (24, light, 0),
      (40, AppColors.faint, 0.3),
      (30, light, 0.6),
      (44, AppColors.primary, 0.9),
    ];
    return SizedBox(
      height: 44,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Builder(
                builder: (context) {
                  final (h, c, delay) = bars[i];
                  // 지연만큼 늦게 시작하는 반복 (0 → 1 → 0)
                  var v = (_controller.value - delay / 1.8) % 1.0;
                  if (v < 0) v += 1;
                  final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
                  final scale = 0.4 + 0.6 * Curves.easeInOut.transform(tri);
                  return Container(
                    width: 10,
                    height: h * scale,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
