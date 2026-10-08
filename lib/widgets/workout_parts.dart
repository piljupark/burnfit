import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/exercise_data.dart';
import '../models/custom_exercise.dart';
import '../models/workout.dart';
import 'app_action_row.dart';
import 'app_bottom_sheet.dart';
import 'app_motion.dart';

/// 회원 운동 · 트레이너 PT 기록이 함께 쓰는 운동 부품과 계산.
///
/// 회원·트레이너 화면의 모양 차이(높이·굵기·색)는 매개변수로 남긴다. 기본값은 회원 화면 모양.

// ─────────────────────────────────────────────
// 계산
// ─────────────────────────────────────────────

/// 1kg = 2.2046226218lbs.
const double kLbsPerKg = 2.2046226218;

String formatMetricValue(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String formatWeight(double value) => formatMetricValue(value);

/// 저장할 무게(kg)는 소수 둘째 자리까지 반올림한다 (lbs 환산의 끝자리 오차 제거).
double roundWeightKg(double value) => (value * 100).roundToDouble() / 100;

/// 유산소 종목의 주 지표 이름 (속도·경사·강도·레벨·거리·횟수).
String cardioPrimaryMetricLabel(String name) {
  final n = name.replaceAll(' ', '');
  if (n.contains('러닝머신') || n.contains('인터벌') || n.contains('조깅')) return '속도';
  if (n.contains('인클라인')) return '경사';
  if (n.contains('사이클') || n.contains('싸이클')) return '강도';
  if (n.contains('스텝밀') || n.contains('천국의계단')) return '레벨';
  if (n.contains('일립티컬')) return '강도';
  if (n.contains('로잉')) return '거리';
  if (n.contains('줄넘기') || n.contains('버피')) return '횟수';
  return '강도';
}

/// 유산소 주 지표의 단위 (없으면 빈 글자).
String cardioPrimaryMetricSuffix(String name) {
  switch (cardioPrimaryMetricLabel(name)) {
    case '속도':
      return 'km/h';
    case '경사':
      return '%';
    case '거리':
      return 'm';
    case '횟수':
      return '회';
    default:
      return '';
  }
}

/// 종목 이름으로 부위를 찾는다: 기본 운동 목록 → 직접 추가한 운동 순. 못 찾으면 null.
///
/// 기록(Workout)에는 부위가 하나만 저장되므로, 여러 부위가 섞인 기록에서
/// 종목마다 유산소인지 가릴 때 쓴다.
WorkoutCategory? exerciseCategoryOf(
  String name, {
  Iterable<CustomExercise> customExercises = const [],
}) {
  final key = name.trim();
  for (final entry in ExerciseData.exercises.entries) {
    if (entry.value.contains(key)) return entry.key;
  }
  final lower = key.toLowerCase();
  for (final custom in customExercises) {
    if (custom.name.trim().toLowerCase() == lower) return custom.category;
  }
  return null;
}

/// 종목 이름으로 찾은 부위가 유산소인지 (못 찾으면 [fallback] 부위로 판단).
bool isCardioExercise(
  String name,
  WorkoutCategory fallback, {
  Iterable<CustomExercise> customExercises = const [],
}) {
  final category =
      exerciseCategoryOf(name, customExercises: customExercises) ?? fallback;
  return category == WorkoutCategory.cardio;
}

/// 저장된 기록의 근력 볼륨(kg). 유산소 종목(속도 × 분)은 빼고 종목마다 판단한다.
double workoutStrengthVolumeKg(
  Workout workout, {
  Iterable<CustomExercise> customExercises = const [],
}) {
  var volume = 0.0;
  for (final exercise in workout.exercises) {
    if (isCardioExercise(
      exercise.name,
      workout.category,
      customExercises: customExercises,
    )) {
      continue;
    }
    volume += exercise.totalVolume;
  }
  return volume;
}

/// 저장된 기록이 모두 유산소 종목인지 (종목마다 판단).
bool workoutIsAllCardio(
  Workout workout, {
  Iterable<CustomExercise> customExercises = const [],
}) {
  return workout.exercises.isNotEmpty &&
      workout.exercises.every(
        (e) => isCardioExercise(
          e.name,
          workout.category,
          customExercises: customExercises,
        ),
      );
}

/// 유산소 종목 한 줄 요약: '속도 8km/h · 30분'.
String cardioExerciseSummary(Exercise exercise) {
  final metricLabel = cardioPrimaryMetricLabel(exercise.name);
  final metricSuffix = cardioPrimaryMetricSuffix(exercise.name);
  final primaryMax = exercise.sets.isEmpty
      ? 0.0
      : exercise.sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  final minutes = exercise.sets.fold<int>(0, (sum, s) => sum + s.reps);
  return '$metricLabel ${formatMetricValue(primaryMax)}$metricSuffix · $minutes분';
}

/// 근력 종목 한 줄 요약: '4세트' 또는 [showMax]면 '4세트 · 최고 120kg' (맨몸이면 '맨몸').
String strengthExerciseSummary(Exercise exercise, {bool showMax = false}) {
  final count = '${exercise.sets.length}세트';
  if (!showMax || exercise.sets.isEmpty) return count;
  final max = exercise.sets
      .map((s) => s.weight)
      .reduce((a, b) => a > b ? a : b);
  if (max <= 0) return '$count · 맨몸';
  return '$count · 최고 ${formatWeight(max)}kg';
}

/// 운동 고르기 줄 오른쪽 '지난 기록' 글자. 유산소는 그 종목의 지표 단위로 ('지난 속도 8km/h').
String previousRecordLabel({
  required String name,
  required bool isCardio,
  required double maxValue,
}) {
  if (isCardio) {
    final label = cardioPrimaryMetricLabel(name);
    return '지난 $label ${formatMetricValue(maxValue)}${cardioPrimaryMetricSuffix(name)}';
  }
  if (maxValue <= 0) return '지난 맨몸';
  return '지난 ${formatWeight(maxValue)}kg';
}

/// 무게 단위(kg↔lbs)를 바꿀 때 쓰는 기억 칸 (세트마다 하나).
///
/// 바꾼 뒤 글자를 손대지 않았으면 다시 바꿀 때 원래 글자로 되돌리고, 저장할 때도 원래 값을 쓴다.
/// 그래서 kg → lbs → kg 왕복에서 소수 오차가 쌓이지 않는다.
class WeightToggleMemo {
  /// 바꾸기 전 글자 (반대 단위)
  String? original;

  /// 바꾼 뒤 보여 준 글자
  String? converted;

  /// 단위를 바꾼 무게 글자. [toLbs]면 kg → lbs.
  String toggle(String text, {required bool toLbs}) {
    final current = text.trim();
    if (converted != null && original != null && current == converted) {
      final restored = original!;
      original = current;
      converted = restored;
      return restored;
    }
    final value = double.tryParse(current);
    if (value == null) {
      original = null;
      converted = null;
      return text;
    }
    final next = formatWeight(toLbs ? value * kLbsPerKg : value / kLbsPerKg);
    original = current;
    converted = next;
    return next;
  }

  /// 지금 글자가 손대지 않은 변환 결과이면 바꾸기 전 값(반대 단위)을 돌려준다.
  double? originalFor(String text) {
    if (converted == null || original == null) return null;
    if (text.trim() != converted) return null;
    return double.tryParse(original!);
  }
}

/// 세트 무게 글자를 kg으로 바꿔 저장 값으로 만든다 (비면 0 — 맨몸 운동).
double weightTextToKg(
  String text, {
  required bool lbs,
  WeightToggleMemo? memo,
}) {
  final value = double.tryParse(text.trim()) ?? 0;
  if (!lbs) return roundWeightKg(value);
  final original = memo?.originalFor(text);
  if (original != null) return roundWeightKg(original);
  return roundWeightKg(value / kLbsPerKg);
}

/// 키프레임 사이를 [curve]로 잇는다 (CSS처럼 구간마다 가속 곡선을 다시 적용).
double keyframeValue(double t, List<(double, double)> frames, Curve curve) {
  for (var i = 0; i < frames.length - 1; i++) {
    final (t0, v0) = frames[i];
    final (t1, v1) = frames[i + 1];
    if (t <= t1) {
      if (t1 == t0) return v1;
      final p = curve.transform(((t - t0) / (t1 - t0)).clamp(0.0, 1.0));
      return v0 + (v1 - v0) * p;
    }
  }
  return frames.last.$2;
}

// ─────────────────────────────────────────────
// 요약 칸
// ─────────────────────────────────────────────

class WorkoutStat {
  final String label;
  final String value;
  final String? suffix;

  const WorkoutStat(this.label, this.value, [this.suffix]);
}

/// 운동 요약 칸 줄 (회색 칸, 사이 8, 좌우 20). 라벨 12 + 값(단위는 400 mute).
/// 시안 `up`: 칸마다 .08s 늦게 아래 10에서 올라오며 나타남.
///
/// 회원(기본): 위 8 · 안쪽 16 14 · 반경 16 · 라벨 caption · 값 20/700.
/// 트레이너: 위 16 · 안쪽 14 12 · 반경 14 · 라벨 mute(한 줄) · 값 18/500.
class WorkoutSummaryStats extends StatelessWidget {
  final List<WorkoutStat> stats;
  final double top;
  final EdgeInsetsGeometry cellPadding;
  final double radius;

  /// 라벨 색 (null이면 기준 시안 캡션 회색)
  final Color? labelColor;
  final int? labelMaxLines;

  /// 값 글자 (null이면 회원 모양 20/700, 줄 높이 24)
  final TextStyle? valueStyle;

  const WorkoutSummaryStats({
    super.key,
    required this.stats,
    this.top = AppSpacing.sm,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius = 16,
    this.labelColor,
    this.labelMaxLines,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final value =
        valueStyle ?? AppTextStyles.title.bold.copyWith(height: 24 / 20);
    Widget cell(int order, WorkoutStat stat) {
      return Expanded(
        child: AppEntrance(
          delay: Duration(milliseconds: 80 * order),
          child: Semantics(
            label: '${stat.label} ${stat.value}${stat.suffix ?? ''}',
            excludeSemantics: true,
            child: Container(
              padding: cellPadding,
              decoration: BoxDecoration(
                color: AppColors.canvasCard,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.label,
                    maxLines: labelMaxLines,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: labelColor ?? AppColors.caption,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: stat.value),
                        if (stat.suffix != null)
                          TextSpan(
                            text: stat.suffix,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.mute,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        top,
        AppSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            cell(i, stats[i]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 접힌 운동 줄
// ─────────────────────────────────────────────

/// 접힌 운동 한 줄 (회색, 반경 20, 좌우 20 바깥 여백, 안쪽 좌우 20).
///
/// 회원(기본): 높이 60 · 이름 16/700 · 오른쪽 상태 13 caption.
/// 트레이너: 높이 64 · 이름 16/500 + 아래 보조 줄 13 mute · 오른쪽 아래 화살표 18.
class WorkoutCollapsedRow extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final double height;

  /// 이름 글자 (null이면 16/700)
  final TextStyle? nameStyle;

  /// 이름 아래 보조 줄 (트레이너)
  final String? subtitle;

  /// 오른쪽 끝 상태 글자 (회원)
  final String? trailing;

  /// 오른쪽 끝 아래 화살표 (트레이너)
  final bool chevron;

  /// 눌림 면 (null이면 기본)
  final Color? highlightColor;

  const WorkoutCollapsedRow({
    super.key,
    required this.name,
    required this.onTap,
    this.height = 60,
    this.nameStyle,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final summary = subtitle ?? trailing;
    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle ?? AppTextStyles.listTitle.bold,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Semantics(
        button: true,
        label: summary == null ? '$name, 펼치기' : '$name, $summary, 펼치기',
        excludeSemantics: true,
        child: Material(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: highlightColor,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: subtitle == null
                        ? nameText
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              nameText,
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm.natural,
                              ),
                            ],
                          ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.caption,
                      ),
                    ),
                  if (chevron) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      AppIcons.bold(AppIcons.chevronDown),
                      size: 18,
                      color: AppColors.chevron,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 운동 고르기 줄
// ─────────────────────────────────────────────

/// 운동 고르기 목록 한 줄: 좌우 20 안쪽, 아래 hairline. 이름 16/500 + 부위 13(위 2),
/// 오른쪽 '지난 기록' 글자.
///
/// 회원(기본): 최소 60 · 부위 body · 오른쪽 13 body.
/// 트레이너: 최소 64 · 부위 mute · 오른쪽 14 body.
class WorkoutPickerRow extends StatelessWidget {
  final String name;
  final WorkoutCategory category;
  final bool custom;

  /// 오른쪽 '지난 75kg' (없으면 null)
  final String? previous;
  final VoidCallback onTap;
  final double minHeight;
  final Color? subtitleColor;
  final TextStyle? previousStyle;

  const WorkoutPickerRow({
    super.key,
    required this.name,
    required this.category,
    required this.custom,
    required this.previous,
    required this.onTap,
    this.minHeight = 60,
    this.subtitleColor,
    this.previousStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.listTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        custom ? '${category.label} · 직접 추가' : category.label,
                        style: AppTextStyles.bodySm.copyWith(
                          color: subtitleColor ?? AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                if (previous != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    previous!,
                    style:
                        previousStyle ??
                        AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 운동 메뉴 시트
// ─────────────────────────────────────────────

/// 운동 메뉴 시트 (시안 MemA-Sheet-ExerciseMenu · Tr-ExerciseMenu): 제목 22/500 + 보조 14 mute,
/// 아래 12 띄우고 60 행동 줄들(40 아이콘 상자). 파괴적 줄(운동 삭제)은 맨 아래.
/// 유산소 종목은 무게가 없으므로 '무게 단위 변경'을 두지 않는다.
class WorkoutExerciseMenuSheet extends StatelessWidget {
  final String name;
  final WorkoutCategory category;
  final bool isCardio;
  final String unitLabel;
  final String nextUnitLabel;
  final VoidCallback onToggleUnit;

  /// 단위 변경과 삭제 사이에 둘 행동 줄 (회원 '휴식 타이머')
  final List<Widget> extraActions;
  final VoidCallback onDelete;

  const WorkoutExerciseMenuSheet({
    super.key,
    required this.name,
    required this.category,
    required this.isCardio,
    required this.unitLabel,
    required this.nextUnitLabel,
    required this.onToggleUnit,
    required this.onDelete,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: name,
          subtitle: isCardio
              ? category.label
              : '${category.label} · 현재 단위 $unitLabel',
          mutedSubtitle: true,
          gap: AppSpacing.md,
        ),
        if (!isCardio) ...[
          AppSheetAction(
            icon: AppIcons.swapUnit,
            label: '무게 단위 변경',
            value: '$unitLabel → $nextUnitLabel',
            onTap: onToggleUnit,
          ),
          const AppRowDivider(),
        ],
        for (final action in extraActions) ...[action, const AppRowDivider()],
        AppSheetAction(
          icon: AppIcons.trash,
          label: '운동 삭제',
          destructive: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 저장된 기록의 운동 줄
// ─────────────────────────────────────────────

/// 저장된 기록 안 운동 한 줄: 이름(왼쪽) + 요약 13 mute(오른쪽, 글자 아래선 맞춤).
/// 유산소는 '속도 8km/h · 30분', 근력은 '4세트'(트레이너는 '4세트 · 최고 120kg').
///
/// 회원(기본): 이름 15 · 사이 8. 트레이너: 이름 15/500 · 사이 12 · [showMax].
class WorkoutSavedExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final bool isCardio;
  final TextStyle? nameStyle;
  final double gap;
  final bool showMax;

  const WorkoutSavedExerciseRow({
    super.key,
    required this.exercise,
    required this.isCardio,
    this.nameStyle,
    this.gap = AppSpacing.sm,
    this.showMax = false,
  });

  @override
  Widget build(BuildContext context) {
    final detail = isCardio
        ? cardioExerciseSummary(exercise)
        : strengthExerciseSummary(exercise, showMax: showMax);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            exercise.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle ?? AppTextStyles.bodyMd.natural,
          ),
        ),
        SizedBox(width: gap),
        Text(detail, style: AppTextStyles.bodySm.natural),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 완료 화면 (회원 운동 완료 · 트레이너 PT 완료)
// ─────────────────────────────────────────────

/// 완료 화면 맨 아래 검정 60 pill '확인' (주황 바탕 위라 두 테마 공통 라이트 색).
class DoneConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DoneConfirmButton({super.key, this.label = '확인', required this.onTap});

  @override
  Widget build(BuildContext context) {
    final light = AppPalette.light;
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: Material(
        color: light.ink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.section.bold.copyWith(color: light.canvas),
            ),
          ),
        ),
      ),
    );
  }
}

/// 완료 화면의 글자 단추 (높이 44, 좌우 12, 라이트 ink).
/// 기본은 15/700 (+ [chevron]이면 오른쪽 굵은 화살표 16), [underline]이면 14 밑줄 링크.
class DoneTextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool chevron;
  final bool underline;

  const DoneTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.chevron = false,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppPalette.light.ink;
    final style = underline
        ? AppTextStyles.fieldLabel.copyWith(
            color: ink,
            decoration: TextDecoration.underline,
            decorationColor: ink,
          )
        : AppTextStyles.bodyMd.bold.copyWith(color: ink);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          height: AppSize.touchMin,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: style),
              if (chevron) ...[
                const SizedBox(width: 2),
                Icon(AppIcons.chevronRightBold, size: 16, color: ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
