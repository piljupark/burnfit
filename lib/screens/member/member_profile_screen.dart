import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
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
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/delete_account_sheet.dart';
import '../../widgets/orb_loader.dart';
import 'edit_profile_sheet.dart';
import 'member_pt_workout_screen.dart';
import 'member_share_settings_screen.dart';
import 'member_workout_stats_screen.dart';
import 'member_routes.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: AppLoadingView(),
      );
    }
    final profile = user.profile;
    final trainer = user.trainerName?.trim() ?? '';
    final subtitle = [
      if (user.centerName.isNotEmpty) user.centerName,
      if (trainer.isNotEmpty) '$trainer 트레이너',
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── 오른쪽 위 편집 버튼 ──────────────────────────────────────────
            SizedBox(
              height: AppSize.touchMin,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppIconButton(
                    icon: AppIcons.edit,
                    label: '프로필 편집',
                    onPressed: () => _showEditProfile(context, user),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),

            // ── 프로필 머리 ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.sm),
              child: AppProfileCard(
                name: user.name,
                subtitle: subtitle,
                roleLabel: '회원',
                seed: user.uid,
              ),
            ),

            // ── InBody ────────────────────────────────────────────────────
            _InbodySection(profile: profile),

            // ── 메뉴 ──────────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.sm),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.chartBar,
              label: '운동 통계',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemberWorkoutStatsScreen(),
                ),
              ),
            ),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.workout,
              label: 'PT 운동 기록',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemberPtWorkoutScreen(),
                ),
              ),
            ),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.share,
              label: '기록 공유 설정',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemberShareSettingsScreen(),
                ),
              ),
            ),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.meal,
              label: '식단 기록',
              onTap: () => MemberRoutes.openMealLog(context),
            ),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.feedback,
              label: '트레이너 피드백',
              onTap: () => MemberRoutes.openFeedback(context),
            ),
            const AppRowDivider(),

            // ── 내 정보 ───────────────────────────────────────────────────
            const AppMonthHeader(label: '내 정보'),
            _InfoRow(label: '센터', value: user.centerName.isNotEmpty ? user.centerName : '-'),
            _InfoRow(label: '트레이너', value: trainer.isNotEmpty ? trainer : '미배정'),
            _InfoRow(label: '상태', trailing: _statusTag(user.status)),
            _InfoRow(label: '이메일', value: user.email),
            _InfoRow(
              label: '생년월일',
              value: (user.birthDate?.trim().isNotEmpty ?? false) ? user.birthDate! : '-',
            ),
            _InfoRow(label: '성별', value: _genderLabel(user.gender)),

            // ── 신체 정보 ─────────────────────────────────────────────────
            AppMonthHeader(
              label: '신체 정보',
              trailing: AppButton(
                label: '편집',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: () => _showEditProfile(context, user),
              ),
            ),
            if (profile == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('신체 정보를 입력해주세요', style: AppTextStyles.bodyLg),
                    const SizedBox(height: AppSpacing.xs),
                    Text('키, 체중, 목표를 입력하면 트레이너와 공유됩니다.', style: AppTextStyles.bodySm),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: '지금 입력하기',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.sm,
                      onPressed: () => _showEditProfile(context, user),
                    ),
                  ],
                ),
              )
            else ...[
              _InfoRow(label: '키', value: _withUnit(profile.height, 'cm')),
              _InfoRow(label: '체중', value: _withUnit(profile.weight, 'kg')),
              _InfoRow(label: 'BMI', value: profile.bmi?.toStringAsFixed(1) ?? '-'),
              _InfoRow(label: '골격근량', value: _withUnit(profile.muscleMass, 'kg')),
              _InfoRow(label: '체지방량', value: _withUnit(profile.bodyFat, 'kg')),
              _InfoRow(
                label: '체지방률',
                value: profile.bodyFatPercent != null ? '${profile.bodyFatPercent!.toStringAsFixed(1)}%' : '-',
              ),
            ],

            // ── 목표 ──────────────────────────────────────────────────────
            AppMonthHeader(
              label: '목표',
              trailing: AppButton(
                label: (profile?.goal?.trim().isNotEmpty ?? false) ? '편집' : '추가',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: () => _showEditProfile(context, user),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.sm),
              child: (profile?.goal?.trim().isNotEmpty ?? false)
                  ? Text(profile!.goal!.trim(), style: AppTextStyles.bodyMd)
                  : Text('아직 목표가 없습니다.', style: AppTextStyles.bodySm),
            ),

            // ── 로그아웃 · 탈퇴 ───────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const AppRowDivider(),
            AppActionRow(
              icon: AppIcons.signOut,
              label: '로그아웃',
              isDestructive: true,
              onTap: () async {
                await context.read<UserProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.memberLogin);
              },
            ),
            const AppRowDivider(),
            const SizedBox(height: AppSpacing.lg),
            const DeleteAccountLink(),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _withUnit(double? v, String unit) => v == null ? '-' : '${_fmt(v)} $unit';

  static String _genderLabel(Gender? g) => switch (g) {
    Gender.male => '남성',
    Gender.female => '여성',
    Gender.other => '기타',
    null => '-',
  };

  /// 상태는 모양으로: 이용 중 = 흰 채움, 승인 대기 = 외곽선, 반려 = 빨간 글자.
  static Widget _statusTag(UserStatus s) => switch (s) {
    UserStatus.pending => const AppTag('승인 대기'),
    UserStatus.approved => const AppTag('이용 중', strong: true),
    UserStatus.rejected => const AppTag('반려', danger: true),
  };

  static void _showEditProfile(BuildContext context, AppUser user) {
    showAppBottomSheet(
      context: context,
      memberStyle: true,
      child: EditProfileSheet(user: user),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 정보 한 줄: 라벨(mute) + 값 / 오른쪽 위젯. hairline 아래.
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;

  const _InfoRow({required this.label, this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final v = value ?? '';
    return Semantics(
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label, style: AppTextStyles.bodySm)),
            Expanded(
              child: trailing != null
                  ? Align(alignment: Alignment.centerLeft, child: trailing)
                  : Text(
                      v,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: v == '-' ? AppColors.mute : AppColors.ink,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InBody: 머리말(날짜) → 숫자 줄(체중·골격근량·체지방률 + 변화량) → 추이 선 그래프
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

  /// 최신값과 직전값의 차이 (없으면 null).
  ({String? text, bool? up}) _delta(_InbodyTrendMetric metric) {
    final values = _items.map(metric.valueOf).whereType<double>().toList();
    if (values.length < 2) return (text: null, up: null);
    final diff = values.last - values[values.length - 2];
    if (diff.abs() < 0.05) return (text: '0.0', up: null);
    return (text: diff.abs().toStringAsFixed(1), up: diff > 0);
  }

  Widget _statCell(String label, _InbodyTrendMetric metric, double? fallback) {
    final latest = _items.isEmpty ? null : metric.valueOf(_items.last);
    final value = latest ?? fallback;
    final delta = _delta(metric);
    return AppKpiCard(
      label: label,
      value: value == null ? '-' : value.toStringAsFixed(1),
      unit: value == null ? '' : metric.unit,
      framed: false,
      valueSize: 24,
      trend: delta.text,
      trendUp: delta.up,
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestDate = _items.isEmpty ? null : DateTime.tryParse(_items.last.measurementDate);
    final chartItems = _items
        .where((item) => _metric.valueOf(item) != null)
        .toList(growable: false);
    final values = chartItems.map((i) => _metric.valueOf(i)!).toList(growable: false);
    final labels = chartItems.map((item) {
      final parsed = DateTime.tryParse(item.measurementDate);
      return parsed != null ? DateFormat('MM').format(parsed) : '';
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMonthHeader(
          label: '인바디',
          count: latestDate == null ? null : DateFormat('MM.dd').format(latestDate),
        ),
        AppStatStrip(
          topBorder: true,
          cells: [
            _statCell('체중', _InbodyTrendMetric.weight, widget.profile?.weight),
            _statCell('골격근량', _InbodyTrendMetric.muscleMass, widget.profile?.muscleMass),
            _statCell('체지방률', _InbodyTrendMetric.bodyFatPercent, widget.profile?.bodyFatPercent),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppScrollableChips(
          labels: [for (final m in _InbodyTrendMetric.values) m.label],
          selectedIndex: _InbodyTrendMetric.values.indexOf(_metric),
          onSelected: (i) => setState(() => _metric = _InbodyTrendMetric.values[i]),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SizedBox(
            height: 140,
            child: _loading
                ? const Center(child: OrbLoader.inline(semanticLabel: 'InBody 불러오는 중'))
                : values.isEmpty
                    ? Center(child: Text('${_metric.label} 기록이 없습니다.', style: AppTextStyles.bodySm))
                    : Semantics(
                        image: true,
                        label: '${_metric.label} 추이: ${[
                          for (var i = 0; i < values.length; i++) '${labels[i]}월 ${values[i].toStringAsFixed(1)}${_metric.unit}',
                        ].join(', ')}',
                        excludeSemantics: true,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _TrendPainter(
                            values: values,
                            labels: labels,
                            labelStyle: AppTextStyles.counter,
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}

/// 얇은 흰 선 그래프: 선 1.5px ink, 격자 hairline, 축 라벨 모노 counter.
class _TrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final TextStyle labelStyle;

  const _TrendPainter({required this.values, required this.labels, required this.labelStyle});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelBand = 20.0;
    const topPad = 12.0;
    final chartH = size.height - labelBand;

    // 격자: 가로 hairline 3줄
    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = topPad + (chartH - topPad) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.1 ? 1.0 : maxV - minV;
    const hPad = 12.0;
    final usableW = size.width - hPad * 2;

    final points = List.generate(values.length, (i) {
      final x = values.length == 1 ? size.width / 2 : hPad + usableW * i / (values.length - 1);
      final norm = values.length == 1 || (maxV - minV).abs() < 0.1 ? 0.5 : (values[i] - minV) / range;
      final y = topPad + (chartH - topPad) * (1 - norm);
      return Offset(x, y);
    });

    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = AppColors.ink;
    final hole = Paint()..color = AppColors.canvas;
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      canvas.drawCircle(points[i], isLast ? 4 : 3, dot);
      if (!isLast) canvas.drawCircle(points[i], 1.5, hole);
    }

    for (var i = 0; i < points.length && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.labels != labels;
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
