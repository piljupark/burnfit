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
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_marks.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/workout_parts.dart';
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

  /// 이 세션(ptSessionId)의 저장된 기록만 둔다. 같은 날 다른 세션 기록을 고치거나 지워
  /// 이 세션의 완료·잔여 횟수가 바뀌지 않게 한다.
  List<Workout> _savedWorkouts = [];
  List<CustomExercise> _customExercises = [];
  List<Workout> _previousWorkouts = [];

  WorkoutCategory _defaultCategory = WorkoutCategory.chest;
  String? _editingWorkoutId;

  /// 아직 이 세션을 완료 처리(잔여 1회 차감)하지 않았는지.
  /// 수정 중인 기록([_editingWorkoutId])과 따로 둔다: 기록은 저장됐는데 완료 처리만 실패했으면
  /// 다시 저장할 때 같은 기록을 고치면서 완료 처리(와 완료 화면)를 이어서 한다.
  late bool _awaitingCompletion =
      widget.session.status == PtSessionStatus.scheduled;

  /// 마지막 기록을 지웠는데 완료 취소(잔여 복구)가 실패한 세션 — 다시 시도 안내를 띄운다.
  String? _restoreFailedSessionId;
  bool _restoring = false;

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
    if (trainer == null) {
      // 로그인 정보가 아직 없거나 사라졌으면 빈 화면 대신 안내와 다시 시도를 보여 준다.
      setState(() {
        _loading = false;
        _errorMessage = '사용자 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
      return;
    }

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
        _savedWorkouts = (results[0] as List<Workout>)
            // 세션 연결값이 없는 예전 기록은 보여 주되, 지워도 세션 상태는 건드리지 않는다.
            .where(
              (w) =>
                  w.ptSessionId == widget.session.id || w.ptSessionId == null,
            )
            .toList();
        _previousWorkouts = results[1] as List<Workout>;
        _customExercises = results[2] as List<CustomExercise>;
        _errorMessage = null;
        // 그 사이 이 세션에 기록이 생겼으면 완료 취소를 다시 시도할 까닭이 없다.
        if (_savedWorkouts.isNotEmpty &&
            _restoreFailedSessionId == widget.session.id) {
          _restoreFailedSessionId = null;
        }
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

  /// 근력 종목만의 볼륨(kg 환산). 유산소 여부는 종목마다 판단한다.
  double get _sessionVolumeKg =>
      _exercises.fold(0.0, (sum, e) => sum + e.volumeKg);

  bool get _isCardioSession =>
      _exercises.isNotEmpty && _exercises.every((e) => e.isCardio);

  int get _cardioMinutes =>
      _exercises.fold(0, (sum, e) => sum + e.cardioMinutes);

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

  /// 저장된 종목의 부위 (기록의 부위는 하나뿐이라 종목 이름으로 다시 찾는다).
  WorkoutCategory _categoryOf(String name, WorkoutCategory fallback) =>
      exerciseCategoryOf(name, customExercises: _customExercises) ?? fallback;

  // ── Exercise management ──

  Future<void> _showExercisePicker() async {
    if (_saving) return;
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) {
      AppFeedback.showWarning(context, '사용자 정보를 불러오지 못했습니다. 다시 시도해 주세요.');
      return;
    }

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

    if (picked == null || !mounted || _saving) return;
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
      if (index < _focusedIndex) _focusedIndex--;
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
    if (action == null || !mounted || _saving) return;

    switch (action.type) {
      case TrainerMenuActionType.toggleUnit:
        // 유산소는 무게가 아니므로 메뉴에 없다. 혹시 와도 바꾸지 않는다.
        if (exercise.isCardio) return;
        setState(() {
          final nextUnit = exercise.unit == TrainerWeightUnit.kg
              ? TrainerWeightUnit.lbs
              : TrainerWeightUnit.kg;
          // 손대지 않은 값은 원래 글자로 되돌려 kg ↔ lbs 왕복 오차를 없앤다.
          for (final set in exercise.sets) {
            set.weightController.text = set.unitMemo.toggle(
              set.weightController.text,
              toLbs: nextUnit == TrainerWeightUnit.lbs,
            );
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

  /// 입력 중인 내용이 있으면 버려도 되는지 묻는다 (없으면 바로 true).
  Future<bool> _confirmDiscard({
    required String title,
    required String confirmLabel,
  }) async {
    if (!_hasContent) return true;
    return showAppConfirmDialog(
      context,
      title: title,
      message: '지금 입력한 운동 기록은 저장되지 않고 사라집니다.',
      confirmLabel: confirmLabel,
    );
  }

  Future<void> _handleBack() async {
    if (!_hasContent) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await _confirmDiscard(
      title: '저장하지 않고 나갈까요?',
      confirmLabel: '나가기',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // ── Save / Edit / Delete ──

  Future<void> _saveWorkout() async {
    if (_saving) return;

    final trainer = context.read<UserProvider>().user;
    if (trainer == null) {
      AppFeedback.showWarning(context, '사용자 정보를 불러오지 못했습니다. 다시 시도해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();

    final exercises = _exercises
        .map((d) => d.toExercise())
        .whereType<Exercise>()
        .toList();

    if (exercises.isEmpty) {
      AppFeedback.showWarning(context, '운동명과 횟수를 입력해주세요. (맨몸 운동은 무게를 비워 두세요)');
      return;
    }

    // 일부만 채운 세트·종목은 저장에서 빠지므로 미리 알린다.
    final droppedExercises = _exercises
        .where((d) => d.toExercise() == null)
        .length;
    final droppedSets = _exercises
        .where((d) => d.toExercise() != null)
        .fold<int>(0, (n, d) => n + d.droppedSetCount);
    if (droppedExercises > 0 || droppedSets > 0) {
      final parts = [
        if (droppedExercises > 0) '종목 $droppedExercises개',
        if (droppedSets > 0) '세트 $droppedSets개',
      ].join(', ');
      final ok = await showAppConfirmDialog(
        context,
        title: '빠지는 기록이 있습니다',
        message: '횟수(유산소는 시간)가 비어 있는 $parts는 저장되지 않습니다. 이대로 저장할까요?',
        confirmLabel: '저장',
        destructive: false,
      );
      if (!ok || !mounted) return;
    }

    // 이번 저장으로 세션이 완료 처리(잔여 1회 차감)되는지.
    final completing = _awaitingCompletion;
    if (completing && widget.session.scheduledAt.isAfter(DateTime.now())) {
      final ok = await showAppConfirmDialog(
        context,
        title: '시작 전인 PT',
        message: '아직 시작 전인 PT입니다. 저장하면 완료 처리되고 1회 차감됩니다.',
        confirmLabel: '저장',
        destructive: false,
      );
      if (!ok || !mounted) return;
    }

    final wasEditing = _editingWorkoutId != null;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final category = _exercises.first.category;
    final summary = _doneSummary(exercises, category);

    setState(() => _saving = true);
    try {
      // 완료 처리할 수 없으면(PT권 없음·잔여 0) 운동 기록부터 쓰지 않는다.
      // 이미 쓴 기록을 고치며 완료 처리만 다시 시도할 때는 서버가 판단한다
      // (앞선 완료 처리가 실제로는 됐는데 응답만 못 받았으면 잔여가 0이어도 막으면 안 된다).
      if (completing && !wasEditing) {
        try {
          await FirestoreService.requireRemainingForCompletion(
            centerId: widget.member.centerId,
            memberId: widget.member.uid,
          );
        } on ArgumentError catch (e) {
          if (mounted) {
            AppFeedback.showWarning(context, AppFeedback.errorMessage(e));
          }
          return;
        }
      }

      final String workoutId;
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
          category: category,
          exercises: exercises,
          note: note,
        );
        workoutId = newWorkout.id;

        // 저장된 기록을 '수정 중'으로 잡아 두면, 아래 완료 처리가 실패해 다시 눌러도
        // 새 기록이 또 생기지 않고 같은 기록을 고친 뒤 완료 처리를 다시 시도한다.
        _editingWorkoutId = newWorkout.id;
        if (mounted) {
          setState(() => _savedWorkouts = [newWorkout, ..._savedWorkouts]);
        }
      } else {
        workoutId = _editingWorkoutId!;
        await WorkoutService.updateWorkout(
          workoutId: workoutId,
          category: category,
          exercises: exercises,
          note: note,
        );
      }

      // 기록이 있으면 세션은 완료 상태여야 한다. 서버가 처음 한 번만 잔여 1회를 차감하고,
      // 실제로 바뀌었을 때만(changed) 차감 뒤 잔여 횟수를 돌려준다.
      PtStatusResult? status;
      if (completing) {
        try {
          status = await FirestoreService.updatePtSessionStatus(
            widget.session.id,
            PtSessionStatus.completed,
          );
        } catch (e) {
          if (!mounted) return;
          AppFeedback.showWarning(
            context,
            '운동 기록은 저장했지만 PT 완료 처리에 실패했습니다. 다시 저장하면 완료 처리를 다시 시도합니다.',
          );
          return;
        }
        // 이미 완료돼 있었어도(changed == false) 더는 완료 처리를 기다리지 않는다.
        _awaitingCompletion = false;
      }

      if (!mounted) return;
      setState(() {
        _clearSession();
        _restoreFailedSessionId = null;
      });
      await _load();

      if (!mounted) return;
      if (status != null && status.changed) {
        await _showPtDone(
          trainer,
          workoutId: workoutId,
          remainingSessions: status.remainingSessions,
          summary: summary,
        );
      } else {
        AppFeedback.showSuccessSnackBar(
          context,
          wasEditing ? '운동 기록을 수정했습니다.' : '운동 기록을 저장했습니다.',
        );
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

  /// PT 완료 화면 요약: 종목 수 · 세트 수 · 근력 볼륨(kg), 모두 유산소면 운동한 분.
  /// 유산소 여부는 종목마다 이름으로 가린다.
  _DoneSummary _doneSummary(
    List<Exercise> exercises,
    WorkoutCategory category,
  ) {
    var volume = 0.0;
    var minutes = 0;
    var allCardio = true;
    for (final exercise in exercises) {
      if (isCardioExercise(
        exercise.name,
        category,
        customExercises: _customExercises,
      )) {
        minutes += exercise.sets.fold<int>(0, (s, set) => s + set.reps);
      } else {
        allCardio = false;
        volume += exercise.totalVolume;
      }
    }
    return _DoneSummary(
      exerciseCount: exercises.length,
      setCount: exercises.fold<int>(0, (n, e) => n + e.sets.length),
      volumeKg: volume,
      cardioMinutes: allCardio ? minutes : null,
    );
  }

  Future<void> _showPtDone(
    AppUser trainer, {
    required String workoutId,
    required int? remainingSessions,
    required _DoneSummary summary,
  }) async {
    final action = await Navigator.of(context).push<TrainerPtDoneAction>(
      MaterialPageRoute(
        builder: (_) => TrainerPtDoneScreen(
          memberName: widget.member.name,
          remainingSessions: remainingSessions,
          exerciseCount: summary.exerciseCount,
          setCount: summary.setCount,
          totalVolumeKg: summary.volumeKg,
          cardioMinutes: summary.cardioMinutes,
        ),
      ),
    );
    if (!mounted || action != TrainerPtDoneAction.feedback) return;

    fb.Feedback? existing;
    try {
      existing = await FirestoreService.getFeedbackByTarget(
        workoutId,
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
      targetId: workoutId,
      targetDate: _workoutDate,
      existing: existing,
    );
  }

  Future<void> _editWorkout(Workout workout) async {
    if (_saving) return;
    final ok = await _confirmDiscard(
      title: '이 기록을 불러올까요?',
      confirmLabel: '불러오기',
    );
    if (!ok || !mounted) return;

    for (final e in _exercises) {
      e.dispose();
    }
    setState(() {
      _exercises.clear();
      _editingWorkoutId = workout.id;
      _focusedIndex = 0;
      _defaultCategory = workout.category;
      _noteController.text = workout.note ?? '';

      // 기록에는 부위가 하나만 있으므로 종목 이름으로 부위를 찾아 유산소 표·볼륨을 맞춘다.
      for (final exercise in workout.exercises) {
        _exercises.add(
          TrainerExerciseDraft.fromExercise(
            exercise: exercise,
            category: _categoryOf(exercise.name, workout.category),
          ),
        );
      }
    });

    AppFeedback.showSuccessSnackBar(context, '수정 모드로 불러왔습니다.');
  }

  Future<void> _deleteWorkout(Workout workout) async {
    if (_saving) return;
    // 이 기록이 속한 세션의 마지막 기록이면 PT 완료도 취소하고 잔여 1회를 되돌린다.
    final sessionId = workout.ptSessionId;
    final isLastRecord =
        sessionId != null &&
        _savedWorkouts.where((w) => w.ptSessionId == sessionId).length <= 1;
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
    if (ok != true || !mounted) return;

    try {
      await WorkoutService.deleteWorkout(workout.id);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
      return;
    }
    if (!mounted) return;

    if (_editingWorkoutId == workout.id) {
      setState(_clearSession);
    }

    if (isLastRecord) {
      final restored = await _restoreSession(sessionId);
      if (!mounted) return;
      if (!restored) {
        AppFeedback.showWarning(
          context,
          '기록은 삭제했지만 PT 완료 취소에 실패했습니다. 아래 \'다시 시도\'를 눌러 주세요.',
        );
      }
    }
    // 완료 취소가 실패해도 지운 기록이 목록에 남아 보이지 않게 다시 불러온다.
    await _load();
  }

  /// 세션을 예약 상태로 되돌린다 (잔여 1회 복구). 실패하면 다시 시도 안내를 띄울 수 있게 기억한다.
  Future<bool> _restoreSession(String sessionId) async {
    try {
      await FirestoreService.updatePtSessionStatus(
        sessionId,
        PtSessionStatus.scheduled,
      );
      if (mounted) {
        setState(() {
          _restoreFailedSessionId = null;
          if (sessionId == widget.session.id) _awaitingCompletion = true;
        });
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _restoreFailedSessionId = sessionId);
      return false;
    }
  }

  Future<void> _retryRestore() async {
    final sessionId = _restoreFailedSessionId;
    if (sessionId == null || _restoring) return;
    // 그 사이 이 세션에 새 기록이 저장됐으면 완료 상태가 맞다.
    if (_savedWorkouts.any((w) => w.ptSessionId == sessionId)) {
      setState(() => _restoreFailedSessionId = null);
      return;
    }
    setState(() => _restoring = true);
    final restored = await _restoreSession(sessionId);
    if (!mounted) return;
    setState(() => _restoring = false);
    if (restored) {
      AppFeedback.showSuccessSnackBar(context, 'PT 완료를 취소하고 잔여 횟수를 복구했습니다.');
    } else {
      AppFeedback.showWarning(context, '완료 취소에 다시 실패했습니다. 잠시 후 다시 시도해 주세요.');
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
    final previousMax =
        exercise.isCardio || exercise.unit == TrainerWeightUnit.kg
        ? previous.maxWeight
        : previous.maxWeight * kLbsPerKg;
    final suffix = exercise.primaryMetricSuffix;

    if (currentMax == null) {
      return TrainerExerciseComparison(
        label: '지난 최고 ${formatMetricValue(previousMax)}$suffix',
        tone: TrainerComparisonTone.muted,
      );
    }

    final diff = currentMax - previousMax;
    if (diff > 0) {
      return TrainerExerciseComparison(
        label: '+${formatMetricValue(diff)}$suffix',
        tone: TrainerComparisonTone.up,
      );
    }
    if (diff < 0) {
      return TrainerExerciseComparison(
        label: '${formatMetricValue(diff)}$suffix',
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

    // 입력 중인 내용이 있으면 뒤로 가기 전에 확인한다 (기기 뒤로·머리 뒤로 모두).
    return PopScope(
      canPop: !_hasContent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 시안 Tr-PtRecord: 56 머리 · 뒤로 24 · 가운데 17/500 · 오른쪽 '저장'(16/500, 내용이 있을 때만)
              AppScreenHeader.centered(
                title: 'PT 기록',
                onBack: _handleBack,
                trailing: canSave
                    ? _HeaderSaveButton(onTap: _saving ? null : _saveWorkout)
                    : null,
              ),
              // 저장하는 동안에는 입력·운동 추가·기록 수정을 막는다.
              Expanded(
                child: IgnorePointer(
                  ignoring: _saving,
                  child: _buildBody(editing),
                ),
              ),
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
                onSecondary: _saving ? null : _showExercisePicker,
              ),
            ],
          ),
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
        if (_restoreFailedSessionId != null)
          AppErrorCard(
            message: _restoring
                ? 'PT 완료를 취소하는 중입니다.'
                : '기록은 삭제했지만 PT 완료 취소(잔여 1회 복구)에 실패했습니다.',
            onRetry: _retryRestore,
          ),
        if (_exercises.isNotEmpty || editing)
          WorkoutSummaryStats(
            top: AppSpacing.base,
            cellPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            radius: AppRadius.field,
            labelColor: AppColors.mute,
            labelMaxLines: 1,
            valueStyle: AppTextStyles.section.copyWith(
              fontSize: 18,
              height: 22 / 18,
              letterSpacing: 18 * -0.019,
            ),
            stats: [
              _isCardioSession
                  ? WorkoutStat('유산소', '$_cardioMinutes', '분')
                  : WorkoutStat(
                      '총 볼륨',
                      NumberFormat('#,##0').format(_sessionVolumeKg.round()),
                      'kg',
                    ),
              WorkoutStat('완료세트', '$_completedSetCount', ' / $_totalSetCount'),
              WorkoutStat('운동', '${_exercises.length}', '종목'),
            ],
          ),
        if (_exercises.isEmpty)
          _PtEmptyCard(compact: _savedWorkouts.isNotEmpty)
        else ...[
          for (var i = 0; i < _exercises.length; i++)
            Padding(
              key: ObjectKey(_exercises[i]),
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
                  : WorkoutCollapsedRow(
                      name: _exercises[i].name,
                      subtitle: trainerExerciseRowSummary(_exercises[i]),
                      height: 64,
                      nameStyle: AppTextStyles.listTitle.natural,
                      chevron: true,
                      highlightColor: AppColors.canvasSoft,
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
                customExercises: _customExercises,
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

/// PT 완료 화면에 넘길 요약 (저장 전에 입력에서 계산한다).
class _DoneSummary {
  final int exerciseCount;
  final int setCount;
  final double volumeKg;
  final int? cardioMinutes;

  const _DoneSummary({
    required this.exerciseCount,
    required this.setCount,
    required this.volumeKg,
    required this.cardioMinutes,
  });
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
                AppBlink(
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

/// 운동이 아직 없을 때 (시안 Tr-PtRecord-Empty): 회색 카드(위 24 · 안쪽 40 28)에
/// 바벨 그림(56×40, 들었다 내림) + 'PT 운동을 기록하세요' + 안내(14 mute, 줄 1.5).
/// 저장된 기록이 있으면 [compact] (시안 Tr-PtRecord-Saved): 위 20 · 안쪽 24, 그림 없이 두 줄.
class _PtEmptyCard extends StatelessWidget {
  final bool compact;

  const _PtEmptyCard({required this.compact});

  @override
  Widget build(BuildContext context) {
    final card = AppEmptyState(
      card: true,
      icon: AppIcons.workout,
      illustration: compact
          ? const SizedBox.shrink()
          : LiftingBarbellMark(
              size: const Size(56, 40),
              outerPlates: false,
              plateColor: AppColors.mute,
            ),
      // 시안: 줄 사이 10 + 제목 위 4
      artGap: compact ? 0 : 14,
      cardPadding: compact
          ? const EdgeInsets.all(AppSpacing.xl)
          : const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      margin: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        compact ? AppSpacing.lg : AppSpacing.xl,
        AppSpacing.screenH,
        0,
      ),
      message: 'PT 운동을 기록하세요',
      description: '아래 운동 추가로 운동을 고르고 세트, 중량, 횟수를 입력하세요.',
    );
    // 시안 `up`: 첫 빈 화면 카드만 아래 10에서 올라오며 나타남 (.5s)
    return compact ? card : AppEntrance(child: card);
  }
}
