import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/workout_timing.dart';
import '../../models/custom_exercise.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_draft_service.dart';
import '../../services/workout_reminder.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/brand_marks.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/rest_timer.dart';
import '../../widgets/workout_duration_sheet.dart';
import '../../widgets/workout_parts.dart';
import 'member_workout_done_screen.dart';
import 'workout_auto_save.dart';
import 'workout_draft_models.dart';
import 'workout_exercise_input.dart';
import 'workout_saved_card.dart';
import 'workout_sheets.dart';

class MemberWorkoutScreen extends StatefulWidget {
  final VoidCallback? onExit;

  /// 운동 완료 화면에서 '확인'을 누르면 부른다 (회원 홈 탭으로).
  final VoidCallback? onGoHome;
  final WorkoutType workoutType;
  final AppUser? targetMember;
  final bool showAsTab;

  /// 화면 밖에서 기록이 바뀌었을 때 (앱을 열 때 자동 저장) — 홈 캘린더를 다시 불러온다.
  final VoidCallback? onRecordsChanged;

  const MemberWorkoutScreen({
    super.key,
    this.onExit,
    this.onGoHome,
    this.onRecordsChanged,
    this.workoutType = WorkoutType.personal,
    this.targetMember,
    this.showAsTab = false,
  });

  @override
  State<MemberWorkoutScreen> createState() => _MemberWorkoutScreenState();
}

class _MemberWorkoutScreenState extends State<MemberWorkoutScreen> {
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final _noteController = TextEditingController();
  final List<WorkoutExerciseDraft> _sessionExercises = [];

  List<Workout> _workouts = [];
  List<Workout> _previousWorkouts = [];
  List<CustomExercise> _customExercises = [];

  WorkoutCategory _defaultCategory = WorkoutCategory.chest;
  String? _editingWorkoutId;

  /// 펼쳐서 세트 표를 보여 줄 운동 (나머지는 한 줄로 접는다). 화면 표시 전용 상태.
  int _activeIndex = 0;

  bool _loading = false;
  bool _saving = false;
  bool _restoredDraft = false;

  /// 완료 화면의 '기록 자세히 보기'에서 저장된 기록으로 내려가기 위한 것.
  final _scrollController = ScrollController();
  final _savedSectionKey = GlobalKey();

  Timer? _draftTimer;

  // 운동 시간 (회원 개인 운동만, core/workout_timing.dart). PT 기록은 재지 않는다.
  // 유산소 세트의 '시간'은 운동 내용이므로 세트 값으로 따로 입력한다.
  DateTime? _startedAt;
  DateTime? _lastSetAt;

  /// 고치는 중인 저장 기록의 운동 시간(초). 새 기록이면 null.
  int? _editingDurationSeconds;

  /// 흘러가는 시간 표시를 30초마다 새로 그린다.
  Timer? _clockTimer;

  /// 앱을 연 뒤 한 번만: 닫혀서 마치지 못한 운동을 자동 저장한다.
  bool _autoSaveChecked = false;

  @override
  void initState() {
    super.initState();

    _noteController.addListener(_queueDraftSave);
    _load();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _clockTimer?.cancel();
    _noteController.dispose();
    _scrollController.dispose();

    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    super.dispose();
  }

  bool get _hasSessionContent {
    return _sessionExercises.isNotEmpty ||
        _noteController.text.trim().isNotEmpty ||
        _startedAt != null;
  }

  /// 운동 시간을 재는 화면인지: 회원이 직접 하는 개인 운동만.
  bool get _tracksTime {
    if (widget.workoutType != WorkoutType.personal) return false;
    final actor = context.read<UserProvider>().user;
    return actor != null && !actor.isTrainer && widget.targetMember == null;
  }

