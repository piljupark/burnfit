import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/custom_exercise.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_draft_service.dart';
import '../../services/workout_service.dart';
import 'workout_draft_models.dart';
import 'workout_exercise_input.dart';
import 'workout_saved_card.dart';
import 'workout_sheets.dart';

class MemberWorkoutScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final WorkoutType workoutType;
  final AppUser? targetMember;
  final bool showAsTab;

  const MemberWorkoutScreen({
    super.key,
    this.onExit,
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

  bool _loading = false;
  bool _saving = false;
  bool _restoredDraft = false;
  bool _workoutStarted = false;

  DateTime _startedAt = DateTime.now();
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();

    _noteController.addListener(_queueDraftSave);

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_workoutStarted) return;

      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });

    _load();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _draftTimer?.cancel();
    _noteController.dispose();

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

  int get _totalSetCount {
    return _sessionExercises.fold(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
  }

  double get _sessionVolume {
    return _sessionExercises.fold(
      0,
      (sum, exercise) => sum + exercise.totalVolume,
    );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('기록 중이던 운동을 불러왔습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    final elapsed = draft['elapsedSeconds'];
    if (elapsed is int) {
      _elapsedSeconds = elapsed;
      _startedAt = DateTime.now().subtract(Duration(seconds: elapsed));
    }

    _workoutStarted = draft['workoutStarted'] as bool? ?? false;

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

    if (!_hasSessionContent) return;

    await WorkoutDraftService.saveDraft(
      memberId: member.uid,
      workoutDate: _selectedDate,
      workoutType: widget.workoutType.name,
      data: {
        'editingWorkoutId': _editingWorkoutId,
        'defaultCategory': _defaultCategory.name,
        'note': _noteController.text.trim(),
        'elapsedSeconds': _elapsedSeconds,
        'exercises': _sessionExercises.map((e) => e.toMap()).toList(),
        'workoutStarted': _workoutStarted,
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

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (!mounted || picked == null) return;

    _clearSession(disposeOnly: true);

    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      _restoredDraft = false;
      _editingWorkoutId = null;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
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
    final picked = await showModalBottomSheet<PickedExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ExercisePickerSheet(
          memberId: context.read<UserProvider>().user!.uid,
          defaultCategory: _defaultCategory,
          customExercises: _customExercises,
          previousStatsByName: _previousStatsByName,
          onCustomAdded: (exercise) {
            setState(() => _customExercises.add(exercise));
          },
        );
      },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세트는 최소 1개 이상 필요합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    });

    _queueDraftSave();
  }

  Future<void> _showExerciseMenu(int index) async {
    final exercise = _sessionExercises[index];

    final action = await showModalBottomSheet<ExerciseMenuAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ExerciseMenuSheet(exercise: exercise);
      },
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
    setState(() {
      final set = _sessionExercises[exerciseIndex].sets[setIndex];
      set.done = !set.done;

      if (set.done && !_workoutStarted) {
        _workoutStarted = true;
        _startedAt = DateTime.now().subtract(
          Duration(seconds: _elapsedSeconds),
        );
      }
    });

    _queueDraftSave();
  }

  void _clearSession({bool disposeOnly = false}) {
    for (final exercise in _sessionExercises) {
      exercise.dispose();
    }

    _sessionExercises.clear();

    if (!disposeOnly) {
      _noteController.clear();
      _editingWorkoutId = null;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
      _workoutStarted = false;
    }
  }

  void _startWorkout() {
    if (_workoutStarted) return;

    setState(() {
      _workoutStarted = true;
      _startedAt = DateTime.now().subtract(Duration(seconds: _elapsedSeconds));
    });

    _queueDraftSave();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('운동명, 무게, 횟수를 입력해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final wasEditing = _editingWorkoutId != null;

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
          durationSeconds: _elapsedSeconds,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        await WorkoutService.updateWorkout(
          workoutId: _editingWorkoutId!,
          category: _sessionExercises.first.category,
          exercises: exercises,
          durationSeconds: _elapsedSeconds,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasEditing ? '운동 기록을 수정했습니다.' : '운동 기록을 저장했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
      _elapsedSeconds = workout.durationSeconds;
      _workoutStarted = false;
      _startedAt = DateTime.now().subtract(
        Duration(seconds: workout.durationSeconds),
      );

      for (final exercise in workout.exercises) {
        _sessionExercises.add(
          WorkoutExerciseDraft.fromExercise(
            exercise: exercise,
            category: workout.category,
          ),
        );
      }
    });

    _queueDraftSave();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('수정 모드로 불러왔습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final body = AppTextStyles.body;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          title: Text('운동 삭제', style: AppTextStyles.h3),
          content: Text('이 운동 기록을 삭제할까요?', style: AppTextStyles.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                '취소',
                style: body.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '삭제',
                style: body.copyWith(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _WorkoutTopBar(
                                  title: widget.showAsTab
                                      ? '운동'
                                      : widget.workoutType == WorkoutType.pt
                                          ? 'PT 운동 · ${DateFormat('M월 d일').format(date)}'
                                          : DateFormat('M월 d일').format(date),
                                  onBack: widget.showAsTab ? null : _handleExit,
                                  onDateTap: _pickDate,
                                  isTabTitle: widget.showAsTab,
                                ),
                                const Gap(20),
                                if (_sessionExercises.isNotEmpty ||
                                    _editingWorkoutId != null) ...[
                                  _WorkoutSummaryBand(
                                    elapsed: formatDuration(_elapsedSeconds),
                                    volume: _sessionVolume,
                                    cardioMinutes: _sessionCardioMinutes,
                                    cardioMode: _isCardioSession,
                                    completedSets: _completedSetCount,
                                    totalSets: _totalSetCount,
                                    editing: _editingWorkoutId != null,
                                  ),
                                  const Gap(20),
                                ],
                                const Gap(20),
                                if (_sessionExercises.isEmpty)
                                  _EmptySessionCard(
                                    onAddExercise: _showExercisePicker,
                                  )
                                else ...[
                                  ..._sessionExercises.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final exercise = entry.value;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: ExerciseInputCard(
                                        order: index + 1,
                                        exercise: exercise,
                                        comparison: _comparisonFor(exercise),
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
                                      ),
                                    );
                                  }),
                                  _SessionNoteField(
                                    controller: _noteController,
                                  ),
                                ],
                                if (_workouts.isNotEmpty) ...[
                                  const Gap(24),
                                  Text(
                                    '오늘 저장된 기록',
                                    style: AppTextStyles.h3.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(12),
                                  ..._workouts.map(
                                    (workout) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: SavedWorkoutCard(
                                        workout: workout,
                                        onEdit: () => _editWorkout(workout),
                                        onDelete: () => _deleteWorkout(workout),
                                      ),
                                    ),
                                  ),
                                ],
                                Gap(widget.showAsTab ? 202 : 132),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.showAsTab ? 70 : 0,
            child: _WorkoutBottomBar(
              elapsed: formatDuration(_elapsedSeconds),
              saving: _saving,
              editing: _editingWorkoutId != null,
              workoutStarted: _workoutStarted,
              onAddExercise: _showExercisePicker,
              onStart: _startWorkout,
              onComplete: _completeWorkout,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback onDateTap;
  final bool isTabTitle;

  const _WorkoutTopBar({
    required this.title,
    required this.onBack,
    required this.onDateTap,
    this.isTabTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isTabTitle) {
      return Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.h1)),
          _IconSquareButton(icon: Icons.calendar_month_rounded, onTap: onDateTap),
        ],
      );
    }
    return Row(
      children: [
        _IconSquareButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack ?? () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: AppTextStyles.h2.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _IconSquareButton(icon: Icons.calendar_month_rounded, onTap: onDateTap),
      ],
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _WorkoutSummaryBand extends StatelessWidget {
  final String elapsed;
  final double volume;
  final int completedSets;
  final int totalSets;
  final bool editing;
  final int cardioMinutes;
  final bool cardioMode;

  const _WorkoutSummaryBand({
    required this.elapsed,
    required this.volume,
    required this.completedSets,
    required this.totalSets,
    required this.editing,
    required this.cardioMinutes,
    required this.cardioMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '수정 중',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(14),
          ],
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: '운동시간', value: elapsed),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: cardioMode ? '총 시간' : '총 볼륨',
                  value: cardioMode
                      ? '$cardioMinutes분'
                      : '${volume.toStringAsFixed(0)}kg',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '완료세트',
                  value: '$completedSets/$totalSets',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.brand,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(5),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptySessionCard extends StatelessWidget {
  final VoidCallback onAddExercise;

  const _EmptySessionCard({required this.onAddExercise});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddExercise,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.textOnAccent,
                size: 32,
              ),
            ),
            const Gap(18),
            Text(
              '운동을 추가하고 바로 기록하세요.',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(6),
            Text(
              'kg, 회차, 완료 체크를 한 화면에서 빠르게 입력할 수 있습니다.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionNoteField extends StatelessWidget {
  final TextEditingController controller;

  const _SessionNoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 3,
        style: AppTextStyles.bodyLarge,
        cursorColor: AppColors.brand,
        decoration: InputDecoration(
          hintText: '메모',
          hintStyle: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _WorkoutBottomBar extends StatelessWidget {
  final String elapsed;
  final bool saving;
  final bool editing;
  final bool workoutStarted;
  final VoidCallback onAddExercise;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _WorkoutBottomBar({
    required this.elapsed,
    required this.saving,
    required this.editing,
    required this.workoutStarted,
    required this.onAddExercise,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    final primaryTitle = saving
        ? '저장 중...'
        : editing
        ? '수정 저장'
        : workoutStarted
        ? '운동 완료'
        : '운동 시작';

    final primaryTap = saving
        ? null
        : editing
        ? onComplete
        : workoutStarted
        ? onComplete
        : onStart;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomActionBox(
              title: elapsed,
              subtitle: '운동시간',
              primary: false,
              onTap: null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BottomActionBox(
              title: '+ 운동 추가',
              subtitle: null,
              primary: false,
              onTap: onAddExercise,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BottomActionBox(
              title: primaryTitle,
              subtitle: null,
              primary: true,
              onTap: primaryTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBox extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool primary;
  final VoidCallback? onTap;

  const _BottomActionBox({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? AppColors.brand
        : AppColors.card;
    final foreground = primary
        ? AppColors.textOnAccent
        : AppColors.brand;
    final subColor = primary
        ? AppColors.textOnAccent
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: primary ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: foreground,
                fontSize: primary ? 17 : 16,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTextStyles.caption.copyWith(
                  color: subColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
