import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/inbody.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import 'member_pt_workout_screen.dart';
import 'member_share_settings_screen.dart';
import 'member_workout_stats_screen.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = user.profile;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 헤더 + 프로필 히어로 ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      '프로필',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Gap(20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProfileHero(
                      user: user,
                      onEdit: () => _showEditProfile(context, user),
                    ),
                  ),
                  const Gap(20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _BodyMetricBar(profile: profile),
                  ),
                  const Gap(12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const _WeightTrendCard(),
                  ),
                  const Gap(12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProfileActionRows(
                      onShareTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MemberShareSettingsScreen(),
                        ),
                      ),
                      onLogout: () async {
                        await context.read<UserProvider>().signOut();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.memberLogin);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 섹션들 ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _SectionGroup(
                    children: [
                      AppActionRow(
                        icon: Icons.bar_chart_rounded,
                        label: '운동 통계',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MemberWorkoutStatsScreen(),
                          ),
                        ),
                      ),
                      const AppRowDivider(),
                      AppActionRow(
                        icon: Icons.fitness_center_outlined,
                        label: 'PT 운동 기록',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MemberPtWorkoutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.lg),

                  // 멤버십 정보
                  const AppSectionHeader(title: '멤버십'),
                  _SectionGroup(
                    children: [
                      _InfoRow(
                        label: '센터',
                        value: user.centerName.isNotEmpty
                            ? user.centerName
                            : '-',
                      ),
                      const AppRowDivider(),
                      _InfoRow(
                        label: '트레이너',
                        value: (user.trainerName?.trim().isNotEmpty ?? false)
                            ? user.trainerName!
                            : '미배정',
                      ),
                      const AppRowDivider(),
                      _InfoRow(
                        label: '상태',
                        value: _statusLabel(user.status),
                        valueColor: _statusColor(user.status),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.lg),

                  // 개인 정보
                  const AppSectionHeader(title: '개인 정보'),
                  _SectionGroup(
                    children: [
                      _InfoRow(label: '이름', value: user.name),
                      const AppRowDivider(),
                      _InfoRow(label: '이메일', value: user.email),
                      const AppRowDivider(),
                      _InfoRow(
                        label: '생년월일',
                        value: (user.birthDate?.trim().isNotEmpty ?? false)
                            ? user.birthDate!
                            : '-',
                      ),
                      const AppRowDivider(),
                      _InfoRow(label: '성별', value: _genderLabel(user.gender)),
                    ],
                  ),
                  const Gap(AppSpacing.lg),

                  // 신체 조성
                  _BodyCompositionSection(
                    profile: profile,
                    onEdit: () => _showEditProfile(context, user),
                  ),
                  const Gap(AppSpacing.lg),

                  // 목표
                  _GoalSection(
                    goal: profile?.goal,
                    onEdit: () => _showEditProfile(context, user),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _genderLabel(Gender? g) => switch (g) {
    Gender.male => '남성',
    Gender.female => '여성',
    Gender.other => '기타',
    null => '-',
  };

  static String _statusLabel(UserStatus s) => switch (s) {
    UserStatus.pending => '승인 대기',
    UserStatus.approved => '이용 중',
    UserStatus.rejected => '반려',
  };

  static Color _statusColor(UserStatus s) => switch (s) {
    UserStatus.pending => AppColors.diet,
    UserStatus.approved => AppColors.workout,
    UserStatus.rejected => AppColors.destructive,
  };

  static void _showEditProfile(BuildContext context, AppUser user) {
    showAppBottomSheet(
      context: context,
      memberStyle: true,
      child: _EditProfileSheet(user: user),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 프로필 히어로 카드
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;

  const _ProfileHero({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0] : '?';
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.trainer.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: AppTextStyles.h2.copyWith(
              color: AppColors.trainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: AppTextStyles.headline.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(2),
              Text(
                user.email,
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const Gap(AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xxs,
                children: [
                  if (user.centerName.isNotEmpty) _Chip(label: user.centerName),
                  if (user.trainerName?.trim().isNotEmpty ?? false)
                    _Chip(label: user.trainerName!),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionSmall.copyWith(
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 신체 지표 바 (키 / 체중 / BMI 가로 배치)
// ─────────────────────────────────────────────────────────────────────────────

class _BodyMetricBar extends StatelessWidget {
  final UserProfile? profile;

  const _BodyMetricBar({required this.profile});

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              label: '키',
              value: profile?.height != null ? _fmt(profile!.height!) : '-',
              unit: profile?.height != null ? 'cm' : '',
            ),
          ),
          Container(width: 0.5, height: 40, color: AppColors.border),
          Expanded(
            child: _MetricItem(
              label: '체중',
              value: profile?.weight != null ? _fmt(profile!.weight!) : '-',
              unit: profile?.weight != null ? 'kg' : '',
            ),
          ),
          Container(width: 0.5, height: 40, color: AppColors.border),
          Expanded(
            child: _MetricItem(
              label: 'BMI',
              value: profile?.bmi != null
                  ? profile!.bmi!.toStringAsFixed(1)
                  : '-',
              unit: '',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTrendCard extends StatefulWidget {
  const _WeightTrendCard();

  @override
  State<_WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<_WeightTrendCard> {
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

  @override
  Widget build(BuildContext context) {
    final chartItems = _items
        .where((item) => _metric.valueOf(item) != null)
        .toList(growable: false);
    final points = _buildPoints(chartItems);
    final labels = chartItems.map((item) {
      final parsed = DateTime.tryParse(item.measurementDate);
      return parsed != null
          ? DateFormat('M월', 'ko').format(parsed)
          : item.measurementDate;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'InBody 추이',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (chartItems.length >= 2)
                Text(
                  _deltaText(chartItems),
                  style: AppTextStyles.captionSmall.copyWith(
                    color: _deltaColor(chartItems),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const Gap(12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final metric in _InbodyTrendMetric.values) ...[
                  _TrendMetricChip(
                    metric: metric,
                    selected: metric == _metric,
                    onTap: () => setState(() => _metric = metric),
                  ),
                  const Gap(8),
                ],
              ],
            ),
          ),
          const Gap(12),
          if (_loading)
            const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (points.isEmpty)
            SizedBox(
              height: 130,
              child: Center(
                child: Text(
                  '${_metric.label} 기록이 없습니다.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeightTrendPainter(
                  points: points,
                  labels: labels,
                  values: chartItems
                      .map((item) => _metric.formatValue(item))
                      .toList(growable: false),
                  color: _metric.color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Offset> _buildPoints(List<Inbody> items) {
    if (items.isEmpty) return const [];
    if (items.length == 1) return const [Offset(140, 58)];

    final values = items
        .map((item) => _metric.valueOf(item))
        .whereType<double>()
        .toList(growable: false);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.1 ? 1.0 : maxValue - minValue;
    final step = 240 / (items.length - 1);

    return List.generate(items.length, (index) {
      final value = _metric.valueOf(items[index]) ?? minValue;
      final normalized = (value - minValue) / range;
      final x = 20 + step * index;
      final y = 94 - normalized * 58;
      return Offset(x, y);
    });
  }

  String _deltaText(List<Inbody> items) {
    final first = _metric.valueOf(items.first);
    final last = _metric.valueOf(items.last);
    if (first == null || last == null) return '';
    final diff = last - first;
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)}${_metric.unit}';
  }

  Color _deltaColor(List<Inbody> items) {
    final first = _metric.valueOf(items.first);
    final last = _metric.valueOf(items.last);
    if (first == null || last == null || (last - first).abs() < 0.1) {
      return AppColors.textSecondary;
    }
    return last > first
        ? AppColors.brand
        : AppColors.destructive;
  }
}

class _WeightTrendPainter extends CustomPainter {
  final List<Offset> points;
  final List<String> labels;
  final List<String> values;
  final Color color;

  const _WeightTrendPainter({
    required this.points,
    required this.labels,
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final scaleX = size.width / 280;
    final scaled = points.map((p) => Offset(p.dx * scaleX, p.dy)).toList();
    final path = Path()..moveTo(scaled.first.dx, scaled.first.dy);
    for (final point in scaled.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (final point in scaled) {
      canvas.drawCircle(point, 3.5, dotPaint);
    }

    for (var i = 0; i < scaled.length; i++) {
      final valuePainter = TextPainter(
        text: TextSpan(
          text: i < values.length ? values[i] : '',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(scaled[i].dx - valuePainter.width / 2, scaled[i].dy - 22),
      );

      final painter = TextPainter(
        text: TextSpan(
          text: i < labels.length ? labels[i] : '',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(scaled[i].dx - painter.width / 2, 116));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.labels != labels ||
        oldDelegate.values != values ||
        oldDelegate.color != color;
  }
}

enum _InbodyTrendMetric {
  weight('체중', 'kg', AppColors.brand),
  muscleMass('골격근량', 'kg', Color(0xFF10A37F)),
  bodyFat('체지방량', 'kg', Color(0xFFE67E22)),
  bodyFatPercent('체지방률', '%', Color(0xFFE25563));

  final String label;
  final String unit;
  final Color color;

  const _InbodyTrendMetric(this.label, this.unit, this.color);

  double? valueOf(Inbody item) {
    return switch (this) {
      _InbodyTrendMetric.weight => item.weight,
      _InbodyTrendMetric.muscleMass => item.muscleMass,
      _InbodyTrendMetric.bodyFat => item.bodyFat,
      _InbodyTrendMetric.bodyFatPercent => item.bodyFatPercent,
    };
  }

  String formatValue(Inbody item) {
    final value = valueOf(item);
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)}$unit';
  }
}

class _TrendMetricChip extends StatelessWidget {
  final _InbodyTrendMetric metric;
  final bool selected;
  final VoidCallback onTap;

  const _TrendMetricChip({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? metric.color : AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? metric.color : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          metric.label,
          style: AppTextStyles.captionSmall.copyWith(
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProfileActionRows extends StatelessWidget {
  final VoidCallback onShareTap;
  final Future<void> Function() onLogout;

  const _ProfileActionRows({required this.onShareTap, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppActionRow(
          icon: Icons.share_outlined,
          label: '기록 공유 설정',
          onTap: onShareTap,
        ),
        const Gap(12),
        AppActionRow(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          isDestructive: true,
          onTap: () {
            onLogout();
          },
        ),
      ],
    );
  }
}


class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm + 2,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.h4.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: value == '-'
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const Gap(2),
                Text(
                  unit,
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          const Gap(2),
          Text(
            label,
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 섹션 공용 위젯
// ─────────────────────────────────────────────────────────────────────────────

class _SectionGroup extends StatelessWidget {
  final List<Widget> children;

  const _SectionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}


class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// 신체 조성 섹션
// ─────────────────────────────────────────────────────────────────────────────

class _BodyCompositionSection extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onEdit;

  const _BodyCompositionSection({required this.profile, required this.onEdit});

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '신체 조성',
          trailing: '편집',
          onTrailingTap: onEdit,
        ),
        if (profile == null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 28,
                    color: AppColors.textDisabled,
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    '신체 정보를 입력해주세요',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    '키, 체중, 목표를 입력하면 트레이너와 공유됩니다.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  AppButton(
                    label: '지금 입력하기',
                    onPressed: onEdit,
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            ),
          )
        else
          _SectionGroup(
            children: [
              _BodyStatRow(
                label: '골격근량',
                value: profile!.muscleMass != null
                    ? '${_fmt(profile!.muscleMass!)} kg'
                    : '-',
              ),
              const AppRowDivider(),
              _BodyStatRow(
                label: '체지방량',
                value: profile!.bodyFat != null
                    ? '${_fmt(profile!.bodyFat!)} kg'
                    : '-',
              ),
              const AppRowDivider(),
              _BodyStatRow(
                label: '체지방률',
                value: profile!.bodyFatPercent != null
                    ? '${profile!.bodyFatPercent!.toStringAsFixed(1)}%'
                    : '-',
              ),
            ],
          ),
      ],
    );
  }
}

class _BodyStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _BodyStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: value == '-'
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 목표 섹션
// ─────────────────────────────────────────────────────────────────────────────

class _GoalSection extends StatelessWidget {
  final String? goal;
  final VoidCallback onEdit;

  const _GoalSection({required this.goal, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '목표',
          trailing: hasGoal ? '편집' : '추가',
          onTrailingTap: onEdit,
        ),
        GestureDetector(
          onTap: !hasGoal ? onEdit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(
              hasGoal ? goal!.trim() : '목표를 설정해보세요 →',
              style: AppTextStyles.body.copyWith(
                color: hasGoal
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 프로필 수정 바텀시트
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final AppUser user;

  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _muscleCtrl;
  late final TextEditingController _bodyFatCtrl;
  late final TextEditingController _goalCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.user.profile;
    _heightCtrl = TextEditingController(text: p?.height?.toString() ?? '');
    _weightCtrl = TextEditingController(text: p?.weight?.toString() ?? '');
    _muscleCtrl = TextEditingController(text: p?.muscleMass?.toString() ?? '');
    _bodyFatCtrl = TextEditingController(text: p?.bodyFat?.toString() ?? '');
    _goalCtrl = TextEditingController(text: p?.goal ?? '');
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _muscleCtrl.dispose();
    _bodyFatCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        height: double.tryParse(_heightCtrl.text.trim()),
        weight: double.tryParse(_weightCtrl.text.trim()),
        muscleMass: double.tryParse(_muscleCtrl.text.trim()),
        bodyFat: double.tryParse(_bodyFatCtrl.text.trim()),
        goal: _goalCtrl.text.trim().isEmpty ? null : _goalCtrl.text.trim(),
      );
      await FirestoreService.updateUser(widget.user.uid, {
        'profile': profile.toMap(),
      });
      if (!mounted) return;
      context.read<UserProvider>().updateUserLocally(
        widget.user.copyWith(profile: profile),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppBottomSheetHeader(
          title: '신체 정보 수정',
          subtitle: '트레이너와 공유되는 핵심 정보입니다.',
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: '키 (cm)',
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체중 (kg)',
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: '골격근량 (kg)',
                controller: _muscleCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체지방량 (kg)',
                controller: _bodyFatCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        AppTextField(
          label: '목표',
          hint: '예: 체지방 감량, 근육량 증가',
          controller: _goalCtrl,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const Gap(AppSpacing.lg),
        AppButton(
          label: '저장',
          onPressed: _save,
          isLoading: _isSaving,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }
}
