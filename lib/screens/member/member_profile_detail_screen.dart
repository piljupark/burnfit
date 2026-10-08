import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/birth_date.dart';
import '../../models/inbody.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import 'edit_basic_info_sheet.dart';
import 'edit_profile_sheet.dart';

/// 회원 프로필 (시안 MemB-Profile · MemB-ProfileEmpty).
/// 가운데 17 머리 → 이름 24 + 이메일 → (띠) 기본 정보 → (띠) 신체 정보 → (띠) 인바디(숫자 칸·추이 그래프) → (띠) 목표.
/// 각 묶음 머리 오른쪽 '편집'(15/500)이 해당 시트를 연다.
class MemberProfileDetailScreen extends StatelessWidget {
  const MemberProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: AppLoadingView(),
      );
    }
    final profile = user.profile;
    final trainer = user.trainerName?.trim() ?? '';
    final goal = profile?.goal?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '프로필',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xl3),
                children: [
                  // ── 이름 · 이메일 ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            user.name,
                            style: AppTextStyles.displayMd.copyWith(
                              fontSize: 24,
                              height: 30 / 24,
                              letterSpacing: 24 * -0.019,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(user.email, style: AppTextStyles.note),
                      ],
                    ),
                  ),
                  const AppSectionBand(top: AppSpacing.xl),

                  // ── 기본 정보 ───────────────────────────────────────────
                  _GroupHeader(
                    label: '기본 정보',
                    action: '편집',
                    actionSemantics: '기본 정보 편집',
                    onAction: () =>
                        _openSheet(context, EditBasicInfoSheet(user: user)),
                  ),
                  _InfoRow(
                    label: '센터',
                    value: user.centerName.isNotEmpty ? user.centerName : null,
                  ),
                  _InfoRow(
                    label: '담당 트레이너',
                    value: trainer.isNotEmpty ? trainer : null,
                    emptyText: '미배정',
                  ),
                  _InfoRow(
                    label: '생년월일',
                    value: formatBirthDate(user.birthDate),
                  ),
                  _InfoRow(label: '성별', value: user.gender?.label, last: true),
                  const AppSectionBand(top: AppSpacing.base),

                  // ── 신체 정보 ───────────────────────────────────────────
                  _GroupHeader(
                    label: '신체 정보',
                    action: '편집',
                    actionSemantics: '신체 정보 편집',
                    onAction: () =>
                        _openSheet(context, EditProfileSheet(user: user)),
                  ),
                  if (profile == null) ...[
                    const _BodyEmptyCard(),
                    const AppSectionBand(top: AppSpacing.xl),
                  ] else ...[
                    _InfoRow(
                      label: '키',
                      value: _num(profile.height),
                      unit: 'cm',
                      strong: true,
                    ),
                    _InfoRow(
                      label: '체중',
                      value: _num(profile.weight),
                      unit: 'kg',
                      strong: true,
                    ),
                    _InfoRow(
                      label: 'BMI',
                      value: profile.bmi?.toStringAsFixed(1),
                      strong: true,
                    ),
                    _InfoRow(
                      label: '골격근량',
                      value: _num(profile.muscleMass),
                      unit: 'kg',
                      strong: true,
                    ),
                    _InfoRow(
                      label: '체지방량',
                      value: _num(profile.bodyFat),
                      unit: 'kg',
                      strong: true,
                    ),
                    _InfoRow(
                      label: '체지방률',
                      value: profile.bodyFatPercent?.toStringAsFixed(1),
                      unit: '%',
                      strong: true,
                      last: true,
                    ),
                    const AppSectionBand(top: AppSpacing.md),
                  ],

                  // ── 인바디 추이 ─────────────────────────────────────────
                  _InbodySection(profile: profile),
                  const AppSectionBand(top: AppSpacing.lg),

                  // ── 목표 ────────────────────────────────────────────────
                  _GroupHeader(
                    label: '목표',
                    action: goal.isNotEmpty ? '편집' : '추가',
                    actionSemantics: goal.isNotEmpty ? '목표 편집' : '목표 추가',
                    onAction: () =>
                        _openSheet(context, EditProfileSheet(user: user)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xs,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: goal.isNotEmpty
                        ? Text(
                            goal,
                            style: AppTextStyles.input.copyWith(height: 1.55),
                          )
                        : Text(
                            '아직 목표가 없습니다.',
                            style: AppTextStyles.note.copyWith(
                              color: AppColors.mute,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openSheet(BuildContext context, Widget sheet) {
    showAppBottomSheet(context: context, memberStyle: true, child: sheet);
  }

  static String? _num(double? v) {
    if (v == null) return null;
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 묶음 머리: 15 mute 라벨 + 오른쪽 '편집'(15/500 ink, 44 높이). 여백 8 8 0 20.
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  final String action;
  final String actionSemantics;
  final VoidCallback onAction;

  const _GroupHeader({
    required this.label,
    required this.action,
    required this.actionSemantics,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(label, style: AppTextStyles.eyebrow),
            ),
          ),
          Semantics(
            button: true,
            label: actionSemantics,
            excludeSemantics: true,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadius.field),
              highlightColor: AppColors.canvasSoft,
              splashFactory: NoSplash.splashFactory,
              child: Container(
                height: AppSize.touchMin,
                constraints: const BoxConstraints(minWidth: AppSize.touchMin),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                child: Text(action, style: AppTextStyles.bodyMd.medium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 정보 한 줄 (52): 왼쪽 라벨 15 mute, 오른쪽 값 16. 좌우 20 안쪽 아래 선(마지막 줄 없음).
// [strong]이면 값 500 + 단위 400 mute를 붙여 쓴다. 값이 없으면 faint.
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String unit;
  final String emptyText;
  final bool strong;
  final bool last;

  const _InfoRow({
    required this.label,
    required this.value,
    this.unit = '',
    this.emptyText = '-',
    this.strong = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final base = AppTextStyles.input;
    final Widget valueText = v == null || v.isEmpty
        ? Text(emptyText, style: base.copyWith(color: AppColors.faint))
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: v),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.mute,
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.end,
            style: strong ? base.medium : base,
          );
    return Semantics(
      container: true,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.eyebrow),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: valueText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 신체 정보가 없을 때: 회색 카드(반경 18) 안 아이콘 36 + 16/500 + 14 mute, 가운데 정렬.
class _BodyEmptyCard extends StatelessWidget {
  const _BodyEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        children: [
          Icon(AppIcons.clipboard, size: 36, color: AppColors.faint),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '신체 정보를 입력해주세요',
            style: AppTextStyles.listTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '키, 체중, 목표를 입력하면 트레이너와 공유됩니다.',
            style: AppTextStyles.note.copyWith(color: AppColors.mute),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InBody: 머리(오른쪽 'M월 d일 측정') → 숫자 칸 3개 → 항목 칩 → 추이 선 그래프
// ─────────────────────────────────────────────────────────────────────────────

class _InbodySection extends StatefulWidget {
  final UserProfile? profile;

  const _InbodySection({required this.profile});

  @override
  State<_InbodySection> createState() => _InbodySectionState();
}

class _InbodySectionState extends State<_InbodySection> {
  List<Inbody> _items = [];
  _InbodyTrendMetric _metric = _InbodyTrendMetric.weight;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final items = await FirestoreService.getInbodiesByMember(
        user.uid,
        centerId: user.centerId,
        limit: 5,
      ).catchError((_) => <Inbody>[]);
      if (!mounted) return;
      setState(() {
        _items = items.reversed.toList();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 최신값과 직전값의 차이: '0.6 감소' / '0.4 증가' / '변화 없음' (없으면 null).
  String? _delta(_InbodyTrendMetric metric) {
    final values = _items.map(metric.valueOf).whereType<double>().toList();
    if (values.length < 2) return null;
    final diff = values.last - values[values.length - 2];
    if (diff.abs() < 0.05) return '변화 없음';
    return '${diff.abs().toStringAsFixed(1)} ${diff > 0 ? '증가' : '감소'}';
  }

  Widget _statCell(String label, _InbodyTrendMetric metric, double? fallback) {
    final latest = _items.isEmpty ? null : metric.valueOf(_items.last);
    final value = latest ?? fallback;
    return AppKpiCard(
      label: label,
      value: value == null ? '-' : value.toStringAsFixed(1),
      unit: value == null ? '' : metric.unit,
      framed: false,
      valueSize: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      labelSize: 12,
      labelGap: AppSpacing.xxs,
      trend: _delta(metric),
      trendSize: 12,
      trendGap: AppSpacing.xxs,
      valueColor: value == null ? AppColors.faint : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestDate = _items.isEmpty
        ? null
        : DateTime.tryParse(_items.last.measurementDate);
    final chartItems = _items
        .where((item) => _metric.valueOf(item) != null)
        .toList(growable: false);
    final values = chartItems
        .map((i) => _metric.valueOf(i)!)
        .toList(growable: false);
    final labels = chartItems
        .map((item) {
          final parsed = DateTime.tryParse(item.measurementDate);
          return parsed != null ? DateFormat('M월').format(parsed) : '';
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('인바디', style: AppTextStyles.eyebrow),
                ),
              ),
              if (latestDate != null)
                Text(
                  DateFormat('M월 d일 측정').format(latestDate),
                  style: AppTextStyles.note.copyWith(color: AppColors.mute),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppStatStrip(
          radius: AppRadius.field,
          // 시안 `up`: .5s, 0 / .08 / .16초 차례로 (기록이 있을 때만)
          entrance: _items.isEmpty ? null : const AppStatEntrance(),
          cells: [
            _statCell('체중', _InbodyTrendMetric.weight, widget.profile?.weight),
            _statCell(
              '골격근량',
              _InbodyTrendMetric.muscleMass,
              widget.profile?.muscleMass,
            ),
            _statCell(
              '체지방률',
              _InbodyTrendMetric.bodyFatPercent,
              widget.profile?.bodyFatPercent,
            ),
          ],
        ),
        // 칩 자체의 위아래 터치 여백 2를 빼서 시안 16에 맞춘다
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(
            children: [
              for (final m in _InbodyTrendMetric.values) ...[
                if (m.index > 0) const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: m.label,
                  large: true,
                  selected: m == _metric,
                  onTap: () => setState(() => _metric = m),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: _loading
              ? const SizedBox(
                  height: 150,
                  child: Center(
                    child: AppLoader.inline(semanticLabel: 'InBody 불러오는 중'),
                  ),
                )
              : values.isEmpty
              ? Container(
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AppColors.hairline),
                    ),
                  ),
                  child: Text(
                    '${_metric.label} 기록이 없습니다.',
                    style: AppTextStyles.note.copyWith(color: AppColors.mute),
                  ),
                )
              : Semantics(
                  image: true,
                  label:
                      '${_metric.label} 추이: ${[for (var i = 0; i < values.length; i++) '${labels[i]} ${values[i].toStringAsFixed(1)}${_metric.unit}'].join(', ')}',
                  excludeSemantics: true,
                  child: _TrendChart(
                    // 항목을 바꾸면 선을 다시 그린다
                    key: ValueKey(_metric),
                    values: values,
                    labels: labels,
                    unit: _metric.unit,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 추이 선 그래프 (높이 150): 시안 `draw`(선 1.4s ease-out으로 그려짐) +
/// `pop`(점이 .2s부터 .25s 간격으로 튀어나옴, .4s).
class _TrendChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String unit;

  const _TrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
  });

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart>
    with SingleTickerProviderStateMixin {
  static const _lineMs = 1400;
  static const _dotStartMs = 200;
  static const _dotStepMs = 250;
  static const _dotMs = 400;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: [
        _lineMs,
        _dotStartMs + _dotStepMs * (widget.values.length - 1) + _dotMs,
      ].reduce((a, b) => a > b ? a : b),
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _controller.duration!.inMilliseconds;
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final ms = _controller.value * totalMs;
          final line = Curves.easeOut.transform((ms / _lineMs).clamp(0.0, 1.0));
          final dots = [
            for (var i = 0; i < widget.values.length; i++)
              ((ms - _dotStartMs - _dotStepMs * i) / _dotMs).clamp(0.0, 1.0),
          ];
          return CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              values: widget.values,
              labels: widget.labels,
              unit: widget.unit,
              line: line,
              dots: dots,
            ),
          );
        },
      ),
    );
  }
}

/// 선 그래프: 가로 격자 3줄(y 12·66·120, hairline), 선 2px ink, 점 r3.5 ink,
/// 마지막 점 r5.5 주황 + 위에 값(13/500), 아래 월 라벨 12 mute.
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final String unit;

  /// 선이 그려진 비율 (0~1)
  final double line;

  /// 점마다 튀어나온 정도 (0~1)
  final List<double> dots;

  const _TrendPainter({
    required this.values,
    required this.labels,
    required this.unit,
    required this.line,
    required this.dots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 12.0;
    const bottom = 120.0;
    const hPad = 12.0;

    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (final y in const [top, (top + bottom) / 2, bottom]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final flat = (maxV - minV).abs() < 0.1;
    final usableW = size.width - hPad * 2;

    final points = List.generate(values.length, (i) {
      final x = values.length == 1
          ? size.width - hPad
          : hPad + usableW * i / (values.length - 1);
      final norm = flat ? 0.5 : (values[i] - minV) / (maxV - minV);
      final y = top + (bottom - top) * (1 - norm);
      return Offset(x, y);
    });

    // 선: 길이 비율만큼 잘라 그린다 (선 그리기 효과)
    if (points.length > 1 && line > 0) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final paint = Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * line), paint);
      }
    }

    // 점: 0 → 1.3 → 1 (cubic-bezier(.3,1.4,.5,1))
    for (var i = 0; i < points.length; i++) {
      final t = i < dots.length ? dots[i] : 1.0;
      if (t <= 0) continue;
      final scale = AppMotion.pop.transform(t);
      final isLast = i == points.length - 1;
      canvas.drawCircle(
        points[i],
        (isLast ? 5.5 : 3.5) * scale,
        Paint()..color = isLast ? AppColors.primary : AppColors.ink,
      );
      if (isLast) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${values[i].toStringAsFixed(1)}$unit',
            style: AppTextStyles.bodySm.medium.copyWith(
              color: AppColors.ink.withValues(alpha: t),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final dx = (points[i].dx - tp.width).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(dx, points[i].dy - 12 - tp.height));
      }
    }

    // 월 라벨 (12 mute, 점 아래 가운데)
    for (var i = 0; i < points.length && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: AppTextStyles.captionSmall),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final dx = (points[i].dx - tp.width / 2).clamp(
        0.0,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(dx, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.line != line ||
      old.dots != dots;
}

enum _InbodyTrendMetric {
  weight('체중', 'kg'),
  muscleMass('골격근량', 'kg'),
  bodyFat('체지방량', 'kg'),
  bodyFatPercent('체지방률', '%');

  final String label;
  final String unit;

  const _InbodyTrendMetric(this.label, this.unit);

  double? valueOf(Inbody item) {
    return switch (this) {
      _InbodyTrendMetric.weight => item.weight,
      _InbodyTrendMetric.muscleMass => item.muscleMass,
      _InbodyTrendMetric.bodyFat => item.bodyFat,
      _InbodyTrendMetric.bodyFatPercent => item.bodyFatPercent,
    };
  }
}
