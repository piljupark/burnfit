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
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import 'trainer_exercise_input.dart';
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

  bool _loading = false;
  bool _saving = false;
  bool _sessionStarted = false;
  String? _errorMessage;

  DateTime _startedAt = DateTime.now();
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  String get _workoutDate =>
      DateFormat('yyyy-MM-dd').format(widget.session.scheduledAt);

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_sessionStarted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });
    _load();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
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
        ),
        WorkoutService.getPreviousWorkouts(
          centerId: widget.member.centerId,
          memberId: widget.member.uid,
          beforeDate: _workoutDate,
          workoutType: WorkoutType.pt,
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

    final picked = await showModalBottomSheet<TrainerPickedExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainerExercisePickerSheet(
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
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
  }

  void _toggleSetDone(int exerciseIndex, int setIndex) {
    setState(() {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.done = !set.done;
      if (set.done && !_sessionStarted) {
        _sessionStarted = true;
        _startedAt = DateTime.now().subtract(
          Duration(seconds: _elapsedSeconds),
        );
      }
    });
  }

  Future<void> _showExerciseMenu(int index) async {
    final exercise = _exercises[index];
    final action = await showModalBottomSheet<TrainerMenuAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainerExerciseMenuSheet(exercise: exercise),
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
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _sessionStarted = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('운동명, 무게, 횟수를 입력해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final wasEditing = _editingWorkoutId != null;

      if (_editingWorkoutId == null) {
        final saved = await WorkoutService.saveWorkout(
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
          durationSeconds: _elapsedSeconds,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

        if (!_savedWorkouts.any((w) => w.ptSessionId == widget.session.id)) {
          await FirestoreService.updatePtSessionStatus(
            widget.session.id,
            PtSessionStatus.completed,
          );
        }

        if (!mounted) return;
        setState(() => _savedWorkouts = [saved, ..._savedWorkouts]);
      } else {
        await WorkoutService.updateWorkout(
          workoutId: _editingWorkoutId!,
          category: _exercises.first.category,
          exercises: exercises,
          durationSeconds: _elapsedSeconds,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }

      if (!mounted) return;
      setState(_clearSession);
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
    for (final e in _exercises) {
      e.dispose();
    }
    setState(() {
      _exercises.clear();
      _editingWorkoutId = workout.id;
      _defaultCategory = workout.category;
      _noteController.text = workout.note ?? '';
      _elapsedSeconds = workout.durationSeconds;
      _sessionStarted = false;
      _startedAt = DateTime.now().subtract(
        Duration(seconds: workout.durationSeconds),
      );

      for (final exercise in workout.exercises) {
        _exercises.add(
          TrainerExerciseDraft.fromExercise(
            exercise: exercise,
            category: workout.category,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('수정 모드로 불러왔습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final body = AppTextStyles.body;
        const w600 = FontWeight.w600;
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          title: Text('운동 삭제', style: AppTextStyles.h3),
          content: Text(
            '이 운동 기록을 삭제할까요?',
            style: body.copyWith(color: AppColors.textSecondary),
          ),
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
                  fontWeight: w600,
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
    final sessionDate = DateFormat('M월 d일').format(widget.session.scheduledAt);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: AppErrorCard(
                        message: _errorMessage!,
                        onRetry: _load,
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenH,
                              AppSpacing.md,
                              AppSpacing.screenH,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TopBar(
                                  memberName: widget.member.name,
                                  sessionDate: sessionDate,
                                  onBack: () => Navigator.of(context).pop(),
                                ),
                                const Gap(20),
                                if (_exercises.isNotEmpty ||
                                    _editingWorkoutId != null) ...[
                                  _SummaryBand(
                                    elapsed:
                                        trainerFormatDuration(_elapsedSeconds),
                                    volume: _sessionVolume,
                                    cardioMinutes: _cardioMinutes,
                                    cardioMode: _isCardioSession,
                                    completedSets: _completedSetCount,
                                    totalSets: _totalSetCount,
                                    editing: _editingWorkoutId != null,
                                  ),
                                  const Gap(20),
                                ],
                                if (_exercises.isEmpty)
                                  _EmptyCard(onAddExercise: _showExercisePicker)
                                else ...[
                                  ..._exercises.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final exercise = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: TrainerExerciseInputCard(
                                        order: index + 1,
                                        exercise: exercise,
                                        comparison: _comparisonFor(exercise),
                                        onChanged: () => setState(() {}),
                                        onAddSet: () => _addSet(index),
                                        onMenuTap: () =>
                                            _showExerciseMenu(index),
                                        onRemoveSet: (si) =>
                                            _removeSet(index, si),
                                        onToggleSetDone: (si) =>
                                            _toggleSetDone(index, si),
                                      ),
                                    );
                                  }),
                                  _NoteField(controller: _noteController),
                                ],
                                if (_savedWorkouts.isNotEmpty) ...[
                                  const Gap(24),
                                  Text(
                                    '저장된 PT 기록',
                                    style: AppTextStyles.h3.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(12),
                                  ..._savedWorkouts.map(
                                    (workout) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: TrainerSavedWorkoutCard(
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
            child: _BottomBar(
              elapsed: trainerFormatDuration(_elapsedSeconds),
              saving: _saving,
              editing: _editingWorkoutId != null,
              sessionStarted: _sessionStarted,
              hasContent: _hasContent,
              onAddExercise: _showExercisePicker,
              onStart: () {
                if (_sessionStarted) return;
                setState(() {
                  _sessionStarted = true;
                  _startedAt = DateTime.now().subtract(
                    Duration(seconds: _elapsedSeconds),
                  );
                });
              },
              onSave: _saveWorkout,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String memberName;
  final String sessionDate;
  final VoidCallback onBack;

  const _TopBar({
    required this.memberName,
    required this.sessionDate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$memberName · PT 운동',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(sessionDate, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final String elapsed;
  final double volume;
  final int completedSets;
  final int totalSets;
  final bool editing;
  final int cardioMinutes;
  final bool cardioMode;

  const _SummaryBand({
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editing) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '수정 중',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: _Metric(label: '운동시간', value: elapsed),
              ),
              Expanded(
                child: _Metric(
                  label: cardioMode ? '총 시간' : '총 볼륨',
                  value: cardioMode
                      ? '$cardioMinutes분'
                      : '${volume.toStringAsFixed(0)}kg',
                ),
              ),
              Expanded(
                child: _Metric(
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

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

class _EmptyCard extends StatelessWidget {
  final VoidCallback onAddExercise;

  const _EmptyCard({required this.onAddExercise});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddExercise,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.xl2,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.textOnAccent,
                size: 32,
              ),
            ),
            const Gap(18),
            Text(
              'PT 운동을 기록하세요.',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(6),
            Text(
              '운동을 추가하고 세트, 중량, 횟수를 입력하세요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}


class _NoteField extends StatelessWidget {
  final TextEditingController controller;

  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
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


class _BottomBar extends StatelessWidget {
  final String elapsed;
  final bool saving;
  final bool editing;
  final bool sessionStarted;
  final bool hasContent;
  final VoidCallback onAddExercise;
  final VoidCallback onStart;
  final VoidCallback onSave;

  const _BottomBar({
    required this.elapsed,
    required this.saving,
    required this.editing,
    required this.sessionStarted,
    required this.hasContent,
    required this.onAddExercise,
    required this.onStart,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    final primaryTitle = saving
        ? '저장 중...'
        : editing
        ? '수정 저장'
        : sessionStarted
        ? '기록 저장'
        : '세션 시작';

    final primaryTap = saving
        ? null
        : editing
        ? onSave
        : sessionStarted
        ? onSave
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
            child: _ActionBox(
              title: elapsed,
              subtitle: '운동시간',
              primary: false,
              onTap: null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBox(
              title: '+ 운동 추가',
              subtitle: null,
              primary: false,
              onTap: onAddExercise,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBox(
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

class _ActionBox extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool primary;
  final VoidCallback? onTap;

  const _ActionBox({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppColors.brand : AppColors.card;
    final foreground = primary ? AppColors.textOnAccent : AppColors.brand;
    final subColor = primary ? AppColors.textOnAccent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: primary
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
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
