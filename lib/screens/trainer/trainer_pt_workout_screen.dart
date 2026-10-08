import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/custom_exercise.dart';
import '../../models/feedback.dart' as fb;
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import 'trainer_exercise_input.dart';
import 'trainer_pt_done_screen.dart';
import 'trainer_saved_card.dart';
import 'trainer_workout_models.dart';
import 'trainer_workout_sheets.dart';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class TrainerPtWorkoutScreen extends StatefulWidget {
  final PtSession session;
  final AppUser member;

  const TrainerPtWorkoutScreen({
    super.key,
    required this.session,
    required this.member,
  });

  @override
  State<TrainerPtWorkoutScreen> createState() => _TrainerPtWorkoutScreenState();
}

class _TrainerPtWorkoutScreenState extends State<TrainerPtWorkoutScreen> {
  final _noteController = TextEditingController();
  final List<TrainerExerciseDraft> _exercises = [];

  List<Workout> _savedWorkouts = [];
  List<CustomExercise> _customExercises = [];
  List<Workout> _previousWorkouts = [];

  WorkoutCategory _defaultCategory = WorkoutCategory.chest;
  String? _editingWorkoutId;

  /// 펼쳐 보이는(현재) 운동 위치. 화면 표시 전용 상태다.
  int _focusedIndex = 0;

  bool _loading = false;
  bool _saving = false;
  String? _errorMessage;

  // 운동 시간은 기록하지 않는다 (회원 운동일지와 같은 기준). 세션 시각·길이는 예약 정보로 보여준다.

  String get _workoutDate =>
      DateFormat('yyyy-MM-dd').format(widget.session.scheduledAt);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Data ──

