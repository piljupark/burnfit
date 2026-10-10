import 'package:flutter/material.dart';

import '../core/app_spacing.dart';
import '../core/workout_timing.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_inputs.dart';

/// 운동 시간 고치기 시트: 분 조절기(− 값 +, 숫자를 누르면 직접 입력) + '저장'.
/// 고른 값을 초로 돌려준다. 닫으면 null.
Future<int?> showWorkoutDurationSheet(
  BuildContext context, {
  required int initialSeconds,
}) {
  return showAppBottomSheet<int>(
    context: context,
    child: _WorkoutDurationSheet(initialMinutes: initialSeconds ~/ 60),
  );
}

class _WorkoutDurationSheet extends StatefulWidget {
  final int initialMinutes;

  const _WorkoutDurationSheet({required this.initialMinutes});

  @override
  State<_WorkoutDurationSheet> createState() => _WorkoutDurationSheetState();
}

class _WorkoutDurationSheetState extends State<_WorkoutDurationSheet> {
  late int _minutes = widget.initialMinutes.clamp(0, workoutDurationMaxMinutes);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(
          title: '운동 시간',
          subtitle: '실제로 운동한 시간으로 고쳐 주세요.',
          mutedSubtitle: true,
        ),
        Center(
          child: AppStepper(
            value: _minutes,
            min: 0,
            max: workoutDurationMaxMinutes,
            unit: '분',
            semanticLabel: '운동 시간',
            onChanged: (v) => setState(() => _minutes = v),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: '저장',
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(_minutes * 60),
        ),
      ],
    );
  }
}
