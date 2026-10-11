import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muscle_map/muscle_map.dart';

import '../core/app_colors.dart';
import '../core/app_haptics.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/exercise_guide_data.dart';
import '../models/exercise_guide.dart';
import '../models/user.dart';
import '../models/workout.dart';
import 'app_bottom_sheet.dart';
import 'app_calendar.dart';
import 'app_icon_box.dart';
import 'app_switch.dart';
import 'workout_parts.dart';

/// 종목 설명 시트 (시안 03-exercise-guide): 제목 + 닫기 → 설명 · 기록 · 설정 → 내용.
///
/// - 설명: 근육 그림(앞 · 뒤, 주 근육 주황 · 보조 연주황) → 도구 · 기록 · 난이도 3칸 → 근육 칩 → 운동 방법 → 출처.
///   직접 추가한 종목은 '설명이 없어요' 카드 + 부위 · 도구 · 기록 3칸.
/// - 기록: 최고 · 하루 최고 2칸 → 최근 5번 막대 → 지난 기록 줄 (회원의 지난 운동에서 계산).
/// - 설정: 운동 화면에서 열 때만 ([settings]) — 메모 · 휴식 시간 · 무게 칸 · 무게 단위 · 빼기.
///
/// 들어가는 곳: 종목 고르기 줄 끝 ⓘ(설명 · 기록), 운동 카드 이름(설명), 운동 카드 ⋯(설정).
/// 회원 운동 · 트레이너 PT 기록이 함께 쓴다.
Future<void> showExerciseGuideSheet(
  BuildContext context, {
  required String name,
  required WorkoutCategory category,
  required ExerciseHistory history,
  ExerciseGuideSettings Function()? settings,
  int initialTab = 0,
  Gender? gender,
}) {
  return showAppBottomSheet<void>(
    context: context,
    heightFactor: 0.9,
    padded: false,
    child: _ExerciseGuideSheet(
      name: name,
      category: category,
      history: history,
      settings: settings,
      initialTab: initialTab,
      gender: gender,
    ),
  );
}

/// 설정 탭에 보일 지금 값과 바꾸는 동작. 시트는 바꿀 때마다 [showExerciseGuideSheet]의
/// `settings`를 다시 불러 새 값을 그린다 (값은 운동 화면의 종목 초안이 가진다).
class ExerciseGuideSettings {
  final bool isCardio;

  /// 휴식 시간(초). null이면 줄을 두지 않는다 (트레이너 PT 기록).
  final int? restSeconds;
  final bool showWeight;
  final String unitLabel;
  final String note;
  final ValueChanged<int>? onRestChanged;
  final VoidCallback onToggleWeight;
  final VoidCallback onToggleUnit;
  final ValueChanged<String> onNoteChanged;

  /// '이 종목 빼기' — 시트를 닫은 뒤 부른다.
  final VoidCallback onRemove;

  const ExerciseGuideSettings({
    required this.isCardio,
    required this.showWeight,
    required this.unitLabel,
    required this.note,
    required this.onToggleWeight,
    required this.onToggleUnit,
    required this.onNoteChanged,
    required this.onRemove,
    this.restSeconds,
    this.onRestChanged,
  });
}

/// 한 종목의 지난 기록 요약 (기록 탭).
class ExerciseHistory {
  final ExerciseHistoryKind kind;

  /// 최근 기록부터.
  final List<ExerciseHistoryRow> rows;

  /// 두 칸: (이름, 값, 단위)
  final (String, String, String) best;
  final (String, String, String) bestDay;

  const ExerciseHistory._({
    required this.kind,
    required this.rows,
    required this.best,
    required this.bestDay,
  });

  static const empty = ExerciseHistory._(
    kind: ExerciseHistoryKind.weighted,
    rows: [],
    best: ('', '', ''),
    bestDay: ('', '', ''),
  );

  bool get isEmpty => rows.isEmpty;