  void _startClock() {
    if (_clockTimer != null || _startedAt == null) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopClock() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  /// 종목을 추가하기 전에 '운동 시작'을 누른 때부터 잰다.
  void _startWorkout() {
    setState(() => _startedAt = DateTime.now());
    _startClock();
    _queueDraftSave();
  }

  /// 종목 없이 시작만 눌렀을 때 되돌린다.
  void _cancelStart() {
    setState(() {
      _startedAt = null;
      _lastSetAt = null;
    });
    _stopClock();
    WorkoutReminder.cancel();
    _queueDraftSave();
  }

  /// 앱을 닫아 마치지 못한 개인 운동을 저장한다 (임시저장을 되살리기 전에).
  Future<void> _autoSaveClosedWorkouts(AppUser member) async {
    if (_autoSaveChecked || !_tracksTime) return;
    _autoSaveChecked = true;
    final result = await WorkoutAutoSave.run(member);
    if (!mounted || result.count == 0) return;
    final duration = formatWorkoutDuration(result.lastDurationSeconds);
    AppFeedback.showSuccessSnackBar(
      context,
      duration == null ? '지난 운동을 저장했어요' : '지난 운동을 저장했어요 · $duration',
    );
    widget.onRecordsChanged?.call();
  }

  int get _completedSetCount {
    return _sessionExercises.fold(
      0,
      (sum, exercise) => sum + exercise.sets.where((set) => set.done).length,
    );
  }

  /// 모든 세트를 완료한 운동 수.
  int get _doneExerciseCount => _sessionExercises
      .where((e) => e.sets.isNotEmpty && e.sets.every((set) => set.done))
      .length;

  /// 완료한 세트의 볼륨 (kg으로 환산, 유산소 제외).
  double get _completedVolumeKg {
    return _sessionExercises.where((e) => !e.isCardio).fold(0, (sum, e) {
      final volume = e.sets
          .where((set) => set.done)
          .fold<double>(0, (v, set) => v + (set.weight ?? 0) * (set.reps ?? 0));
      return sum + (e.unit == WeightUnit.kg ? volume : volume / kLbsPerKg);
    });
  }

  bool get _isCardioSession {
    return _sessionExercises.isNotEmpty &&
        _sessionExercises.every((exercise) => exercise.isCardio);
  }

  int get _sessionCardioMinutes {
    return _sessionExercises.fold(0, (sum, exercise) {
      if (!exercise.isCardio) return sum;

      return sum +
          exercise.sets.fold(0, (setSum, set) => setSum + (set.reps ?? 0));
    });
  }

  Map<String, PreviousExerciseStats> get _previousStatsByName {
    final result = <String, PreviousExerciseStats>{};

    for (final workout in _previousWorkouts) {
      for (final exercise in workout.exercises) {
        if (result.containsKey(exercise.name)) continue;

        result[exercise.name] = PreviousExerciseStats(
          name: exercise.name,
          date: workout.workoutDate,
          maxWeight: exercise.sets.isEmpty
              ? 0
              : exercise.sets
                    .map((set) => set.weight)
                    .reduce((a, b) => a > b ? a : b),
          totalVolume: exercise.totalVolume,
        );
      }
    }

    return result;
  }

  Future<void> _load() async {
    final actor = context.read<UserProvider>().user;
    final member = widget.targetMember ?? actor;
    if (actor == null || member == null) return;

    setState(() => _loading = true);

    try {
      await _autoSaveClosedWorkouts(member);
      if (!mounted) return;

      final results = await Future.wait([
        WorkoutService.getWorkoutsByDate(
          member.centerId,
          member.uid,
          _selectedDate,
          workoutType: widget.workoutType,
        ),
        WorkoutService.getPreviousWorkouts(
          centerId: member.centerId,
          memberId: member.uid,
          beforeDate: _selectedDate,
          workoutType: widget.workoutType,
        ),
        ExerciseService.getCustomExercises(actor.uid),
      ]);

      if (!mounted) return;

      setState(() {
        _workouts = results[0] as List<Workout>;
        _previousWorkouts = results[1] as List<Workout>;
        _customExercises = results[2] as List<CustomExercise>;
      });

      await _restoreDraftIfNeeded();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restoreDraftIfNeeded() async {
    if (_restoredDraft || _hasSessionContent) return;

    final actor = context.read<UserProvider>().user;
    final member = widget.targetMember ?? actor;
    if (actor == null || member == null) return;

    final draft = await WorkoutDraftService.loadDraft(
      memberId: member.uid,
      workoutDate: _selectedDate,
      workoutType: widget.workoutType.name,
    );

    if (draft == null) return;

    final rawExercises = draft['exercises'];
    final hasExercises = rawExercises is List && rawExercises.isNotEmpty;
    final note = draft['note'] as String? ?? '';
    final started = draftTime(draft, draftStartedAtKey) != null;

    if (!hasExercises && note.trim().isEmpty && !started) return;

    _replaceSessionFromDraft(draft);

    if (!mounted) return;

    setState(() => _restoredDraft = true);

    AppFeedback.showSuccessSnackBar(context, '기록 중이던 운동을 불러왔습니다.');
  }

  void _replaceSessionFromDraft(Map<String, dynamic> draft) {
    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    _sessionExercises.clear();

    final categoryName = draft['defaultCategory'] as String?;
    _defaultCategory = WorkoutCategory.values.firstWhere(
      (category) => category.name == categoryName,
      orElse: () => WorkoutCategory.chest,
    );

    _editingWorkoutId = draft['editingWorkoutId'] as String?;
    _noteController.text = draft['note'] as String? ?? '';

    if (_tracksTime) {
      _startedAt = draftTime(draft, draftStartedAtKey);
      _lastSetAt = draftTime(draft, draftLastSetAtKey);
      _editingDurationSeconds = draft['editingDurationSeconds'] as int?;
      // 오래 전에 시작만 해 두었거나 완료 세트 없이 남은 운동은 시간을 새로 잰다
      // (자동 저장되지 않고 남은 경우 — '운동 중 · 50시간'이 되지 않게).
      final lastActive = _lastSetAt ?? _startedAt;
      if (lastActive != null &&
          DateTime.now().difference(lastActive) >= workoutAutoSaveAfter) {
        _startedAt = null;
        _lastSetAt = null;
      }
      _startClock();
      final lastSetAt = _lastSetAt;
      if (lastSetAt != null) WorkoutReminder.scheduleAfterSet(lastSetAt);
    }

    final rawExercises = draft['exercises'];
    if (rawExercises is List) {
      for (final item in rawExercises) {
        if (item is Map<String, dynamic>) {
          _sessionExercises.add(WorkoutExerciseDraft.fromMap(item));
        } else if (item is Map) {
          _sessionExercises.add(
            WorkoutExerciseDraft.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    _activeIndex = _firstOpenExerciseIndex();
  }

  /// 아직 완료하지 않은 세트가 있는 첫 운동 (없으면 0).
  int _firstOpenExerciseIndex() {
    final index = _sessionExercises.indexWhere(
      (exercise) => exercise.sets.any((set) => !set.done),
    );
    return index < 0 ? 0 : index;
  }

  void _queueDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _persistDraftNow);
  }

  Future<void> _persistDraftNow() async {
    if (!mounted) return;

    final actor = context.read<UserProvider>().user;
    final member = widget.targetMember ?? actor;
    if (actor == null || member == null) return;

    // 마지막 운동까지 지웠으면 예전 임시 저장본도 지운다 (다시 열었을 때 되살아나지 않게).
    if (!_hasSessionContent) {
      await _clearDraft();
      return;
    }

    await WorkoutDraftService.saveDraft(
      memberId: member.uid,
      workoutDate: _selectedDate,
      workoutType: widget.workoutType.name,
      data: {
        'editingWorkoutId': _editingWorkoutId,
        'defaultCategory': _defaultCategory.name,
        'note': _noteController.text.trim(),
        'exercises': _sessionExercises.map((e) => e.toMap()).toList(),
        draftStartedAtKey: _startedAt?.toIso8601String(),
        draftLastSetAtKey: _lastSetAt?.toIso8601String(),
        'editingDurationSeconds': _editingDurationSeconds,
      },
    );
  }

  Future<void> _clearDraft() async {
    if (!mounted) return;

    final actor = context.read<UserProvider>().user;
    final member = widget.targetMember ?? actor;
    if (actor == null || member == null) return;

    await WorkoutDraftService.clearDraft(
      memberId: member.uid,
      workoutDate: _selectedDate,
      workoutType: widget.workoutType.name,
    );
  }

  Future<void> _pickDate() async {
    await _persistDraftNow();
    if (!mounted) return;

    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (!mounted || picked == null) return;

    _clearSession(disposeOnly: true);

    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      _restoredDraft = false;
      _editingWorkoutId = null;
    });

    await _load();
  }

  Future<void> _handleExit() async {
    await _persistDraftNow();

    if (!mounted) return;

    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }

    Navigator.of(context).maybePop();
  }

  Future<void> _showExercisePicker() async {
    final picked = await showAppBottomSheet<PickedExercise>(
      context: context,
      heightFactor: 0.85,
      padded: false,
      child: ExercisePickerSheet(
        memberId: context.read<UserProvider>().user!.uid,
        defaultCategory: _defaultCategory,
        customExercises: _customExercises,
        previousStatsByName: _previousStatsByName,
        onCustomAdded: (exercise) {
          setState(() => _customExercises.add(exercise));
        },
      ),
    );

    if (picked == null) return;

    setState(() {
      _defaultCategory = picked.category;
      _sessionExercises.add(
        WorkoutExerciseDraft(
          name: picked.name,
          category: picked.category,
          sets: [WorkoutSetDraft()],
        ),
      );
      _activeIndex = _sessionExercises.length - 1;
    });

    _queueDraftSave();
  }

  void _addSet(int exerciseIndex) {
    final exercise = _sessionExercises[exerciseIndex];
    final previous = exercise.sets.isNotEmpty ? exercise.sets.last : null;

    setState(() {
      exercise.sets.add(
        WorkoutSetDraft(
          weight: previous?.weightController.text.trim() ?? '',
          reps: previous?.repsController.text.trim() ?? '',
          done: false,
        ),
      );
    });

    _queueDraftSave();
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    final exercise = _sessionExercises[exerciseIndex];

    if (exercise.sets.length == 1) {
      AppFeedback.showWarning(context, '세트는 최소 1개 이상 필요합니다.');
      return;
    }

    setState(() {
      exercise.sets[setIndex].dispose();
      exercise.sets.removeAt(setIndex);
    });

    _queueDraftSave();
  }

  void _removeExercise(int index) {
    setState(() {
      _sessionExercises[index].dispose();
      _sessionExercises.removeAt(index);

      if (index < _activeIndex) _activeIndex--;
      if (_activeIndex >= _sessionExercises.length) {
        _activeIndex = _sessionExercises.isEmpty
            ? 0
            : _sessionExercises.length - 1;
      }
    });

    _queueDraftSave();
  }

  Future<void> _showExerciseMenu(int index) async {
    final exercise = _sessionExercises[index];

    final action = await showAppBottomSheet<ExerciseMenuAction>(
      context: context,
      child: ExerciseMenuSheet(exercise: exercise),
    );

    if (action == null) return;

    switch (action.type) {
      case ExerciseMenuActionType.toggleUnit:
        setState(() {
          final nextUnit = exercise.unit == WeightUnit.kg
              ? WeightUnit.lbs
              : WeightUnit.kg;

          // 손대지 않은 값은 원래 글자로 되돌려 kg ↔ lbs 왕복 오차를 없앤다.
          for (final set in exercise.sets) {
            set.weightController.text = set.unitMemo.toggle(
              set.weightController.text,
              toLbs: nextUnit == WeightUnit.lbs,
            );
          }

          exercise.unit = nextUnit;
        });

        _queueDraftSave();
        break;

      case ExerciseMenuActionType.restTimer:
        setState(() {
          exercise.restSeconds = action.restSeconds ?? exercise.restSeconds;
        });

        _queueDraftSave();
        break;

      case ExerciseMenuActionType.delete:
        _removeExercise(index);
        break;
    }
  }

  void _toggleSetDone(int exerciseIndex, int setIndex) {
    final exercise = _sessionExercises[exerciseIndex];
    final set = exercise.sets[setIndex];
    setState(() => set.done = !set.done);
    // 근력 세트를 완료하면 그 운동의 휴식 시간으로 타이머를 시작한다.
    if (set.done && !exercise.isCardio) {
      RestTimer.instance.start(exercise.restSeconds);
    }
    // 첫 세트를 완료하면 운동 시간이 시작되고, 세트마다 10분 뒤 리마인드를 다시 맞춘다.
    if (set.done && _tracksTime && _editingWorkoutId == null) {
      final now = DateTime.now();
      setState(() {
        _startedAt ??= now;
        _lastSetAt = now;
      });
      _startClock();
      WorkoutReminder.scheduleAfterSet(now);
    }

    _queueDraftSave();
  }

  void _clearSession({bool disposeOnly = false}) {
    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    _sessionExercises.clear();
    _activeIndex = 0;
    _startedAt = null;
    _lastSetAt = null;
    _editingDurationSeconds = null;
    _stopClock();

    if (!disposeOnly) {
      _noteController.clear();
      _editingWorkoutId = null;
    }
  }

  Future<void> _completeWorkout() async {
    final actor = context.read<UserProvider>().user;
    final member = widget.targetMember ?? actor;
    if (actor == null || member == null) return;

    final exercises = <Exercise>[];

    for (final draft in _sessionExercises) {
      final exercise = draft.toExercise();
      if (exercise != null) exercises.add(exercise);
    }

    if (exercises.isEmpty) {
      AppFeedback.showWarning(context, '운동명과 횟수를 입력해주세요. (맨몸 운동은 무게를 비워 두세요)');
      return;
    }

    final wasEditing = _editingWorkoutId != null;
    final tracksTime = _tracksTime;
    // 새 개인 운동: 시작부터 지금('운동 마치기')까지. 고치는 기록: 고친 값(안 고쳤으면 원래 값).
    final startedAt = _startedAt;
    final durationSeconds = !tracksTime
        ? 0
        : wasEditing
        ? (_editingDurationSeconds ?? 0)
        : startedAt == null
        ? 0
        : workoutDurationSeconds(startedAt, DateTime.now());

    // 완료 화면 요약 (세션을 비우기 전에 계산한다)
    final cardioMinutes = _isCardioSession ? _sessionCardioMinutes : null;
    final setCount = exercises.fold<int>(0, (n, e) => n + e.sets.length);
    var volumeKg = 0.0;
    for (final draft in _sessionExercises.where((d) => !d.isCardio)) {
      for (final set in draft.toExercise()?.sets ?? const <ExerciseSet>[]) {
        volumeKg += set.weight * set.reps;
      }
    }

    setState(() => _saving = true);

    try {
      Workout? savedWorkout;

      if (_editingWorkoutId == null) {
        savedWorkout = await WorkoutService.saveWorkout(
          centerId: member.centerId,
          memberId: member.uid,
          memberName: member.name,
          trainerId: widget.workoutType == WorkoutType.pt
              ? actor.uid
              : member.trainerId,
          workoutType: widget.workoutType,
          createdById: actor.uid,
          createdByRole: actor.isTrainer
              ? WorkoutCreatedByRole.trainer
              : WorkoutCreatedByRole.member,
          workoutDate: _selectedDate,
          category: _sessionExercises.first.category,
          exercises: exercises,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          durationSeconds: durationSeconds,
        );
      } else {
        await WorkoutService.updateWorkout(
          workoutId: _editingWorkoutId!,
          category: _sessionExercises.first.category,
          exercises: exercises,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          // PT 기록·트레이너가 고칠 때는 넘기지 않아 원래 값을 둔다.
          durationSeconds: tracksTime ? durationSeconds : null,
        );
      }

      await _clearDraft();
      if (tracksTime) await WorkoutReminder.cancel();

      if (!mounted) return;

      setState(() {
        if (savedWorkout != null) {
          _workouts = [savedWorkout, ..._workouts];
        }

        _clearSession();
        _restoredDraft = false;
      });

      await _load();

      if (!mounted) return;

      RestTimer.instance.skip();
      if (wasEditing || widget.workoutType == WorkoutType.pt) {
        AppFeedback.showSuccessSnackBar(
          context,
          wasEditing ? '운동 기록을 수정했습니다.' : '운동 기록을 저장했습니다.',
        );
      } else {
        await _showDone(
          member: member,
          exerciseCount: exercises.length,
          setCount: setCount,
          volumeKg: volumeKg,
          cardioMinutes: cardioMinutes,
          workoutId: savedWorkout?.id,
          durationSeconds: durationSeconds,
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

  /// 운동 완료 화면 (시안 Done). '확인' → 홈 탭, '기록 자세히 보기' → 저장된 기록으로 내려간다.
  Future<void> _showDone({
    required AppUser member,
    required int exerciseCount,
    required int setCount,
    required double volumeKg,
    required int? cardioMinutes,
    required String? workoutId,
    required int durationSeconds,
  }) async {
    final weekOverWeek = cardioMinutes != null
        ? null
        : await _lastWeekVolume(
            member,
          ).then((last) => last == null ? null : volumeKg - last);
    if (!mounted) return;
    final action = await Navigator.of(context).push<MemberWorkoutDoneAction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MemberWorkoutDoneScreen(
          totalVolumeKg: volumeKg,
          exerciseCount: exerciseCount,
          setCount: setCount,
          cardioMinutes: cardioMinutes,
          weekOverWeekKg: weekOverWeek,
          durationSeconds: durationSeconds,
          // 완료 화면에서 운동 시간을 고치면 저장한 기록에 바로 반영한다.
          onChangeDuration: workoutId == null
              ? null
              : (seconds) => _changeSavedDuration(workoutId, seconds),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case MemberWorkoutDoneAction.detail:
        final target = _savedSectionKey.currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
          );
        }
      case MemberWorkoutDoneAction.home:
      case null:
        widget.onGoHome?.call();
    }
  }

  /// 저장한 기록의 운동 시간만 고친다 (운동 완료 화면). 성공하면 true.
  Future<bool> _changeSavedDuration(String workoutId, int seconds) async {
    try {
      await WorkoutService.updateWorkoutDuration(
        workoutId: workoutId,
        durationSeconds: seconds,
      );
      if (mounted) await _load();
      return true;
    } catch (e) {
      if (mounted) AppFeedback.showErrorSnackBar(context, e);
      return false;
    }
  }

  /// 고치는 기록의 운동 시간 (운동 화면의 '운동 시간' 줄).
  Future<void> _editDuration() async {
    final seconds = await showWorkoutDurationSheet(
      context,
      initialSeconds: _editingDurationSeconds ?? 0,
    );
    if (seconds == null || !mounted) return;
    setState(() => _editingDurationSeconds = seconds);
    _queueDraftSave();
  }

  /// 지난주 같은 요일의 개인 운동 볼륨(kg). 기록이 없거나 불러오지 못하면 null.
  Future<double?> _lastWeekVolume(AppUser member) async {
    final lastWeek = DateTime.parse(
      _selectedDate,
    ).subtract(const Duration(days: 7));
    try {
      final workouts = await WorkoutService.getWorkoutsByDate(
        member.centerId,
        member.uid,
        DateFormat('yyyy-MM-dd').format(lastWeek),
        workoutType: widget.workoutType,
      );
      if (workouts.isEmpty) return null;
      return workouts.fold<double>(0, (sum, w) => sum + w.totalVolume);
    } catch (_) {
      return null;
    }
  }

  void _editWorkout(Workout workout) {
    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    setState(() {
      _sessionExercises.clear();
      _editingWorkoutId = workout.id;
      _defaultCategory = workout.category;
      _noteController.text = workout.note ?? '';
      _startedAt = null;
      _lastSetAt = null;
      _editingDurationSeconds = _tracksTime ? workout.durationSeconds : null;
      _stopClock();

      // 기록에는 부위가 하나만 있으므로 종목 이름으로 부위를 찾아 유산소 표를 맞춘다.
      for (final exercise in workout.exercises) {
        _sessionExercises.add(
          WorkoutExerciseDraft.fromExercise(
            exercise: exercise,
            category:
                exerciseCategoryOf(
                  exercise.name,
                  customExercises: _customExercises,
                ) ??
                workout.category,
          ),
        );
      }
      _activeIndex = 0;
    });

    _queueDraftSave();
    if (_tracksTime) WorkoutReminder.cancel();

    AppFeedback.showSuccessSnackBar(context, '수정 모드로 불러왔습니다.');
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final ok = await showAppConfirmDialog(
      context,
      title: '운동 기록 삭제',
      message:
          '${workout.exercises.length}개 종목, ${workout.totalSets}세트 기록이 삭제됩니다. 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
    );

    if (ok != true) return;

    try {
      await WorkoutService.deleteWorkout(workout.id);

      if (!mounted) return;

      if (_editingWorkoutId == workout.id) {
        setState(() => _clearSession());
        await _clearDraft();
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  ExerciseComparison _comparisonFor(WorkoutExerciseDraft exercise) {
    final previous = _previousStatsByName[exercise.name];

    if (previous == null) {
      return const ExerciseComparison(
        label: '지난 기록 없음',
        tone: ComparisonTone.muted,
      );
    }

    final currentMax = exercise.maxWeight;

    final previousMax = exercise.isCardio
        ? previous.maxWeight
        : exercise.unit == WeightUnit.kg
        ? previous.maxWeight
        : previous.maxWeight * kLbsPerKg;

    final suffix = exercise.primaryMetricSuffix;
    final metricName = exercise.primaryMetricLabel;

    if (currentMax == null) {
      return ExerciseComparison(
        label: exercise.isCardio
            ? '지난 $metricName ${formatMetricValue(previousMax)}$suffix'
            : '지난 최고 ${formatMetricValue(previousMax)}$suffix',
        tone: ComparisonTone.muted,
      );
    }

    final diff = currentMax - previousMax;

    if (diff > 0) {
      return ExerciseComparison(
        label: '+${formatMetricValue(diff)}$suffix',
        tone: ComparisonTone.up,
      );
    }

    if (diff < 0) {
      return ExerciseComparison(
        label: '${formatMetricValue(diff)}$suffix',
        tone: ComparisonTone.down,
      );
    }

    return const ExerciseComparison(label: '동일', tone: ComparisonTone.same);
  }

  /// 머리 제목: 오늘이면 '오늘 운동', 다른 날이면 '10월 7일 운동' (PT 기록은 'PT 운동', 수정 중이면 '운동 수정').
  String get _title {
    if (_editingWorkoutId != null) return '운동 수정';
    if (widget.workoutType == WorkoutType.pt) return 'PT 운동';
    final date = DateTime.parse(_selectedDate);
    if (DateUtils.isSameDay(date, DateTime.now())) return '오늘 운동';
    return '${DateFormat('M월 d일', 'ko').format(date)} 운동';
  }

  /// 접힌 운동 줄 오른쪽: '4세트 · 대기' / '4세트 · 2/4' / '4세트 · 완료'.
  String _collapsedStatus(WorkoutExerciseDraft exercise) {
    final total = exercise.sets.length;
    final done = exercise.sets.where((set) => set.done).length;
    final state = done == 0
        ? '대기'
        : done == total
        ? '완료'
        : '$done/$total';
    return '$total세트 · $state';
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _sessionExercises.isEmpty
        ? 0
        : _activeIndex.clamp(0, _sessionExercises.length - 1);
    final media = MediaQuery.of(context);
    // 탭으로 쓸 때는 아래 탭 바 위에 버튼을 둔다.
    final barBottom = widget.showAsTab ? AppNavBar.totalHeight(context) : 0.0;
    final buttonBottomPadding = widget.showAsTab
        ? AppSpacing.md
        : media.padding.bottom + AppSpacing.md;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 탭으로 쓸 때는 다른 탭과 같은 제목(AppHero), 하위 화면일 때는 뒤로 머리
                  if (widget.showAsTab)
                    AppHero(
                      title: _title,
                      bottomGap: AppSpacing.sm,
                      actions: [
                        AppIconButton(
                          icon: AppIcons.calendar,
                          label: '날짜 선택',
                          iconSize: 24,
                          onPressed: _pickDate,
                        ),
                      ],
                    )
                  else
                    _WorkoutHeader(
                      title: _title,
                      onBack: _handleExit,
                      onPickDate: _pickDate,
                    ),
                  Expanded(
                    child: _loading
                        ? const AppLoadingView()
                        : ListView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              bottom: barBottom + 100 + 80,
                            ),
                            children: [
                              if (_startedAt != null &&
                                  _editingWorkoutId == null)
                                _ElapsedLine(
                                  startedAt: _startedAt!,
                                  onCancel: _sessionExercises.isEmpty
                                      ? _cancelStart
                                      : null,
                                ),
                              if (_sessionExercises.isNotEmpty)
                                WorkoutSummaryStats(
                                  stats: [
                                    WorkoutStat(
                                      '종목',
                                      '$_doneExerciseCount',
                                      ' / ${_sessionExercises.length}',
                                    ),
                                    WorkoutStat('세트', '$_completedSetCount'),
                                    _isCardioSession
                                        ? WorkoutStat(
                                            '시간',
                                            '$_sessionCardioMinutes',
                                            '분',
                                          )
                                        : WorkoutStat(
                                            '볼륨',
                                            NumberFormat('#,##0').format(
                                              _completedVolumeKg.round(),
                                            ),
                                            'kg',
                                          ),
                                  ],
                                ),
                              if (_sessionExercises.isEmpty)
                                _WorkoutEmptyCard(
                                  // 종목을 추가하기 전에 시작할 수 있다 (회원 개인 운동만).
                                  onStart:
                                      _tracksTime &&
                                          _startedAt == null &&
                                          _editingWorkoutId == null
                                      ? _startWorkout
                                      : null,
                                  started: _startedAt != null,
                                )
                              else
                                for (
                                  var index = 0;
                                  index < _sessionExercises.length;
                                  index++
                                )
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: index == 0
                                          ? AppSpacing.base
                                          : AppSpacing.md,
                                    ),
                                    child: index == activeIndex
                                        ? ExerciseInputCard(
                                            order: index + 1,
                                            exercise: _sessionExercises[index],
                                            comparison: _comparisonFor(
                                              _sessionExercises[index],
                                            ),
                                            onChanged: () {
                                              setState(() {});
                                              _queueDraftSave();
                                            },
                                            onAddSet: () => _addSet(index),
                                            onMenuTap: () =>
                                                _showExerciseMenu(index),
                                            onRemoveSet: (setIndex) =>
                                                _removeSet(index, setIndex),
                                            onToggleSetDone: (setIndex) =>
                                                _toggleSetDone(index, setIndex),
                                          )
                                        : WorkoutCollapsedRow(
                                            name: _sessionExercises[index].name,
                                            trailing: _collapsedStatus(
                                              _sessionExercises[index],
                                            ),
                                            onTap: () => setState(
                                              () => _activeIndex = index,
                                            ),
                                          ),
                                  ),
                              _AddExerciseButton(onTap: _showExercisePicker),
                              if (_editingWorkoutId != null &&
                                  _editingDurationSeconds != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                  ),
                                  child: AppActionRow(
                                    icon: AppIcons.timer,
                                    label: '운동 시간',
                                    value:
                                        formatWorkoutDuration(
                                          _editingDurationSeconds!,
                                        ) ??
                                        '기록 없음',
                                    onTap: _editDuration,
                                  ),
                                ),
                              if (_sessionExercises.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.screenH,
                                    AppSpacing.xl,
                                    AppSpacing.screenH,
                                    0,
                                  ),
                                  child: AppTextField(
                                    label: '메모',
                                    hint: '오늘 운동은 어땠나요?',
                                    controller: _noteController,
                                    maxLines: 3,
                                    textInputAction: TextInputAction.newline,
                                  ),
                                ),
                              if (_workouts.isNotEmpty) ...[
                                // 오늘 기록과 저장된 기록 사이: 회색 띠
                                Container(
                                  key: _savedSectionKey,
                                  height: AppSpacing.sm,
                                  margin: const EdgeInsets.only(
                                    top: AppSpacing.xl,
                                  ),
                                  color: AppColors.canvasCard,
                                ),
                                // 시안: 17/500 제목 + 오른쪽 끝 개수(15 mute), 여백 20 20 4
                                AppMonthHeader(
                                  label: '저장된 기록',
                                  count: '${_workouts.length}',
                                  strong: true,
                                ),
                                // 시안 `slide`: 아래 12에서 올라오며 나타남 (.45s, 순번 × .08s)
                                for (var i = 0; i < _workouts.length; i++)
                                  AppEntrance(
                                    key: ValueKey(_workouts[i].id),
                                    offset: const Offset(0, 12),
                                    duration: const Duration(milliseconds: 450),
                                    delay: Duration(milliseconds: 80 * i),
                                    child: SavedWorkoutCard(
                                      workout: _workouts[i],
                                      onEdit: () => _editWorkout(_workouts[i]),
                                      onDelete: () =>
                                          _deleteWorkout(_workouts[i]),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: barBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 시안: 휴식 막대는 아래 버튼 바 위로 4 떨어진다.
                // 막대가 떠 있을 때는 뒤 내용이 틈으로 비치지 않게 흰 면을 깐다.
                ListenableBuilder(
                  listenable: RestTimer.instance,
                  builder: (context, child) => Container(
                    color: RestTimer.instance.isRunning
                        ? AppColors.canvas
                        : null,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      RestTimer.instance.isRunning ? AppSpacing.sm : 0,
                      AppSpacing.screenH,
                      AppSpacing.xs,
                    ),
                    child: child,
                  ),
                  child: const RestTimerBar(),
                ),
                Container(
                  color: AppColors.canvas,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    buttonBottomPadding,
                  ),
                  child: AppButton(
                    label: _saving
                        ? '저장 중'
                        : _editingWorkoutId != null
                        ? '수정 저장'
                        : '운동 마치기',
                    size: AppButtonSize.lg,
                    // 시안 Main 계열 Workout: 17/500 = Bold
                    bold: true,
                    fullWidth: true,
                    isLoading: _saving,
                    // 운동을 하나도 추가하지 않았으면 마칠 것이 없으므로 비활성.
                    onPressed: _saving || _sessionExercises.isEmpty
                        ? null
                        : _completeWorkout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 머리 (56): 왼쪽 뒤로(탭이면 비움) · 가운데 제목 17/700 · 오른쪽 날짜 선택.
class _WorkoutHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback onPickDate;

  const _WorkoutHeader({
    required this.title,
    required this.onBack,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSize.appBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: AppSize.touchMin,
              child: onBack == null
                  ? null
                  : AppIconButton(
                      icon: AppIcons.backBold,
                      label: '뒤로',
                      iconSize: 24,
                      onPressed: onBack,
                    ),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.bold,
                ),
              ),
            ),
            AppIconButton(
              icon: AppIcons.calendar,
              label: '날짜 선택',
              iconSize: 24,
              onPressed: onPickDate,
            ),
          ],
        ),
      ),
    );
  }
}

/// '종목 추가': 52 높이 점선 테두리 상자 (반경 16).
class _AddExerciseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddExerciseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: Semantics(
        button: true,
        label: '종목 추가',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          highlightColor: AppColors.canvasSoft,
          splashFactory: NoSplash.splashFactory,
          child: CustomPaint(
            painter: WorkoutDashedBorderPainter(color: AppColors.outline),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                '종목 추가',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘 운동이 아직 없을 때: 회색 둥근 카드 + 바벨 그림 + 안내 두 줄
/// (+ 회원 개인 운동이면 '운동 시작' 회색 단추 — 누른 때부터 운동 시간을 잰다).
class _WorkoutEmptyCard extends StatelessWidget {
  final VoidCallback? onStart;
  final bool started;

  const _WorkoutEmptyCard({this.onStart, this.started = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 머리 아래 8 (탭 제목 아래 8과 합쳐 16)
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 40),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const LiftingBarbellMark(),
          // 시안: 줄 간격 10 + 제목 위 8
          const SizedBox(height: 18),
          // 시안 MemA-Workout-Empty: 17/500(Medium)
          Text(
            started ? '운동을 시작했어요' : '운동을 추가하고 바로 기록하세요',
            style: AppTextStyles.section,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            started
                ? '아래 \'종목 추가\'로 오늘 할 운동을\n골라 주세요.'
                : '무게, 횟수, 완료 체크를 한 화면에서\n입력할 수 있습니다.',
            style: AppTextStyles.note.copyWith(color: AppColors.mute),
            textAlign: TextAlign.center,
          ),
          if (onStart != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '운동 시작',
              variant: AppButtonVariant.secondary,
              icon: const Icon(AppIcons.timer),
              onPressed: onStart,
            ),
          ],
        ],
      ),
    );
  }
}

/// 진행 중인 운동 시간: 주황 점 + '운동 중 · 32분' 15 body (가운데).
/// 종목 없이 시작만 했으면 오른쪽에 '취소'.
class _ElapsedLine extends StatelessWidget {
  final DateTime startedAt;
  final VoidCallback? onCancel;

  const _ElapsedLine({required this.startedAt, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final elapsed =
        formatWorkoutDuration(
          workoutDurationSeconds(startedAt, DateTime.now()),
        ) ??
        '방금 시작';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '운동 중 · $elapsed',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: AppSpacing.xs),
            AppButton(
              label: '취소',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
