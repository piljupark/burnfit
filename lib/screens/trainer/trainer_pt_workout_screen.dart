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
import '../../models/pt_session.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/exercise_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';
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

  /// 펼쳐 보이는(현재) 운동 위치. 화면 표시 전용 상태다.
  int _focusedIndex = 0;

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

    final picked = await showAppBottomSheet<TrainerPickedExercise>(
      context: context,
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
      AppFeedback.showSuccessSnackBar(context, '세트는 최소 1개 이상 필요합니다.');
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
      AppFeedback.showSuccessSnackBar(context, '운동명, 무게, 횟수를 입력해주세요.');
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
      AppFeedback.showSuccessSnackBar(
        context,
        wasEditing ? '운동 기록을 수정했습니다.' : '운동 기록을 저장했습니다.',
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
      _focusedIndex = 0;
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

    AppFeedback.showSuccessSnackBar(context, '수정 모드로 불러왔습니다.');
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('PT 기록 삭제', style: AppTextStyles.title),
        content: Text(
          '운동 ${workout.exercises.length}개, ${workout.totalSets}세트 기록이 삭제되며 되돌릴 수 없습니다.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
        ),
        actions: [
          AppButton(
            label: '취소',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: '삭제',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
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

  void _startSession() {
    if (_sessionStarted) return;
    setState(() {
      _sessionStarted = true;
      _startedAt = DateTime.now().subtract(
        Duration(seconds: _elapsedSeconds),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editingWorkoutId != null;
    final canSave = (_sessionStarted || editing) && _hasContent;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: 'PT 기록',
                onBack: () => Navigator.of(context).pop(),
                trailing: canSave
                    ? Transform.translate(
                        offset: const Offset(12, 0),
                        child: AppButton(
                          label: '저장',
                          variant: AppButtonVariant.ghost,
                          onPressed: _saving ? null : _saveWorkout,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(child: _buildBody(editing)),
            _BottomBar(
              saving: _saving,
              editing: editing,
              sessionStarted: _sessionStarted,
              onAddExercise: _showExercisePicker,
              onStart: _startSession,
              onSave: _saveWorkout,
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
          member: widget.member,
          subtitle: subtitle,
          elapsed: trainerFormatDuration(_elapsedSeconds),
          running: _sessionStarted,
          editing: editing,
        ),
        if (_exercises.isNotEmpty || editing)
          AppStatStrip(
            topBorder: true,
            cells: [
              AppKpiCard(
                framed: false,
                valueSize: 20,
                label: _isCardioSession ? '총 시간' : '총 볼륨',
                value: _isCardioSession
                    ? '$_cardioMinutes'
                    : NumberFormat('#,##0').format(_sessionVolume.round()),
                unit: _isCardioSession ? '분' : 'kg',
              ),
              AppKpiCard(
                framed: false,
                valueSize: 20,
                label: '완료세트',
                value: '$_completedSetCount/$_totalSetCount',
                unit: '',
              ),
              AppKpiCard(
                framed: false,
                valueSize: 20,
                label: '운동',
                value: '${_exercises.length}',
                unit: '종목',
              ),
            ],
          ),
        if (_exercises.isEmpty)
          const AppEmptyState(
            icon: AppIcons.workout,
            message: 'PT 운동을 기록하세요',
            description: '아래 운동 추가로 운동을 고르고 세트, 중량, 횟수를 입력하세요.',
          )
        else ...[
          for (var i = 0; i < _exercises.length; i++) ...[
            if (i == focused) ...[
              TrainerExerciseInputCard(
                order: i + 1,
                exercise: _exercises[i],
                comparison: _comparisonFor(_exercises[i]),
                onChanged: () => setState(() {}),
                onAddSet: () => _addSet(i),
                onMenuTap: () => _showExerciseMenu(i),
                onRemoveSet: (si) => _removeSet(i, si),
                onToggleSetDone: (si) => _toggleSetDone(i, si),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else
              AppActionRow(
                icon: AppIcons.workout,
                label: _exercises[i].name,
                subtitle: trainerExerciseRowSummary(_exercises[i]),
                onTap: () => setState(() => _focusedIndex = i),
              ),
            const AppRowDivider(),
          ],
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
          AppMonthHeader(
            label: '저장된 PT 기록',
            count: '${_savedWorkouts.length}',
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl2,
              AppSpacing.screenH,
              0,
            ),
          ),
          for (final workout in _savedWorkouts)
            TrainerSavedWorkoutCard(
              workout: workout,
              onEdit: () => _editWorkout(workout),
              onDelete: () => _deleteWorkout(workout),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────

/// 회원 줄: 아바타 + 이름(17) + 일정 보조 줄 + 오른쪽 큰 모노 세션 타이머.
class _MemberRow extends StatelessWidget {
  final AppUser member;
  final String subtitle;
  final String elapsed;
  final bool running;
  final bool editing;

  const _MemberRow({
    required this.member,
    required this.subtitle,
    required this.elapsed,
    required this.running,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          AppAvatar(name: member.name, seed: member.uid),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg,
                      ),
                    ),
                    if (editing) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const AppTag('수정 중', strong: true),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Semantics(
            label: running ? '운동 시간 $elapsed' : '운동 시간 $elapsed, 시작 전',
            excludeSemantics: true,
            child: Text(
              elapsed,
              style: AppTextStyles.eyebrow.copyWith(
                fontSize: 20,
                height: 28 / 20,
                letterSpacing: 20 * 0.04,
                color: running ? AppColors.ink : AppColors.mute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래 고정 행동: 외곽선 '운동 추가' + 주 행동(세션 시작 / 기록 저장 / 수정 저장).
class _BottomBar extends StatelessWidget {
  final bool saving;
  final bool editing;
  final bool sessionStarted;
  final VoidCallback onAddExercise;
  final VoidCallback onStart;
  final VoidCallback onSave;

  const _BottomBar({
    required this.saving,
    required this.editing,
    required this.sessionStarted,
    required this.onAddExercise,
    required this.onStart,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    final primaryTitle = saving
        ? '저장 중'
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        bottom + AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: '운동 추가',
              variant: AppButtonVariant.secondary,
              icon: const Icon(AppIcons.add),
              fullWidth: true,
              onPressed: onAddExercise,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: primaryTitle,
              fullWidth: true,
              isLoading: saving,
              onPressed: primaryTap,
            ),
          ),
        ],
      ),
    );
  }
}
