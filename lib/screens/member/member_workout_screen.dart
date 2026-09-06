import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/exercise_data.dart';
import '../../models/custom_exercise.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_draft_service.dart';
import '../../services/workout_service.dart';

const double _workoutCellHeight = 64;
const double _workoutCellRadius = 10;
const double _workoutGap = 8;

String _cardioPrimaryMetricLabel(String name) {
  final n = name.replaceAll(' ', '');

  if (n.contains('러닝머신') || n.contains('인터벌') || n.contains('조깅')) {
    return '속도';
  }

  if (n.contains('인클라인')) {
    return '경사';
  }

  if (n.contains('사이클') || n.contains('싸이클')) {
    return '강도';
  }

  if (n.contains('스텝밀') || n.contains('천국의계단')) {
    return '레벨';
  }

  if (n.contains('일립티컬')) {
    return '강도';
  }

  if (n.contains('로잉')) {
    return '거리';
  }

  if (n.contains('줄넘기') || n.contains('버피')) {
    return '횟수';
  }

  return '강도';
}

String _cardioPrimaryMetricSuffix(String name) {
  final label = _cardioPrimaryMetricLabel(name);

  switch (label) {
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

String _formatMetricValue(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

class MemberWorkoutScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final WorkoutType workoutType;
  final AppUser? targetMember;

  const MemberWorkoutScreen({
    super.key,
    this.onExit,
    this.workoutType = WorkoutType.personal,
    this.targetMember,
  });

  @override
  State<MemberWorkoutScreen> createState() => _MemberWorkoutScreenState();
}

String _inferExerciseCategoryLabel(
  String exerciseName,
  WorkoutCategory fallback,
) {
  for (final entry in ExerciseData.exercises.entries) {
    if (entry.value.contains(exerciseName)) {
      return entry.key.label;
    }
  }

  return fallback.label;
}

class _MemberWorkoutScreenState extends State<MemberWorkoutScreen> {
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final _noteController = TextEditingController();
  final List<_WorkoutExerciseDraft> _sessionExercises = [];

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

  Map<String, _PreviousExerciseStats> get _previousStatsByName {
    final result = <String, _PreviousExerciseStats>{};

    for (final workout in _previousWorkouts) {
      for (final exercise in workout.exercises) {
        if (result.containsKey(exercise.name)) continue;

        result[exercise.name] = _PreviousExerciseStats(
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
          _sessionExercises.add(_WorkoutExerciseDraft.fromMap(item));
        } else if (item is Map) {
          _sessionExercises.add(
            _WorkoutExerciseDraft.fromMap(Map<String, dynamic>.from(item)),
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
    final picked = await showModalBottomSheet<_PickedExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ExercisePickerSheet(
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
        _WorkoutExerciseDraft(
          name: picked.name,
          category: picked.category,
          sets: [_WorkoutSetDraft()],
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
        _WorkoutSetDraft(
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

    final action = await showModalBottomSheet<_ExerciseMenuAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ExerciseMenuSheet(exercise: exercise);
      },
    );

    if (action == null) return;

    switch (action.type) {
      case _ExerciseMenuActionType.toggleUnit:
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

            set.weightController.text = _formatWeight(converted);
          }

          exercise.unit = nextUnit;
        });

        _queueDraftSave();
        break;

      case _ExerciseMenuActionType.restTimer:
        setState(() {
          exercise.restSeconds = action.restSeconds ?? exercise.restSeconds;
        });

        _queueDraftSave();
        break;

      case _ExerciseMenuActionType.delete:
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
          _WorkoutExerciseDraft.fromExercise(
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
            borderRadius: BorderRadius.circular(AppRadius.lg),
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

  _ExerciseComparison _comparisonFor(_WorkoutExerciseDraft exercise) {
    final previous = _previousStatsByName[exercise.name];

    if (previous == null) {
      return const _ExerciseComparison(
        label: '지난 기록 없음',
        tone: _ComparisonTone.muted,
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
      return _ExerciseComparison(
        label: exercise.isCardio
            ? '지난 $metricName ${_formatMetricValue(previousMax)}$suffix'
            : '지난 최고 ${_formatMetricValue(previousMax)}$suffix',
        tone: _ComparisonTone.muted,
      );
    }

    final diff = currentMax - previousMax;

    if (diff > 0) {
      return _ExerciseComparison(
        label: '+${_formatMetricValue(diff)}$suffix',
        tone: _ComparisonTone.up,
      );
    }

    if (diff < 0) {
      return _ExerciseComparison(
        label: '${_formatMetricValue(diff)}$suffix',
        tone: _ComparisonTone.down,
      );
    }

    return const _ExerciseComparison(label: '동일', tone: _ComparisonTone.same);
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _formatWeight(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
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
                                  title: widget.workoutType == WorkoutType.pt
                                      ? 'PT 운동 · ${DateFormat('M월 d일').format(date)}'
                                      : DateFormat('M월 d일').format(date),
                                  onBack: _handleExit,
                                  onDateTap: _pickDate,
                                ),
                                const Gap(20),
                                if (_sessionExercises.isNotEmpty ||
                                    _editingWorkoutId != null) ...[
                                  _WorkoutSummaryBand(
                                    elapsed: _formatDuration(_elapsedSeconds),
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
                                      child: _ExerciseInputCard(
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
                                      child: _SavedWorkoutCard(
                                        workout: workout,
                                        onEdit: () => _editWorkout(workout),
                                        onDelete: () => _deleteWorkout(workout),
                                      ),
                                    ),
                                  ),
                                ],
                                const Gap(132),
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
            bottom: 0,
            child: _WorkoutBottomBar(
              elapsed: _formatDuration(_elapsedSeconds),
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
  final VoidCallback onBack;
  final VoidCallback onDateTap;

  const _WorkoutTopBar({
    required this.title,
    required this.onBack,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconSquareButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
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

class _ExerciseInputCard extends StatelessWidget {
  final int order;
  final _WorkoutExerciseDraft exercise;
  final _ExerciseComparison comparison;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;
  final VoidCallback onMenuTap;
  final void Function(int setIndex) onRemoveSet;
  final void Function(int setIndex) onToggleSetDone;

  const _ExerciseInputCard({
    required this.order,
    required this.exercise,
    required this.comparison,
    required this.onChanged,
    required this.onAddSet,
    required this.onMenuTap,
    required this.onRemoveSet,
    required this.onToggleSetDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$order',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.brand,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${exercise.category.label} | ${exercise.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ComparisonPill(comparison: comparison),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onMenuTap,
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(16),
          Container(height: 1, color: AppColors.border),
          const Gap(14),
          Row(
            children: [
              const Expanded(child: _TableHeaderCell(label: '회차')),
              const SizedBox(width: _workoutGap),
              Expanded(
                child: _TableHeaderCell(label: exercise.primaryMetricLabel),
              ),
              const SizedBox(width: _workoutGap),
              Expanded(
                child: _TableHeaderCell(label: exercise.secondaryMetricLabel),
              ),
              const SizedBox(width: _workoutGap),
              const Expanded(child: _TableHeaderCell(label: '완료')),
            ],
          ),
          const Gap(10),
          ...exercise.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WorkoutSetRow(
                number: index + 1,
                set: set,
                onChanged: onChanged,
                onRemove: () => onRemoveSet(index),
                onToggleDone: () => onToggleSetDone(index),
              ),
            );
          }),
          const Gap(6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: exercise.sets.length > 1
                      ? () => onRemoveSet(exercise.sets.length - 1)
                      : null,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '— 세트삭제',
                      style: AppTextStyles.body.copyWith(
                        color: exercise.sets.length > 1
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onAddSet,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ 세트추가',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;

  const _TableHeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WorkoutSetRow extends StatelessWidget {
  final int number;
  final _WorkoutSetDraft set;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onToggleDone;

  const _WorkoutSetRow({
    required this.number,
    required this.set,
    required this.onChanged,
    required this.onRemove,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _workoutCellHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: onRemove,
              child: _WorkoutInputBox(
                child: Text(
                  '$number',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 25,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _workoutGap),
          Expanded(
            child: _BigNumberField(
              controller: set.weightController,
              decimal: true,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: _workoutGap),
          Expanded(
            child: _BigNumberField(
              controller: set.repsController,
              decimal: false,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: _workoutGap),
          Expanded(
            child: GestureDetector(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: set.done
                      ? AppColors.brand
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(_workoutCellRadius),
                  border: Border.all(
                    color: set.done
                        ? AppColors.brand
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: set.done
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutInputBox extends StatelessWidget {
  final Widget child;

  const _WorkoutInputBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _workoutCellHeight,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(_workoutCellRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _BigNumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool decimal;
  final VoidCallback onChanged;

  const _BigNumberField({
    required this.controller,
    required this.decimal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _WorkoutInputBox(
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: Center(
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d*'),
                ),
              ],
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: AppTextStyles.h2.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.0,
              ),
              strutStyle: const StrutStyle(
                fontSize: 25,
                height: 1.0,
                forceStrutHeight: true,
              ),
              cursorColor: AppColors.brand,
              cursorHeight: 25,
              decoration: const InputDecoration(
                filled: false,
                isCollapsed: true,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonPill extends StatelessWidget {
  final _ExerciseComparison comparison;

  const _ComparisonPill({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final color = switch (comparison.tone) {
      _ComparisonTone.up => AppColors.workout,
      _ComparisonTone.down => AppColors.destructive,
      _ComparisonTone.same => AppColors.brand,
      _ComparisonTone.muted => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        comparison.label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
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

class _SavedWorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavedWorkoutCard({
    required this.workout,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isCardio => workout.category == WorkoutCategory.cardio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _WorkoutTypeBadges(workout: workout),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const Gap(14),
          ...workout.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedExerciseRow(exercise: exercise, isCardio: _isCardio),
            ),
          ),
          const Gap(6),
          Container(height: 1, color: AppColors.border),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _SavedWorkoutFooterMetric(
                  label: '총 볼륨',
                  value: '${workout.totalVolume.toStringAsFixed(0)}kg',
                ),
              ),
              Expanded(
                child: _SavedWorkoutFooterMetric(
                  label: '총 세트',
                  value: '${workout.totalSets}세트',
                ),
              ),
              Expanded(
                child: _SavedWorkoutFooterMetric(
                  label: '운동시간',
                  value: _MemberWorkoutScreenState._formatDuration(
                    workout.durationSeconds,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final bool isCardio;

  const _SavedExerciseRow({required this.exercise, required this.isCardio});

  @override
  Widget build(BuildContext context) {
    final setCount = exercise.sets.length;

    if (isCardio) {
      final metricLabel = _cardioPrimaryMetricLabel(exercise.name);
      final metricSuffix = _cardioPrimaryMetricSuffix(exercise.name);

      final primaryMax = exercise.sets.isEmpty
          ? 0.0
          : exercise.sets
                .map((set) => set.weight)
                .reduce((a, b) => a > b ? a : b);

      final minutes = exercise.sets.fold<int>(0, (sum, set) => sum + set.reps);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SavedBullet(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${exercise.name} · $metricLabel ${_formatMetricValue(primaryMax)}$metricSuffix · $minutes분',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SavedBullet(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${exercise.name} $setCount세트',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedBullet extends StatelessWidget {
  const _SavedBullet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SavedWorkoutFooterMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SavedWorkoutFooterMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.brand,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(4),
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

class _WorkoutTypeBadges extends StatelessWidget {
  final Workout workout;

  const _WorkoutTypeBadges({required this.workout});

  @override
  Widget build(BuildContext context) {
    final labels = workout.exercises
        .map(
          (exercise) =>
              _inferExerciseCategoryLabel(exercise.name, workout.category),
        )
        .toSet()
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) => _CategoryBadge(label: label)).toList(),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textOnAccent,
          fontWeight: FontWeight.w700,
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

class _ExercisePickerSheet extends StatefulWidget {
  final String memberId;
  final WorkoutCategory defaultCategory;
  final List<CustomExercise> customExercises;
  final Map<String, _PreviousExerciseStats> previousStatsByName;
  final void Function(CustomExercise exercise) onCustomAdded;

  const _ExercisePickerSheet({
    required this.memberId,
    required this.defaultCategory,
    required this.customExercises,
    required this.previousStatsByName,
    required this.onCustomAdded,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
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

  List<_PickedExercise> get _items {
    final query = _searchController.text.trim().toLowerCase();

    final defaults = <_PickedExercise>[];

    for (final entry in ExerciseData.exercises.entries) {
      if (_selectedCategory != null && entry.key != _selectedCategory) continue;

      for (final name in entry.value) {
        defaults.add(_PickedExercise(name: name, category: entry.key));
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
          (exercise) => _PickedExercise(
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

  bool get _canAddCustom {
    final query = _searchController.text.trim();
    if (query.isEmpty) return false;

    final exact = _items.any((item) => item.name == query);
    return !exact;
  }

  Future<void> _addCustom() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    setState(() => _addingCustom = true);

    try {
      final exercise = await ExerciseService.addCustomExercise(
        memberId: widget.memberId,
        name: name,
        category: _selectedCategory ?? widget.defaultCategory,
      );

      widget.onCustomAdded(exercise);

      if (!mounted) return;

      Navigator.of(context).pop(
        _PickedExercise(
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

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Gap(12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '운동 추가',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(14),
                    TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyLarge,
                      cursorColor: AppColors.brand,
                      decoration: InputDecoration(
                        hintText: '운동명 검색 또는 직접 입력',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.brand,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PickerChip(
                            label: '전체',
                            selected: _selectedCategory == null,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          ...WorkoutCategory.values.map(
                            (category) => _PickerChip(
                              label: category.label,
                              selected: _selectedCategory == category,
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_canAddCustom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: GestureDetector(
                    onTap: _addingCustom ? null : _addCustom,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _addingCustom
                            ? '추가 중...'
                            : '"${_searchController.text.trim()}" 새 운동으로 추가',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(8),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final previous = widget.previousStatsByName[item.name];

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    item.custom
                                        ? '${item.category.label} · 직접 추가'
                                        : item.category.label,
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (previous != null)
                              Text(
                                '지난 ${_MemberWorkoutScreenState._formatWeight(previous.maxWeight)}kg',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand
              : AppColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.brand
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected
                ? AppColors.textOnAccent
                : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WorkoutExerciseDraft {
  final String name;
  final WorkoutCategory category;
  final List<_WorkoutSetDraft> sets;
  WeightUnit unit;
  int restSeconds;

  _WorkoutExerciseDraft({
    required this.name,
    required this.category,
    required this.sets,
    this.unit = WeightUnit.kg,
    this.restSeconds = 90,
  });

  factory _WorkoutExerciseDraft.fromExercise({
    required Exercise exercise,
    required WorkoutCategory category,
  }) {
    return _WorkoutExerciseDraft(
      name: exercise.name,
      category: category,
      unit: WeightUnit.kg,
      restSeconds: 90,
      sets: exercise.sets
          .map(
            (set) => _WorkoutSetDraft(
              weight: _MemberWorkoutScreenState._formatWeight(set.weight),
              reps: set.reps.toString(),
              done: true,
            ),
          )
          .toList(),
    );
  }

  factory _WorkoutExerciseDraft.fromMap(Map<String, dynamic> map) {
    final categoryName = map['category'] as String?;
    final unitName = map['unit'] as String?;
    final restSeconds = map['restSeconds'] as int? ?? 90;

    final rawSets = map['sets'];
    final sets = <_WorkoutSetDraft>[];

    if (rawSets is List) {
      for (final item in rawSets) {
        if (item is Map<String, dynamic>) {
          sets.add(_WorkoutSetDraft.fromMap(item));
        } else if (item is Map) {
          sets.add(_WorkoutSetDraft.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return _WorkoutExerciseDraft(
      name: map['name'] as String? ?? '',
      category: WorkoutCategory.values.firstWhere(
        (category) => category.name == categoryName,
        orElse: () => WorkoutCategory.chest,
      ),
      unit: WeightUnit.values.firstWhere(
        (unit) => unit.name == unitName,
        orElse: () => WeightUnit.kg,
      ),
      restSeconds: restSeconds,
      sets: sets.isEmpty ? [_WorkoutSetDraft()] : sets,
    );
  }

  double get totalVolume {
    return sets.fold(
      0,
      (sum, set) => sum + ((set.weight ?? 0) * (set.reps ?? 0)),
    );
  }

  double? get maxWeight {
    final values = sets.map((set) => set.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get isCardio => category == WorkoutCategory.cardio;

  String get primaryMetricLabel {
    if (isCardio) return _cardioPrimaryMetricLabel(name);
    return unit.label;
  }

  String get secondaryMetricLabel {
    if (isCardio) return '시간';
    return '회';
  }

  String get primaryMetricSuffix {
    if (isCardio) return _cardioPrimaryMetricSuffix(name);
    return unit.label;
  }

  Exercise? toExercise() {
    final validSets = <ExerciseSet>[];

    for (final set in sets) {
      final rawWeight = set.weight;
      final reps = set.reps;

      if (rawWeight == null || rawWeight <= 0 || reps == null || reps <= 0) {
        continue;
      }

      final weightInKg = unit == WeightUnit.kg
          ? rawWeight
          : rawWeight / 2.2046226218;

      validSets.add(ExerciseSet(weight: weightInKg, reps: reps));
    }

    if (name.trim().isEmpty || validSets.isEmpty) return null;

    return Exercise(name: name.trim(), sets: validSets);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'unit': unit.name,
      'restSeconds': restSeconds,
      'sets': sets.map((set) => set.toMap()).toList(),
    };
  }

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _WorkoutSetDraft {
  final TextEditingController weightController;
  final TextEditingController repsController;
  bool done;

  _WorkoutSetDraft({String weight = '', String reps = '', this.done = false})
    : weightController = TextEditingController(text: weight),
      repsController = TextEditingController(text: reps);

  factory _WorkoutSetDraft.fromMap(Map<String, dynamic> map) {
    return _WorkoutSetDraft(
      weight: map['weight']?.toString() ?? '',
      reps: map['reps']?.toString() ?? '',
      done: map['done'] as bool? ?? false,
    );
  }

  double? get weight => double.tryParse(weightController.text.trim());
  int? get reps => int.tryParse(repsController.text.trim());

  Map<String, dynamic> toMap() {
    return {
      'weight': weightController.text.trim(),
      'reps': repsController.text.trim(),
      'done': done,
    };
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class _PickedExercise {
  final String name;
  final WorkoutCategory category;
  final bool custom;

  const _PickedExercise({
    required this.name,
    required this.category,
    this.custom = false,
  });
}

class _PreviousExerciseStats {
  final String name;
  final String date;
  final double maxWeight;
  final double totalVolume;

  const _PreviousExerciseStats({
    required this.name,
    required this.date,
    required this.maxWeight,
    required this.totalVolume,
  });
}

enum _ComparisonTone { up, down, same, muted }

enum WeightUnit { kg, lbs }

enum _ExerciseMenuActionType { toggleUnit, restTimer, delete }

class _ExerciseMenuAction {
  final _ExerciseMenuActionType type;
  final int? restSeconds;

  const _ExerciseMenuAction({required this.type, this.restSeconds});
}

class _ExerciseComparison {
  final String label;
  final _ComparisonTone tone;

  const _ExerciseComparison({required this.label, required this.tone});
}

class _ExerciseMenuSheet extends StatelessWidget {
  final _WorkoutExerciseDraft exercise;

  const _ExerciseMenuSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final nextUnit = exercise.unit == WeightUnit.kg ? 'lbs' : 'kg';

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Gap(18),
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text(
                  '${exercise.category.label} · 현재 단위 ${exercise.unit.label}',
                  style: AppTextStyles.bodySmall,
                ),
                const Gap(20),
                _ExerciseMenuTile(
                  icon: Icons.swap_horiz_rounded,
                  title: '무게 단위 변경',
                  subtitle: '${exercise.unit.label} → $nextUnit',
                  onTap: () {
                    Navigator.of(context).pop(
                      const _ExerciseMenuAction(
                        type: _ExerciseMenuActionType.toggleUnit,
                      ),
                    );
                  },
                ),
                const Gap(10),
                _ExerciseMenuTile(
                  icon: Icons.timer_outlined,
                  title: '휴식 타이머',
                  subtitle: '${exercise.restSeconds}초',
                  onTap: () async {
                    final seconds = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          _RestTimerSheet(initialSeconds: exercise.restSeconds),
                    );

                    if (seconds == null || !context.mounted) return;

                    Navigator.of(context).pop(
                      _ExerciseMenuAction(
                        type: _ExerciseMenuActionType.restTimer,
                        restSeconds: seconds,
                      ),
                    );
                  },
                ),
                const Gap(10),
                _ExerciseMenuTile(
                  icon: Icons.delete_outline_rounded,
                  title: '운동 삭제',
                  subtitle: '이 운동을 기록에서 제거합니다',
                  danger: true,
                  onTap: () {
                    Navigator.of(context).pop(
                      const _ExerciseMenuAction(
                        type: _ExerciseMenuActionType.delete,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _ExerciseMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.destructive
        : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(4),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestTimerSheet extends StatelessWidget {
  final int initialSeconds;

  const _RestTimerSheet({required this.initialSeconds});

  @override
  Widget build(BuildContext context) {
    final options = [30, 45, 60, 90, 120, 180];

    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Gap(18),
                Text(
                  '휴식 타이머',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text('운동별 기본 휴식 시간을 설정합니다.', style: AppTextStyles.bodySmall),
                const Gap(20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((seconds) {
                    final selected = seconds == initialSeconds;

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(seconds),
                      child: Container(
                        width: 96,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brand
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.brand
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '$seconds초',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: selected
                                ? AppColors.textOnAccent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension WeightUnitLabel on WeightUnit {
  String get label {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lbs:
        return 'lbs';
    }
  }
}