  /// [workouts]는 최근 날짜부터 (`WorkoutService.getPreviousWorkouts` 순서).
  factory ExerciseHistory.fromWorkouts(
    String name,
    List<Workout> workouts, {
    required bool isCardio,
  }) {
    final key = name.trim();
    final found = <(String, Exercise)>[
      for (final w in workouts)
        for (final e in w.exercises)
          if (e.name.trim() == key && e.sets.isNotEmpty) (w.workoutDate, e),
    ];
    if (found.isEmpty) return empty;

    final kind = isCardio
        ? ExerciseHistoryKind.cardio
        : found.every((f) => f.$2.sets.every((s) => s.weight <= 0))
        ? ExerciseHistoryKind.bodyweight
        : ExerciseHistoryKind.weighted;
    final number = NumberFormat('#,##0');
    final count = strengthCountLabel(key);
    final metric = cardioPrimaryMetricLabel(key);
    final metricUnit = cardioPrimaryMetricSuffix(key);

    double maxOf(Iterable<double> v) => v.reduce((a, b) => a > b ? a : b);

    final rows = <ExerciseHistoryRow>[];
    var best = 0.0;
    var bestDay = 0.0;
    for (final (date, e) in found) {
      final sets = e.sets;
      final double dayValue;
      final String summary;
      final String value;
      switch (kind) {
        case ExerciseHistoryKind.weighted:
          final top = sets.reduce(
            (a, b) =>
                b.weight > a.weight || (b.weight == a.weight && b.reps > a.reps)
                ? b
                : a,
          );
          dayValue = e.totalVolume;
          best = best > top.weight ? best : top.weight;
          summary =
              '${sets.length}세트 · ${formatWeight(top.weight)}kg × ${top.reps}';
          value = '${number.format(dayValue.round())}kg';
        case ExerciseHistoryKind.bodyweight:
          final top = sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
          dayValue = sets.fold<int>(0, (sum, s) => sum + s.reps).toDouble();
          best = best > top ? best : top.toDouble();
          summary = '${sets.length}세트 · 최고 $top$count';
          value = '${dayValue.round()}$count';
        case ExerciseHistoryKind.cardio:
          final top = maxOf(sets.map((s) => s.weight));
          dayValue = sets.fold<int>(0, (sum, s) => sum + s.reps).toDouble();
          best = best > top ? best : top;
          summary = '$metric ${formatMetricValue(top)}$metricUnit';
          value = '${dayValue.round()}분';
      }
      bestDay = bestDay > dayValue ? bestDay : dayValue;
      rows.add(
        ExerciseHistoryRow(
          date: date,
          summary: summary,
          value: value,
          amount: dayValue,
        ),
      );
    }

    return ExerciseHistory._(
      kind: kind,
      rows: rows,
      best: switch (kind) {
        ExerciseHistoryKind.weighted => ('최고 무게', formatWeight(best), 'kg'),
        ExerciseHistoryKind.bodyweight => (
          '최고 ${count == '초' ? '시간' : '횟수'}',
          '${best.round()}',
          count,
        ),
        ExerciseHistoryKind.cardio => (
          '최고 $metric',
          formatMetricValue(best),
          metricUnit,
        ),
      },
      bestDay: switch (kind) {
        ExerciseHistoryKind.weighted => (
          '최고 볼륨 (하루)',
          number.format(bestDay.round()),
          'kg',
        ),
        ExerciseHistoryKind.bodyweight => (
          '하루 최고 ${count == '초' ? '합계' : '횟수'}',
          number.format(bestDay.round()),
          count,
        ),
        ExerciseHistoryKind.cardio => (
          '가장 오래',
          number.format(bestDay.round()),
          '분',
        ),
      },
    );
  }
}

enum ExerciseHistoryKind { weighted, bodyweight, cardio }

class ExerciseHistoryRow {
  final String date;
  final String summary;
  final String value;

  /// 막대 높이에 쓰는 하루 양 (볼륨 · 횟수 합 · 분).
  final double amount;

  const ExerciseHistoryRow({
    required this.date,
    required this.summary,
    required this.value,
    required this.amount,
  });
}

/// 설명 탭 '기록' 칸: 이 종목을 어떻게 적는지.
String _recordLabel(String name, bool isCardio) {
  if (isCardio) return '${cardioPrimaryMetricLabel(name)} · 분';
  if (isTimedExercise(name)) return '초';
  if (isBodyweightExercise(name)) return '횟수';
  return '무게 · 횟수';
}

class _ExerciseGuideSheet extends StatefulWidget {
  final String name;
  final WorkoutCategory category;
  final ExerciseHistory history;
  final ExerciseGuideSettings Function()? settings;
  final int initialTab;
  final Gender? gender;

