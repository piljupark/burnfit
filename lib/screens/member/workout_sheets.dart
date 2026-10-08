import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/exercise_data.dart';
import '../../models/custom_exercise.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/workout_parts.dart';
import 'workout_draft_models.dart';

/// 운동 추가 시트 (시안 MemA-Sheet-ExercisePicker / ExerciseSearch).
/// 좌우 20 · 머리 아래 12 · 검색창 48 · 칩 40(위아래 12) · 시트 폭 구분선 ·
/// 줄 최소 60(이름 16/500, 부위 13 body, 오른쪽 '지난 100kg' 13 body, 줄마다 아래 선).
class ExercisePickerSheet extends StatefulWidget {
  final String memberId;
  final WorkoutCategory defaultCategory;
  final List<CustomExercise> customExercises;
  final Map<String, PreviousExerciseStats> previousStatsByName;
  final void Function(CustomExercise exercise) onCustomAdded;

  const ExercisePickerSheet({
    super.key,
    required this.memberId,
    required this.defaultCategory,
    required this.customExercises,
    required this.previousStatsByName,
    required this.onCustomAdded,
  });

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _searchController = TextEditingController();
  WorkoutCategory? _selectedCategory;
  bool _addingCustom = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.defaultCategory;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PickedExercise> get _items {
    final query = _searchController.text.trim().toLowerCase();

    final defaults = <PickedExercise>[];

    for (final entry in ExerciseData.exercises.entries) {
      if (_selectedCategory != null && entry.key != _selectedCategory) continue;

      for (final name in entry.value) {
        defaults.add(PickedExercise(name: name, category: entry.key));
      }
    }

    final customs = widget.customExercises
        .where((exercise) {
          if (_selectedCategory != null &&
              exercise.category != _selectedCategory) {
            return false;
          }
          return true;
        })
        .map(
          (exercise) => PickedExercise(
            name: exercise.name,
            category: exercise.category,
            custom: true,
          ),
        );

    final all = [...defaults, ...customs];

    if (query.isEmpty) return all;

    return all
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  /// 같은 이름(대소문자 무시)이 기본 운동·직접 추가한 운동의 어느 부위에도 없을 때만 새로 추가한다.
  bool get _canAddCustom {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return false;

    final defaults = ExerciseData.exercises.values.expand((names) => names);
    final customs = widget.customExercises.map((exercise) => exercise.name);
    return ![
      ...defaults,
      ...customs,
    ].any((name) => name.trim().toLowerCase() == query);
  }

  Future<void> _addCustom() async {
    if (_addingCustom) return;

    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    // '전체'에서는 어느 부위로 넣을지 알 수 없으므로 부위를 먼저 고르게 한다.
    final category = _selectedCategory;
    if (category == null) {
      AppFeedback.showWarning(context, '부위를 먼저 고른 뒤 새 운동으로 추가하세요.');
      return;
    }

    setState(() => _addingCustom = true);

    try {
      final exercise = await ExerciseService.addCustomExercise(
        memberId: widget.memberId,
        name: name,
        category: category,
      );

      widget.onCustomAdded(exercise);

      if (!mounted) return;

      Navigator.of(context).pop(
        PickedExercise(
          name: exercise.name,
          category: exercise.category,
          custom: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _addingCustom = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final categories = WorkoutCategory.values;
    final selectedChip = _selectedCategory == null
        ? 0
        : categories.indexOf(_selectedCategory!) + 1;
    final labels = ['전체', ...categories.map((category) => category.label)];
    final hasQuery = _searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppBottomSheetHeader(title: '운동 추가', gap: AppSpacing.md),
              AppTextField(
                label: '',
                hint: '운동명 검색 또는 직접 입력',
                controller: _searchController,
                prefix: Icon(
                  AppIcons.search,
                  color: hasQuery ? AppColors.ink : AppColors.mute,
                ),
                // 시안 ExerciseSearch: 입력 중이면 오른쪽 28 회색 원 지우기
                suffix: hasQuery
                    ? _ClearButton(onTap: _searchController.clear)
                    : null,
                textInputAction: TextInputAction.search,
              ),
            ],
          ),
        ),
        // 칩 줄: 위아래 12 (큰 칩은 위아래 2 터치 여백을 스스로 둔다)
        AppScrollableChips(
          labels: labels,
          selectedIndex: selectedChip,
          large: true,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            10,
            AppSpacing.screenH,
            _canAddCustom ? 0 : 10,
          ),
          onSelected: (i) => setState(() {
            _selectedCategory = i == 0 ? null : categories[i - 1];
          }),
        ),
        if (_canAddCustom)
          // 시안 `rise`: 아래 8에서 올라오며 나타남 (.35s)
          AppEntrance(
            offset: const Offset(0, 8),
            duration: const Duration(milliseconds: 350),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: _DashedAddButton(
                label: '"${_searchController.text.trim()}" 새 운동으로 추가',
                loading: _addingCustom,
                onTap: _addingCustom ? null : _addCustom,
              ),
            ),
          ),
        const AppRowDivider(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              final previous = widget.previousStatsByName[item.name];

              return WorkoutPickerRow(
                name: item.name,
                category: item.category,
                custom: item.custom,
                previous: previous == null
                    ? null
                    : previousRecordLabel(
                        name: item.name,
                        isCardio: item.category == WorkoutCategory.cardio,
                        maxValue: previous.maxWeight,
                      ),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 검색어 지우기: 28 회색 원(#D4D4D8) + 흰 x 12.
class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '지우기',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: AppSize.touchMin,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.outline,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.closeBold,
                size: 12,
                color: AppColors.canvas,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// '"와이드" 새 운동으로 추가': 52 높이 · 반경 14 · 1.5 점선(#D4D4D8) · + 16 · 15/500.
class _DashedAddButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _DashedAddButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: CustomPaint(
          painter: WorkoutDashedBorderPainter(
            color: AppColors.outline,
            radius: AppRadius.field,
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  AppLoader.inline(color: AppColors.ink)
                else
                  Icon(
                    AppIcons.bold(AppIcons.add),
                    size: 16,
                    color: AppColors.ink,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 둥근 사각형 점선 (선 1.5, 대시 4.5 · 간격 4.5 — 브라우저 1.5px dashed와 같은 비율).
class WorkoutDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const WorkoutDashedBorderPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(stroke / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4.5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(WorkoutDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// 운동 메뉴 시트 (시안 MemA-Sheet-ExerciseMenu): 제목 22/500 + 보조 14 mute, 아래 12 띄우고
/// 60 높이 행동 줄 셋(40 아이콘 상자). 위 두 줄 아래에만 선. 모양은 [WorkoutExerciseMenuSheet].
class ExerciseMenuSheet extends StatelessWidget {
  final WorkoutExerciseDraft exercise;

  const ExerciseMenuSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return WorkoutExerciseMenuSheet(
      name: exercise.name,
      category: exercise.category,
      isCardio: exercise.isCardio,
      unitLabel: exercise.unit.label,
      nextUnitLabel: exercise.unit == WeightUnit.kg ? 'lbs' : 'kg',
      onToggleUnit: () => Navigator.of(
        context,
      ).pop(const ExerciseMenuAction(type: ExerciseMenuActionType.toggleUnit)),
      extraActions: [
        AppSheetAction(
          icon: AppIcons.timer,
          label: '휴식 타이머',
          value: '${exercise.restSeconds}초',
          chevron: true,
          onTap: () async {
            final seconds = await showAppBottomSheet<int>(
              context: context,
              child: RestTimerSheet(initialSeconds: exercise.restSeconds),
            );

            if (seconds == null || !context.mounted) return;

            Navigator.of(context).pop(
              ExerciseMenuAction(
                type: ExerciseMenuActionType.restTimer,
                restSeconds: seconds,
              ),
            );
          },
        ),
      ],
      onDelete: () => Navigator.of(
        context,
      ).pop(const ExerciseMenuAction(type: ExerciseMenuActionType.delete)),
    );
  }
}

/// 휴식 타이머 시트 (시안 MemA-Sheet-RestTimer): 제목 옆 주황 시계(바늘이 돎) + 보조 14 mute,
/// 아래 20 띄우고 3열 칸(높이 52, 반경 14, 사이 8). 고른 칸은 검정 채움 + 흰 500.
class RestTimerSheet extends StatelessWidget {
  final int initialSeconds;

  const RestTimerSheet({super.key, required this.initialSeconds});

  @override
  Widget build(BuildContext context) {
    final options = [30, 45, 60, 90, 120, 180];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(
          title: '휴식 타이머',
          subtitle: '운동별 기본 휴식 시간을 설정합니다.',
          mutedSubtitle: true,
          gap: AppSpacing.lg,
          trailingTitle: _TickingClock(),
        ),
        GridView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 52,
          ),
          children: [
            for (final seconds in options)
              _RestOption(
                label: '$seconds초',
                selected: seconds == initialSeconds,
                onTap: () => Navigator.of(context).pop(seconds),
              ),
          ],
        ),
      ],
    );
  }
}

/// 휴식 시간 칸 (높이 52, 반경 14). 고른 칸 = ink 채움 + canvas 글자 500, 나머지 = canvasSoft 채움.
class _RestOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RestOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.ink : AppColors.canvasSoft,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          highlightColor: AppColors.canvasMid,
          splashFactory: NoSplash.splashFactory,
          child: Center(
            child: Text(
              label,
              style: selected
                  ? AppTextStyles.input.medium.copyWith(color: AppColors.canvas)
                  : AppTextStyles.input,
            ),
          ),
        ),
      ),
    );
  }
}

/// 제목 옆 주황 시계 22 (선 2): 바늘이 4초에 한 바퀴 돈다 (시안 `tick`).
class _TickingClock extends StatefulWidget {
  const _TickingClock();

  @override
  State<_TickingClock> createState() => _TickingClockState();
}

class _TickingClockState extends State<_TickingClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: const Size.square(22),
          painter: _ClockPainter(
            angle: _controller.value * 2 * math.pi,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// 시안 SVG(viewBox 24): 원(12,13 r8) + 바늘(12,13 → 12,8.5) + 위 꼭지(10,2 → 14,2), 선 2.
class _ClockPainter extends CustomPainter {
  final double angle;
  final Color color;

  const _ClockPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(12, 13), 8, paint);
    canvas.drawLine(const Offset(10, 2), const Offset(14, 2), paint);
    canvas.save();
    canvas.translate(12, 13);
    canvas.rotate(angle);
    canvas.drawLine(Offset.zero, const Offset(0, -4.5), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.color != color;
}
