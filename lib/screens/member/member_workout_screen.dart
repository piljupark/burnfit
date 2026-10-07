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
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';
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

  /// 펼쳐서 세트 표를 보여 줄 운동 (나머지는 한 줄로 접는다). 화면 표시 전용 상태.
  int _activeIndex = 0;

  bool _loading = false;
  bool _saving = false;
  bool _restoredDraft = false;

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

    if (!_hasSessionContent) return;

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
      AppFeedback.showSuccessSnackBar(context, '세트는 최소 1개 이상 필요합니다.');
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
        _activeIndex = _sessionExercises.isEmpty ? 0 : _sessionExercises.length - 1;
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
    setState(() {
      final set = _sessionExercises[exerciseIndex].sets[setIndex];
      set.done = !set.done;
    });

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
      AppFeedback.showSuccessSnackBar(context, '운동명, 무게, 횟수를 입력해주세요.');
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
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.backdrop,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.canvasCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.hairline),
          ),
          title: Text('운동 기록 삭제', style: AppTextStyles.title),
          content: Text(
            '${workout.exercises.length}개 종목, ${workout.totalSets}세트 기록이 삭제됩니다. 되돌릴 수 없습니다.',
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

  /// 본문 첫 머리말: 기록 날짜 `10월 7일 (수)` (PT면 `PT · 10월 7일 (수)`).
  String get _dateLabel {
    final day = DateFormat('M월 d일 (E)', 'ko').format(DateTime.parse(_selectedDate));
    return widget.workoutType == WorkoutType.pt ? 'PT · $day' : day;
  }

  /// 머리말 옆 상태: 수정 중 / 진행 중 / 없음.
  String? get _statusLabel => _editingWorkoutId != null
      ? '수정 중'
      : _sessionExercises.isNotEmpty
      ? '진행 중'
      : null;

  String _collapsedSubtitle(WorkoutExerciseDraft exercise) {
    final total = exercise.sets.length;
    final done = exercise.sets.where((set) => set.done).length;
    final max = exercise.maxWeight;
    final metric = max == null
        ? ''
        : ' · ${formatMetricValue(max)}${exercise.primaryMetricSuffix}';
    return '$total세트 · 완료 $done/$total$metric';
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _sessionExercises.isNotEmpty || _editingWorkoutId != null;
    final activeIndex = _sessionExercises.isEmpty
        ? 0
        : _activeIndex.clamp(0, _sessionExercises.length - 1);

    final calendarButton = AppIconButton(
      icon: AppIcons.calendar,
      label: '날짜 선택',
      onPressed: _pickDate,
    );

    final header = widget.showAsTab
        ? AppHero(
            title: '운동',
            actions: [calendarButton],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                child: AppScreenHeader(
                  title: widget.workoutType == WorkoutType.pt ? 'PT 운동' : '운동 기록',
                  onBack: _handleExit,
                  trailing: Transform.translate(
                    offset: const Offset(12, 0),
                    child: calendarButton,
                  ),
                ),
              ),
              const AppRowDivider(),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: _loading
                  ? const AppLoadingView()
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        header,
                        AppMonthHeader(label: _dateLabel, count: _statusLabel),
                        if (hasSession)
                          AppStatStrip(
                            cells: [
                              AppKpiCard(
                                framed: false,
                                valueSize: 20,
                                label: _isCardioSession ? '유산소' : '총 볼륨',
                                value: _isCardioSession
                                    ? '$_sessionCardioMinutes'
                                    : NumberFormat('#,###').format(_sessionVolume.round()),
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
                                value: '${_sessionExercises.length}',
                                unit: '종목',
                              ),
                            ],
                          ),
                        if (_sessionExercises.isEmpty)
                          const AppEmptyState(
                            icon: AppIcons.workout,
                            message: '운동을 추가하고 바로 기록하세요',
                            description: '무게, 횟수, 완료 체크를 한 화면에서 입력할 수 있습니다.',
                          )
                        else ...[
                          for (var index = 0; index < _sessionExercises.length; index++) ...[
                            if (index > 0) const AppRowDivider(),
                            if (index == activeIndex)
                              ExerciseInputCard(
                                order: index + 1,
                                exercise: _sessionExercises[index],
                                comparison: _comparisonFor(_sessionExercises[index]),
                                onChanged: () {
                                  setState(() {});
                                  _queueDraftSave();
                                },
                                onAddSet: () => _addSet(index),
                                onMenuTap: () => _showExerciseMenu(index),
                                onRemoveSet: (setIndex) => _removeSet(index, setIndex),
                                onToggleSetDone: (setIndex) => _toggleSetDone(index, setIndex),
                              )
                            else
                              AppActionRow(
                                icon: AppIcons.workout,
                                label: _sessionExercises[index].name,
                                subtitle: _collapsedSubtitle(_sessionExercises[index]),
                                onTap: () => setState(() => _activeIndex = index),
                              ),
                          ],
                          const AppRowDivider(),
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
                        ],
                        if (_workouts.isNotEmpty) ...[
                          AppMonthHeader(
                            label: '저장된 기록',
                            count: '${_workouts.length}',
                          ),
                          for (final workout in _workouts)
                            SavedWorkoutCard(
                              workout: workout,
                              onEdit: () => _editWorkout(workout),
                              onDelete: () => _deleteWorkout(workout),
                            ),
                        ],
                        SizedBox(height: widget.showAsTab ? 202 : 132),
                      ],
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.showAsTab ? 70 : 0,
            child: _WorkoutBottomBar(
              saving: _saving,
              editing: _editingWorkoutId != null,
              hasContent: _sessionExercises.isNotEmpty,
              onAddExercise: _showExercisePicker,
              onComplete: _completeWorkout,
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래 고정 버튼 줄: 외곽선 "운동 추가" + 주 행동(흰 채움) 하나.
class _WorkoutBottomBar extends StatelessWidget {
  final bool saving;
  final bool editing;
  final bool hasContent;
  final VoidCallback onAddExercise;
  final VoidCallback onComplete;

  const _WorkoutBottomBar({
    required this.saving,
    required this.editing,
    required this.hasContent,
    required this.onAddExercise,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    // 시작 단계 없이 바로 저장한다 (운동 시간은 기록하지 않음).
    final primaryTitle = saving ? '저장 중' : editing ? '수정 저장' : '기록 저장';
    // 운동을 하나도 추가하지 않았으면 저장할 것이 없으므로 비활성.
    final VoidCallback? primaryTap = saving || !hasContent ? null : onComplete;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        bottom + AppSpacing.md,
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
              size: AppButtonSize.lg,
              fullWidth: true,
              icon: const Icon(AppIcons.add),
              onPressed: onAddExercise,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: primaryTitle,
              size: AppButtonSize.lg,
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
