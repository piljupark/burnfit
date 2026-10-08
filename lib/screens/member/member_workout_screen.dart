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
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_draft_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_bottom_sheet.dart';
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
import 'member_workout_done_screen.dart';
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

  const MemberWorkoutScreen({
    super.key,
    this.onExit,
    this.onGoHome,
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

  // 운동 시간은 기록하지 않는다 (피드백: 운동일지에 전체 운동 시간은 필요 없음).
  // 유산소 세트의 '시간'은 운동 내용이므로 세트 값으로 그대로 입력한다.
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();

    _noteController.addListener(_queueDraftSave);
    _load();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _noteController.dispose();
    _scrollController.dispose();

    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    super.dispose();
  }

  bool get _hasSessionContent {
    return _sessionExercises.isNotEmpty ||
        _noteController.text.trim().isNotEmpty;
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
      return sum + (e.unit == WeightUnit.kg ? volume : volume / 2.2046226218);
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

    if (!hasExercises && note.trim().isEmpty) return;

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

          for (final set in exercise.sets) {
            final value = set.weight;
            if (value == null) continue;

            final converted = exercise.unit == WeightUnit.kg
                ? value * 2.2046226218
                : value / 2.2046226218;

            set.weightController.text = formatWeight(converted);
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

    _queueDraftSave();
  }

  void _clearSession({bool disposeOnly = false}) {
    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    _sessionExercises.clear();
    _activeIndex = 0;

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
        );
      } else {
        await WorkoutService.updateWorkout(
          workoutId: _editingWorkoutId!,
          category: _sessionExercises.first.category,
          exercises: exercises,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }

      await _clearDraft();

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

      for (final exercise in workout.exercises) {
        _sessionExercises.add(
          WorkoutExerciseDraft.fromExercise(
            exercise: exercise,
            category: workout.category,
          ),
        );
      }
      _activeIndex = 0;
    });

    _queueDraftSave();

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
        : previous.maxWeight * 2.2046226218;

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
    final barBottom = widget.showAsTab
        ? AppNavBar.totalHeight(context)
        : 0.0;
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
                              if (_sessionExercises.isNotEmpty)
                                _SessionStats(
                                  doneExercises: _doneExerciseCount,
                                  totalExercises: _sessionExercises.length,
                                  doneSets: _completedSetCount,
                                  cardioMinutes: _isCardioSession
                                      ? _sessionCardioMinutes
                                      : null,
                                  volumeKg: _completedVolumeKg,
                                ),
                              if (_sessionExercises.isEmpty)
                                const _WorkoutEmptyCard()
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
                                        : _CollapsedExercise(
                                            name: _sessionExercises[index].name,
                                            status: _collapsedStatus(
                                              _sessionExercises[index],
                                            ),
                                            onTap: () => setState(
                                              () => _activeIndex = index,
                                            ),
                                          ),
                                  ),
                              _AddExerciseButton(onTap: _showExercisePicker),
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

/// 요약 3칸 (회색, 반경 16): 종목 완료/전체 · 완료 세트 · 볼륨(kg) — 유산소만이면 볼륨 대신 시간(분).
class _SessionStats extends StatelessWidget {
  final int doneExercises;
  final int totalExercises;
  final int doneSets;
  final int? cardioMinutes;
  final double volumeKg;

  const _SessionStats({
    required this.doneExercises,
    required this.totalExercises,
    required this.doneSets,
    required this.cardioMinutes,
    required this.volumeKg,
  });

  @override
  Widget build(BuildContext context) {
    // 시안 `up`: 아래 10에서 올라오며 나타남 (.5s, 칸마다 .08s 늦게)
    Widget cell(int order, String label, String value, String? suffix) {
      return Expanded(
        child: AppEntrance(
          delay: Duration(milliseconds: 80 * order),
          child: Semantics(
            label: '$label $value${suffix ?? ''}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.canvasCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 12 * -0.019,
                      color: AppColors.caption,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: value),
                        if (suffix != null)
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
                    // 시안 20/500(Bold), 줄 높이 기본(약 24)
                    style: AppTextStyles.title.bold.copyWith(height: 24 / 20),
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
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          cell(0, '종목', '$doneExercises', ' / $totalExercises'),
          const SizedBox(width: AppSpacing.sm),
          cell(1, '세트', '$doneSets', null),
          const SizedBox(width: AppSpacing.sm),
          cardioMinutes != null
              ? cell(2, '시간', '$cardioMinutes', '분')
              : cell(
                  2,
                  '볼륨',
                  NumberFormat('#,##0').format(volumeKg.round()),
                  'kg',
                ),
        ],
      ),
    );
  }
}

/// 접힌 운동 한 줄 (회색 60, 반경 20): 이름 16/700 · 오른쪽 상태 13 mute.
class _CollapsedExercise extends StatelessWidget {
  final String name;
  final String status;
  final VoidCallback onTap;

  const _CollapsedExercise({
    required this.name,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Semantics(
        button: true,
        label: '$name, $status, 펼치기',
        excludeSemantics: true,
        child: Material(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.listTitle.bold,
                    ),
                  ),
                  Text(
                    status,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

/// 오늘 운동이 아직 없을 때: 회색 둥근 카드 + 바벨 그림 + 안내 두 줄.
class _WorkoutEmptyCard extends StatelessWidget {
  const _WorkoutEmptyCard();

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
          const _LiftingBarbell(),
          // 시안: 줄 간격 10 + 제목 위 8
          const SizedBox(height: 18),
          // 시안 MemA-Workout-Empty: 17/500(Medium)
          Text(
            '운동을 추가하고 바로 기록하세요',
            style: AppTextStyles.section,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '무게, 횟수, 완료 체크를 한 화면에서\n입력할 수 있습니다.',
            style: AppTextStyles.note.copyWith(color: AppColors.mute),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 바벨 그림 (64×40)이 위아래로 6씩 들렸다 내려간다 (시안 `lift`: 1.8s ease-in-out 반복).
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
          size: Size(64, 40),
          painter: _BarbellArtPainter(),
        ),
        builder: (context, child) {
          // 0%·100% → +6, 50% → −6
          final v = _controller.value;
          final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
          final dy = 6 - 12 * Curves.easeInOut.transform(tri);
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
      ),
    );
  }
}

/// 시안 SVG(viewBox 200×110)를 64×40에 비율 맞춰 그린 바벨:
/// 회색 봉(#9A9AA0) + 검정 원판 넷 + 가운데 주황 손잡이.
class _BarbellArtPainter extends CustomPainter {
  const _BarbellArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200;
    canvas.translate(0, (size.height - 110 * k) / 2);
    canvas.scale(k);
    void rrect(double x, double y, double w, double h, double r, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    rrect(40, 49, 120, 12, 6, AppColors.faint);
    rrect(26, 23, 22, 64, 8, AppColors.ink);
    rrect(8, 33, 18, 44, 7, AppColors.ink);
    rrect(152, 23, 22, 64, 8, AppColors.ink);
    rrect(174, 33, 18, 44, 7, AppColors.ink);
    rrect(80, 46, 40, 18, 9, AppColors.primary);
  }

  @override
  // 색이 테마를 따르므로 다시 그릴 때마다 칠한다 (그림이 작아 부담 없음).
  bool shouldRepaint(_BarbellArtPainter oldDelegate) => true;
}