  Future<void> _load() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        WorkoutService.getWorkoutsByDate(
          widget.member.centerId,
          widget.member.uid,
          _workoutDate,
          workoutType: WorkoutType.pt,
          ptTrainerId: trainer.uid,
        ),
        WorkoutService.getPreviousWorkouts(
          centerId: widget.member.centerId,
          memberId: widget.member.uid,
          beforeDate: _workoutDate,
          workoutType: WorkoutType.pt,
          ptTrainerId: trainer.uid,
        ),
        ExerciseService.getCustomExercises(trainer.uid),
      ]);

      if (!mounted) return;
      setState(() {
        _savedWorkouts = results[0] as List<Workout>;
        _previousWorkouts = results[1] as List<Workout>;
        _customExercises = results[2] as List<CustomExercise>;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Session state ──

  bool get _hasContent =>
      _exercises.isNotEmpty || _noteController.text.trim().isNotEmpty;

  int get _completedSetCount =>
      _exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.done).length);

  int get _totalSetCount => _exercises.fold(0, (sum, e) => sum + e.sets.length);

  double get _sessionVolume =>
      _exercises.fold(0.0, (sum, e) => sum + e.totalVolume);

  bool get _isCardioSession =>
      _exercises.isNotEmpty && _exercises.every((e) => e.isCardio);

  int get _cardioMinutes => _exercises.fold(0, (sum, e) {
    if (!e.isCardio) return sum;
    return sum + e.sets.fold(0, (s, set) => s + (set.reps ?? 0));
  });

  Map<String, TrainerPreviousStats> get _previousStatsByName {
    final result = <String, TrainerPreviousStats>{};
    for (final workout in _previousWorkouts) {
      for (final exercise in workout.exercises) {
        if (result.containsKey(exercise.name)) continue;
        result[exercise.name] = TrainerPreviousStats(
          date: workout.workoutDate,
          maxWeight: exercise.sets.isEmpty
              ? 0
              : exercise.sets
                    .map((s) => s.weight)
                    .reduce((a, b) => a > b ? a : b),
        );
      }
    }
    return result;
  }

  // ── Exercise management ──

  Future<void> _showExercisePicker() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    // 시안 Tr-ExercisePicker: 시트 위 끝이 화면 위 72 (844 중 772)
    final picked = await showAppBottomSheet<TrainerPickedExercise>(
      context: context,
      heightFactor: 0.91,
      padded: false,
      child: TrainerExercisePickerSheet(
        trainerId: trainer.uid,
        defaultCategory: _defaultCategory,
        customExercises: _customExercises,
        previousStatsByName: _previousStatsByName,
        onCustomAdded: (e) => setState(() => _customExercises.add(e)),
      ),
    );

    if (picked == null) return;
    setState(() {
      _defaultCategory = picked.category;
      _exercises.add(
        TrainerExerciseDraft(
          name: picked.name,
          category: picked.category,
          sets: [TrainerSetDraft()],
        ),
      );
      _focusedIndex = _exercises.length - 1;
    });
  }

  void _addSet(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final previous = exercise.sets.isNotEmpty ? exercise.sets.last : null;
    setState(() {
      exercise.sets.add(
        TrainerSetDraft(
          weight: previous?.weightController.text.trim() ?? '',
          reps: previous?.repsController.text.trim() ?? '',
        ),
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    final exercise = _exercises[exerciseIndex];
    if (exercise.sets.length == 1) {
      AppFeedback.showWarning(context, '세트는 최소 1개 이상 필요합니다.');
      return;
    }
    setState(() {
      exercise.sets[setIndex].dispose();
      exercise.sets.removeAt(setIndex);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
      if (_focusedIndex >= _exercises.length) {
        _focusedIndex = _exercises.isEmpty ? 0 : _exercises.length - 1;
      }
    });
  }

  void _toggleSetDone(int exerciseIndex, int setIndex) {
    setState(() {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.done = !set.done;
    });
  }

  Future<void> _showExerciseMenu(int index) async {
    final exercise = _exercises[index];
    final action = await showAppBottomSheet<TrainerMenuAction>(
      context: context,
      child: TrainerExerciseMenuSheet(exercise: exercise),
    );
    if (action == null) return;

    switch (action.type) {
      case TrainerMenuActionType.toggleUnit:
        setState(() {
          final nextUnit = exercise.unit == TrainerWeightUnit.kg
              ? TrainerWeightUnit.lbs
              : TrainerWeightUnit.kg;
          for (final set in exercise.sets) {
            final value = set.weight;
            if (value == null) continue;
            final converted = exercise.unit == TrainerWeightUnit.kg
                ? value * 2.2046226218
                : value / 2.2046226218;
            set.weightController.text = trainerFormatWeight(converted);
          }
          exercise.unit = nextUnit;
        });
        break;
      case TrainerMenuActionType.delete:
        _removeExercise(index);
        break;
    }
  }

  void _clearSession() {
    for (final e in _exercises) {
      e.dispose();
    }
    _exercises.clear();
    _noteController.clear();
    _editingWorkoutId = null;
    _focusedIndex = 0;
  }

  // ── Save / Edit / Delete ──

  Future<void> _saveWorkout() async {
    if (_saving) return;

    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    final exercises = _exercises
        .map((d) => d.toExercise())
        .whereType<Exercise>()
        .toList();

    if (exercises.isEmpty) {
      AppFeedback.showWarning(context, '운동명, 무게, 횟수를 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final wasEditing = _editingWorkoutId != null;
      Workout? saved;

      if (_editingWorkoutId == null) {
        final newWorkout = await WorkoutService.saveWorkout(
          centerId: widget.member.centerId,
          memberId: widget.member.uid,
          memberName: widget.member.name,
          trainerId: trainer.uid,
          workoutType: WorkoutType.pt,
          createdById: trainer.uid,
          createdByRole: WorkoutCreatedByRole.trainer,
          ptSessionId: widget.session.id,
          workoutDate: _workoutDate,
          category: _exercises.first.category,
          exercises: exercises,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

        saved = newWorkout;

        // 저장된 기록을 '수정 중'으로 잡아 두면, 아래 완료 처리가 실패해 다시 눌러도
        // 새 기록이 또 생기지 않고 같은 기록을 고친 뒤 완료 처리를 다시 시도한다.
        if (mounted) {
          setState(() {
            _savedWorkouts = [newWorkout, ..._savedWorkouts];
            _editingWorkoutId = newWorkout.id;
          });
        }
      } else {
        await WorkoutService.updateWorkout(
          workoutId: _editingWorkoutId!,
          category: _exercises.first.category,
          exercises: exercises,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }

      // 기록이 있으면 세션은 완료 상태여야 한다. 서버가 처음 한 번만 잔여 1회를 차감하므로
      // 저장·수정 때마다 불러도 안전하다 (이전에 완료 처리가 실패했어도 여기서 다시 시도된다).
      await FirestoreService.updatePtSessionStatus(
        widget.session.id,
        PtSessionStatus.completed,
      );

      if (!mounted) return;
      setState(_clearSession);
      await _load();

      if (!mounted) return;
      if (wasEditing) {
        AppFeedback.showSuccessSnackBar(context, '운동 기록을 수정했습니다.');
      } else {
        await _showPtDone(trainer, saved!);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showPtDone(AppUser trainer, Workout saved) async {
    final ptInfo = await FirestoreService.getPtInfo(
      widget.member.uid,
      centerId: widget.member.centerId,
    );
    if (!mounted) return;

    final action = await Navigator.of(context).push<TrainerPtDoneAction>(
      MaterialPageRoute(
        builder: (_) => TrainerPtDoneScreen(
          memberName: widget.member.name,
          remainingSessions: ptInfo?.remainingSessions ?? 0,
          exerciseCount: saved.exercises.length,
          setCount: saved.totalSets,
          totalVolumeKg: saved.totalVolume,
          cardioMinutes: saved.category == WorkoutCategory.cardio
              ? saved.exercises.fold<int>(
                  0,
                  (sum, e) =>
                      sum + e.sets.fold<int>(0, (s, set) => s + set.reps),
                )
              : null,
        ),
      ),
    );
    if (!mounted || action != TrainerPtDoneAction.feedback) return;

    fb.Feedback? existing;
    try {
      existing = await FirestoreService.getFeedbackByTarget(
        saved.id,
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        trainerId: trainer.uid,
      );
    } catch (_) {
      existing = null;
    }
    if (!mounted) return;
    await FeedbackSheet.show(
      context,
      centerId: widget.member.centerId,
      trainerId: trainer.uid,
      trainerName: trainer.name,
      memberId: widget.member.uid,
      memberName: widget.member.name,
      targetType: fb.FeedbackTargetType.workout,
      targetId: saved.id,
      targetDate: saved.workoutDate,
      existing: existing,
    );
  }

  void _editWorkout(Workout workout) {
    for (final e in _exercises) {
      e.dispose();
    }
    setState(() {
      _exercises.clear();
      _editingWorkoutId = workout.id;
      _focusedIndex = 0;
      _defaultCategory = workout.category;
      _noteController.text = workout.note ?? '';

      for (final exercise in workout.exercises) {
        _exercises.add(
          TrainerExerciseDraft.fromExercise(
            exercise: exercise,
            category: workout.category,
          ),
        );
      }
    });

    AppFeedback.showSuccessSnackBar(context, '수정 모드로 불러왔습니다.');
  }

  Future<void> _deleteWorkout(Workout workout) async {
    // 이 세션의 마지막 기록이면 PT 완료도 취소하고 잔여 1회를 되돌린다.
    final isLastRecord =
        _savedWorkouts
            .where((w) => w.ptSessionId == widget.session.id)
            .length <=
        1;
    final ok = await showAppConfirmDialog(
      context,
      title: 'PT 기록 삭제',
      message:
          '운동 ${workout.exercises.length}개, ${workout.totalSets}세트 기록이 삭제되며 되돌릴 수 없습니다.',
      warning: isLastRecord
          ? '이 PT의 마지막 기록이라 완료 처리도 취소되고 잔여 횟수 1회가 복구됩니다.'
          : null,
      confirmLabel: '삭제',
    );
    if (ok != true) return;

    try {
      await WorkoutService.deleteWorkout(workout.id);
      if (isLastRecord) {
        await FirestoreService.updatePtSessionStatus(
          widget.session.id,
          PtSessionStatus.scheduled,
        );
      }
      if (!mounted) return;

      if (_editingWorkoutId == workout.id) {
        setState(_clearSession);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  TrainerExerciseComparison _comparisonFor(TrainerExerciseDraft exercise) {
    final previous = _previousStatsByName[exercise.name];
    if (previous == null) {
      return const TrainerExerciseComparison(
        label: '지난 기록 없음',
        tone: TrainerComparisonTone.muted,
      );
    }

    final currentMax = exercise.maxWeight;
    final previousMax = exercise.unit == TrainerWeightUnit.kg
        ? previous.maxWeight
        : previous.maxWeight * 2.2046226218;
    final suffix = exercise.primaryMetricSuffix;

    if (currentMax == null) {
      return TrainerExerciseComparison(
        label: '지난 최고 ${trainerFormatMetricValue(previousMax)}$suffix',
        tone: TrainerComparisonTone.muted,
      );
    }

    final diff = currentMax - previousMax;
    if (diff > 0) {
      return TrainerExerciseComparison(
        label: '+${trainerFormatMetricValue(diff)}$suffix',
        tone: TrainerComparisonTone.up,
      );
    }
    if (diff < 0) {
      return TrainerExerciseComparison(
        label: '${trainerFormatMetricValue(diff)}$suffix',
        tone: TrainerComparisonTone.down,
      );
    }
    return const TrainerExerciseComparison(
      label: '동일',
      tone: TrainerComparisonTone.same,
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final editing = _editingWorkoutId != null;
    final canSave = _hasContent;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 시안 Tr-PtRecord: 56 머리 · 뒤로 24 · 가운데 17/500 · 오른쪽 '저장'(16/500, 내용이 있을 때만)
            AppScreenHeader.centered(
              title: 'PT 기록',
              onBack: () => Navigator.of(context).pop(),
              trailing: canSave
                  ? _HeaderSaveButton(onTap: _saving ? null : _saveWorkout)
                  : null,
            ),
            Expanded(child: _buildBody(editing)),
            // 시작 단계 없이 바로 저장한다. 저장하면 예약된 PT가 완료 처리된다.
            // 운동 내용이 없으면 저장할 것이 없으므로 비활성.
            AppBottomActionBar(
              primaryLabel: _saving
                  ? '저장 중'
                  : editing
                  ? '수정 저장'
                  : '기록 저장',
              loading: _saving,
              onPrimary: _saving || !canSave ? null : _saveWorkout,
              secondaryLabel: '운동 추가',
              secondaryIcon: AppIcons.add,
              onSecondary: _showExercisePicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool editing) {
    if (_loading) return const AppLoadingView();
    if (_errorMessage != null) {
      return Center(
        child: AppErrorCard(message: _errorMessage!, onRetry: _load),
      );
    }

    final scheduled = widget.session.scheduledAt;
    final subtitle =
        '${DateFormat('M월 d일 HH:mm').format(scheduled)} · ${widget.session.durationMinutes}분';
    final focused = _exercises.isEmpty
        ? -1
        : _focusedIndex.clamp(0, _exercises.length - 1);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _MemberRow(
          name: widget.member.name,
          subtitle: subtitle,
          editing: editing,
        ),
        if (_exercises.isNotEmpty || editing)
          _SessionStats(
            cardioMinutes: _isCardioSession ? _cardioMinutes : null,
            volumeKg: _sessionVolume,
            doneSets: _completedSetCount,
            totalSets: _totalSetCount,
            exerciseCount: _exercises.length,
          ),
        if (_exercises.isEmpty)
          _PtEmptyCard(compact: _savedWorkouts.isNotEmpty)
        else ...[
          for (var i = 0; i < _exercises.length; i++)
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? AppSpacing.base : AppSpacing.md,
              ),
              child: i == focused
                  ? TrainerExerciseInputCard(
                      order: i + 1,
                      exercise: _exercises[i],
                      comparison: _comparisonFor(_exercises[i]),
                      onChanged: () => setState(() {}),
                      onAddSet: () => _addSet(i),
                      onMenuTap: () => _showExerciseMenu(i),
                      onRemoveSet: (si) => _removeSet(i, si),
                      onToggleSetDone: (si) => _toggleSetDone(i, si),
                    )
                  : TrainerCollapsedExercise(
                      exercise: _exercises[i],
                      onTap: () => setState(() => _focusedIndex = i),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              0,
            ),
            child: AppTextField(
              label: '메모',
              hint: '오늘 세션에서 남길 내용',
              controller: _noteController,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
          ),
        ],
        if (_savedWorkouts.isNotEmpty) ...[
          // 시안: 메모 아래 28 · 빈 카드 아래 24 띄운 8 회색 띠
          AppSectionBand(top: _exercises.isEmpty ? AppSpacing.xl : 28),
          AppMonthHeader(
            label: '저장된 PT 기록',
            count: '${_savedWorkouts.length}',
            strong: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              18,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
          ),
          // 시안 `slide`: 왼쪽 12에서 밀려 들어옴 (.4s, 순번 × .08s)
          for (var i = 0; i < _savedWorkouts.length; i++)
            AppEntrance.slide(
              key: ValueKey(_savedWorkouts[i].id),
              delay: Duration(milliseconds: 80 * i),
              child: TrainerSavedWorkoutCard(
                workout: _savedWorkouts[i],
                onEdit: () => _editWorkout(_savedWorkouts[i]),
                onDelete: () => _deleteWorkout(_savedWorkouts[i]),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl2),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────

/// 머리 오른쪽 '저장' (시안: 최소 44 · 좌우 12 · 16/500, 단추 끝이 화면 오른쪽 8).
/// 가운데 머리의 오른쪽 칸(44, 가운데 정렬) 안에서 위치를 맞춘다.
class _HeaderSaveButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderSaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 38),
          child: Semantics(
            button: true,
            enabled: onTap != null,
            label: '저장',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.field),
              highlightColor: AppColors.canvasSoft,
              splashFactory: NoSplash.splashFactory,
              child: Container(
                height: AppSize.touchMin,
                constraints: const BoxConstraints(minWidth: AppSize.touchMin),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                child: Text(
                  '저장',
                  style: AppTextStyles.listTitle.copyWith(
                    color: onTap == null ? AppColors.faint : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 회원 줄 (시안 Tr-PtRecord: 위 8 · 좌우 20): 이름 20/500 + 일정 14 mute(위 2).
/// 수정 중이면 일정 뒤에 ' · 수정 중'(noticeText 500, 1.4s 깜빡임).
class _MemberRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool editing;

  const _MemberRow({
    required this.name,
    required this.subtitle,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.natural,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fieldLabel.natural,
                ),
              ),
              if (editing) ...[
                Text(' · ', style: AppTextStyles.fieldLabel.natural),
                _Blink(
                  child: Text(
                    '수정 중',
                    style: AppTextStyles.fieldLabel.natural.medium.copyWith(
                      color: AppColors.noticeText,
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

/// 시안 `blink`: 투명도 1 → .35 → 1 (1.4s ease-in-out 반복). 동작 줄이기면 멈춘다.
class _Blink extends StatefulWidget {
  final Widget child;

  const _Blink({required this.child});

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
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
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final v = _controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        return Opacity(
          opacity: 1 - 0.65 * Curves.easeInOut.transform(tri),
          child: child,
        );
      },
    );
  }
}

/// 요약 3칸 (시안 Tr-PtRecord: 위 16 · 좌우 20 · 사이 8, 칸 회색 반경 14 · 안쪽 12 14):
/// 라벨 12 mute + 값 18/500(단위 400 mute, 위 2). 총 볼륨(유산소만이면 유산소 분) · 완료세트 · 운동.
class _SessionStats extends StatelessWidget {
  final int? cardioMinutes;
  final double volumeKg;
  final int doneSets;
  final int totalSets;
  final int exerciseCount;

  const _SessionStats({
    required this.cardioMinutes,
    required this.volumeKg,
    required this.doneSets,
    required this.totalSets,
    required this.exerciseCount,
  });

  @override
  Widget build(BuildContext context) {
    // 시안 `up`: 아래 10에서 올라오며 나타남 (.5s, 칸마다 .08s 늦게)
    Widget cell(int order, String label, String value, String suffix) {
      return Expanded(
        child: AppEntrance(
          delay: Duration(milliseconds: 80 * order),
          child: Semantics(
            label: '$label $value$suffix',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.canvasCard,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 12 * -0.019,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: value),
                        TextSpan(
                          text: suffix,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.section.copyWith(
                      fontSize: 18,
                      height: 22 / 18,
                      letterSpacing: 18 * -0.019,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.base,
        AppSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          cardioMinutes != null
              ? cell(0, '유산소', '$cardioMinutes', '분')
              : cell(
                  0,
                  '총 볼륨',
                  NumberFormat('#,##0').format(volumeKg.round()),
                  'kg',
                ),
          const SizedBox(width: AppSpacing.sm),
          cell(1, '완료세트', '$doneSets', ' / $totalSets'),
          const SizedBox(width: AppSpacing.sm),
          cell(2, '운동', '$exerciseCount', '종목'),
        ],
      ),
    );
  }
}

/// 운동이 아직 없을 때 (시안 Tr-PtRecord-Empty): 회색 카드(반경 18, 위 24 · 안쪽 40 28)에
/// 바벨 그림(56×40, 들었다 내림) + 'PT 운동을 기록하세요'(16/500) + 안내(14 mute, 줄 1.5).
/// 저장된 기록이 있으면 [compact] (시안 Tr-PtRecord-Saved): 위 20 · 안쪽 24, 그림 없이 두 줄(사이 8).
class _PtEmptyCard extends StatelessWidget {
  final bool compact;

  const _PtEmptyCard({required this.compact});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        compact ? AppSpacing.lg : AppSpacing.xl,
        AppSpacing.screenH,
        0,
      ),
      padding: compact
          ? const EdgeInsets.all(AppSpacing.xl)
          : const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        children: [
          if (!compact) ...[
            const _LiftingBarbell(),
            // 시안: 줄 사이 10 + 제목 위 4
            const SizedBox(height: 14),
          ],
          Text(
            'PT 운동을 기록하세요',
            textAlign: TextAlign.center,
            style: AppTextStyles.listTitle.natural,
          ),
          SizedBox(height: compact ? AppSpacing.sm : 10),
          Text(
            '아래 운동 추가로 운동을 고르고 세트, 중량, 횟수를 입력하세요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.fieldLabel.copyWith(height: 1.5),
          ),
        ],
      ),
    );
    // 시안 `up`: 첫 빈 화면 카드만 아래 10에서 올라오며 나타남 (.5s)
    return compact ? card : AppEntrance(child: card);
  }
}

/// 바벨 그림 (56×40)이 위아래로 6씩 들렸다 내려간다 (시안 `lift`: 1.8s ease-in-out 반복).
class _LiftingBarbell extends StatefulWidget {
  const _LiftingBarbell();

  @override
  State<_LiftingBarbell> createState() => _LiftingBarbellState();
}

class _LiftingBarbellState extends State<_LiftingBarbell>
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
        child: const CustomPaint(
          size: Size(56, 40),
          painter: _BarbellArtPainter(),
        ),
        builder: (context, child) {
          // 0%·100% → +6, 50% → −6 (동작 줄이기면 0%에 멈춘다)
          final v = _controller.value;
          final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
          final dy = 6 - 12 * Curves.easeInOut.transform(tri);
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
      ),
    );
  }
}

/// 시안 SVG(viewBox 200×64)를 56×40에 비율 맞춰 그린 바벨:
/// 봉(faint) + 원판 둘(mute) + 가운데 주황 손잡이.
class _BarbellArtPainter extends CustomPainter {
  const _BarbellArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200;
    canvas.translate(0, (size.height - 64 * k) / 2);
    canvas.scale(k);
    void rrect(double x, double y, double w, double h, double r, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    rrect(40, 26, 120, 12, 6, AppColors.faint);
    rrect(26, 0, 22, 64, 8, AppColors.mute);
    rrect(152, 0, 22, 64, 8, AppColors.mute);
    rrect(80, 23, 40, 18, 9, AppColors.primary);
  }

  @override
  // 색이 테마를 따르므로 다시 그릴 때마다 칠한다 (그림이 작아 부담 없음).
  bool shouldRepaint(_BarbellArtPainter oldDelegate) => true;
}