  const _ExerciseGuideSheet({
    required this.name,
    required this.category,
    required this.history,
    required this.settings,
    required this.initialTab,
    required this.gender,
  });

  @override
  State<_ExerciseGuideSheet> createState() => _ExerciseGuideSheetState();
}

class _ExerciseGuideSheetState extends State<_ExerciseGuideSheet> {
  late int _tab = widget.initialTab.clamp(0, _tabs.length - 1);

  List<String> get _tabs => ['설명', '기록', if (widget.settings != null) '설정'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: AppBottomSheetHeader(title: widget.name, gap: AppSpacing.md),
        ),
        AppViewTabs(
          labels: _tabs,
          selectedIndex: _tab,
          onSelect: (i) {
            if (i != _tab) AppHaptics.selection();
            setState(() => _tab = i);
          },
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.base,
              AppSpacing.screenH,
              MediaQuery.of(context).padding.bottom + AppSpacing.xl,
            ),
            children: switch (_tab) {
              0 => _description(),
              1 => _historyTab(),
              _ => _settingsTab(),
            },
          ),
        ),
      ],
    );
  }

  bool get _isCardio => widget.category == WorkoutCategory.cardio;

  // ── 설명 ──

  List<Widget> _description() {
    final guide = ExerciseGuideData.of(widget.name);
    final record = _recordLabel(widget.name, _isCardio);
    if (guide == null) {
      return [
        const _EmptyInfo('직접 추가한 종목이라 설명이 없어요.'),
        const SizedBox(height: AppSpacing.base),
        _Facts([('부위', widget.category.label), ('도구', '—'), ('기록', record)]),
      ];
    }
    return [
      _MuscleCard(guide: guide, gender: widget.gender),
      const SizedBox(height: AppSpacing.base),
      _Facts([
        ('도구', guide.equipment.label),
        ('기록', record),
        ('난이도', guide.level.label),
      ]),
      const SizedBox(height: AppSpacing.base),
      _MuscleChips(label: '주 근육', muscles: guide.primary, main: true),
      const SizedBox(height: AppSpacing.sm),
      _MuscleChips(label: '보조', muscles: guide.secondary, main: false),
      const SizedBox(height: AppSpacing.lg),
      Text('운동 방법', style: AppTextStyles.section),
      const SizedBox(height: AppSpacing.md),
      for (var i = 0; i < guide.steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: AppTextStyles.bodyMd.bold.copyWith(
                    color: AppColors.mute,
                    height: 23 / 15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  guide.steps[i],
                  style: AppTextStyles.bodyMd.copyWith(height: 23 / 15),
                ),
              ),
            ],
          ),
        ),
      Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.only(top: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: AppColors.noticeBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '검수 전',
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.noticeText,
                      height: 18 / 11,
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: guide.source == null
                    ? '운동 방법은 REFIT이 썼어요.'
                    : "출처: free-exercise-db '${guide.source}' (공공 소유)를 우리말로 옮김",
              ),
            ],
          ),
          style: AppTextStyles.captionSmall.copyWith(height: 18 / 12),
        ),
      ),
    ];
  }

  // ── 기록 ──

  List<Widget> _historyTab() {
    final history = widget.history;
    if (history.isEmpty) {
      return const [_EmptyInfo('아직 이 종목 기록이 없어요.')];
    }
    final recent = history.rows.take(5).toList().reversed.toList();
    final top = recent
        .map((r) => r.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return [
      Row(
        children: [
          Expanded(child: _Kpi(history.best)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _Kpi(history.bestDay)),
        ],
      ),
      const SizedBox(height: AppSpacing.base),
      Semantics(
        label: '최근 ${recent.length}번 기록 막대',
        excludeSemantics: true,
        child: Container(
          height: 96,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.canvasCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 22),
                        height: top <= 0
                            ? 4
                            : (recent[i].amount / top * 56).clamp(4, 56),
                        decoration: BoxDecoration(
                          color: i == recent.length - 1
                              ? AppColors.primary
                              : AppColors.ink.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i == recent.length - 1 ? '최근' : '',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.mute,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('지난 기록', style: AppTextStyles.section),
      for (final row in history.rows.take(10)) _HistoryRow(row),
    ];
  }

  // ── 설정 ──

  List<Widget> _settingsTab() {
    final s = widget.settings!();
    void change(VoidCallback action) {
      action();
      setState(() {});
    }

    final note = s.note.trim();
    return [
      _SettingRow(
        icon: AppIcons.note,
        title: '메모',
        subtitle: note.isEmpty ? '자세, 느낌, 다음에 바꿀 점' : note,
        trailing: Icon(
          AppIcons.chevronRightBold,
          size: 18,
          color: AppColors.chevron,
        ),
        onTap: () async {
          final next = await showExerciseNoteSheet(
            context,
            exerciseName: widget.name,
            initial: s.note,
          );
          if (next == null || !mounted) return;
          change(() => s.onNoteChanged(next));
        },
      ),
      if (s.restSeconds != null && s.onRestChanged != null)
        _SettingRow(
          icon: AppIcons.timer,
          title: '휴식 시간',
          subtitle: '세트를 완료하면 시작',
          trailing: _Stepper(
            label: '${s.restSeconds}초',
            onMinus: s.restSeconds! > 15
                ? () => change(() => s.onRestChanged!(s.restSeconds! - 15))
                : null,
            onPlus: s.restSeconds! < 300
                ? () => change(() => s.onRestChanged!(s.restSeconds! + 15))
                : null,
          ),
        ),
      if (!s.isCardio)
        _SettingRow(
          icon: AppIcons.workout,
          title: '무게 칸',
          subtitle: s.showWeight ? '끄면 맨몸으로 횟수만 기록' : '켜면 중량을 더해 기록',
          trailing: AppSwitch(value: s.showWeight),
          onTap: () => change(s.onToggleWeight),
          toggled: s.showWeight,
        ),
      if (!s.isCardio && s.showWeight)
        _SettingRow(
          icon: AppIcons.swapUnit,
          title: '무게 단위',
          subtitle: '이 종목만',
          trailing: _UnitToggle(
            unit: s.unitLabel,
            onSelect: (unit) {
              if (unit != s.unitLabel) change(s.onToggleUnit);
            },
          ),
        ),
      Semantics(
        button: true,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            s.onRemove();
          },
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            height: 68,
            child: Center(
              child: Text(
                '이 종목 빼기',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────
// 작은 부품
// ─────────────────────────────────────────────

/// 근육 그림 카드: 앞 · 뒤가 한 그림(근육 그림 부품의 [Maps.BODY]) + 범례.
/// 주 근육 = 주황, 보조 = 연주황, 나머지 근육 = 회색. 회원이 여성이면 여성 몸 그림.
///
/// 부품은 크기를 폭으로만 맞추고 그림 하나만 기억하므로(전역), 앞 · 뒤를 따로 두 개 그리지 않고
/// 둘이 함께 있는 그림 하나를 카드 폭에 맞춘다. 칠하지 않은 근육은 테두리만 그리므로
/// 나머지 근육도 '없음' 세기로 넘겨 회색으로 채운다.
class _MuscleCard extends StatelessWidget {
  final ExerciseGuide guide;
  final Gender? gender;

  const _MuscleCard({required this.guide, required this.gender});

  static const _allGroups = [
    'chest', 'shoulders', 'obliques', 'abs', 'abductor', 'biceps', 'calves', //
    'forearm', 'glutes', 'harmstrings', 'lats', 'upper_back', 'quads',
    'trapezius', 'triceps', 'adductors', 'lower_back', 'neck',
  ];

  /// 그림 높이 ÷ 폭 (앞 · 뒤 함께 있는 그림, 남녀 같은 비율).
  static const _aspect = 285 / 350;

  static Color get _secondary =>
      AppColors.isLight ? const Color(0xFFFFC7A3) : const Color(0xFF8A4A26);

  @override
  Widget build(BuildContext context) {
    final female = gender == Gender.female;
    final groups = <String, MuscleIntensity>{
      for (final m in _allGroups) m: MuscleIntensity.none,
      for (final m in guide.secondary) m: MuscleIntensity.light,
      for (final m in guide.primary) m: MuscleIntensity.hard,
    };
    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
    final muscles = [
      ...guide.primary.map(muscleLabel),
      ...guide.secondary.map(muscleLabel),
    ].join(', ');
    return Semantics(
      label: '근육 그림: $muscles',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return SizedBox(
                  width: width,
                  height: width * _aspect,
                  child: IgnorePointer(
                    child: MuscleIntensityMap(
                      map: female ? Maps.FEMALE_BODY : Maps.BODY,
                      width: width,
                      height: width * _aspect,
                      onChanged: (_) {},
                      initialSelectedGroups: groups,
                      strokeColor: AppColors.canvasCard,
                      strokeWidth: 0.8,
                      skeletonColor: AppColors.track,
                      intensityColorBuilder: (intensity) => switch (intensity) {
                        MuscleIntensity.hard => AppColors.primary,
                        MuscleIntensity.light ||
                        MuscleIntensity.medium => _secondary,
                        MuscleIntensity.none => AppColors.canvasMid,
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '앞',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    '뒤',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                legend(AppColors.primary, '주로 쓰는 근육'),
                const SizedBox(width: 14),
                legend(_secondary, '함께 쓰는 근육'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 3칸 요약 (회색 카드, 칸 사이 세로선).
class _Facts extends StatelessWidget {
  final List<(String, String)> items;

  const _Facts(this.items);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.line,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      Text(items[i].$1, style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.listTitle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MuscleChips extends StatelessWidget {
  final String label;
  final List<String> muscles;
  final bool main;

  const _MuscleChips({
    required this.label,
    required this.muscles,
    required this.main,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.mute),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: muscles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('없음', style: AppTextStyles.bodySm),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in muscles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: main
                              ? AppColors.noticeBg
                              : AppColors.canvasSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          muscleLabel(m),
                          style: AppTextStyles.caption.copyWith(
                            color: main ? AppColors.noticeText : AppColors.ink,
                            fontWeight: main ? FontWeight.w500 : null,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  final String text;

  const _EmptyInfo(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(text, textAlign: TextAlign.center, style: AppTextStyles.note),
    );
  }
}

class _Kpi extends StatelessWidget {
  final (String, String, String) value;

  const _Kpi(this.value);

  @override
  Widget build(BuildContext context) {
    final (label, number, unit) = value;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: number),
                TextSpan(
                  text: unit.isEmpty ? '' : ' $unit',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                ),
              ],
            ),
            style: AppTextStyles.sheetTitle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ExerciseHistoryRow row;

  const _HistoryRow(this.row);

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(row.date);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date == null ? row.date : DateFormat('M.d').format(date),
                  style: AppTextStyles.listTitle,
                ),
                if (date != null)
                  Text(
                    DateFormat('E', 'ko').format(date),
                    style: AppTextStyles.captionSmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              row.summary,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
          ),
          Text(
            row.value,
            style: AppTextStyles.bodyMd.medium.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 설정 줄 (68): 40 아이콘 상자 + 제목 16/500 · 보조 13 + 오른쪽 조절.
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool? toggled;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          AppIconBox(icon: icon, background: AppColors.canvasCard),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.listTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      toggled: toggled,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: row,
      ),
    );
  }
}

/// − 90초 + (원 36, 15초씩).
class _Stepper extends StatelessWidget {
  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _Stepper({required this.label, this.onMinus, this.onPlus});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String semantic, VoidCallback? onTap) =>
        Semantics(
          button: true,
          enabled: onTap != null,
          label: semantic,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap == null
                ? null
                : () {
                    AppHaptics.light();
                    onTap();
                  },
            child: SizedBox.square(
              dimension: AppSize.touchMin,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.canvasSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: onTap == null ? AppColors.faint : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(AppIcons.remove, '15초 줄이기', onMinus),
        SizedBox(
          width: 52,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.listTitle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        button(AppIcons.add, '15초 늘리기', onPlus),
      ],
    );
  }
}

/// kg | lbs 알약 (고른 쪽 검정 채움).
class _UnitToggle extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onSelect;

  const _UnitToggle({required this.unit, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in const ['kg', 'lbs'])
            Semantics(
              button: true,
              selected: u == unit,
              child: GestureDetector(
                onTap: () => onSelect(u),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: u == unit ? AppColors.ink : null,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    u,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: u == unit ? AppColors.canvas : AppColors.body,
                      fontWeight: u == unit ? FontWeight.w500 : null,
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
