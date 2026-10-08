import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../models/inbody.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_key_value_row.dart';
import '../../widgets/app_text_field.dart';

class TrainerInbodyInputSheet extends StatefulWidget {
  final AppUser member;
  final AppUser trainer;

  const TrainerInbodyInputSheet({
    super.key,
    required this.member,
    required this.trainer,
  });

  @override
  State<TrainerInbodyInputSheet> createState() =>
      _TrainerInbodyInputSheetState();
}

class _TrainerInbodyInputSheetState extends State<TrainerInbodyInputSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _muscleCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _bodyFatPercentCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  final _bmrCtrl = TextEditingController();
  final _visceralFatCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _weightCtrl.dispose();
    _muscleCtrl.dispose();
    _bodyFatCtrl.dispose();
    _bodyFatPercentCtrl.dispose();
    _bmiCtrl.dispose();
    _bmrCtrl.dispose();
    _visceralFatCtrl.dispose();
    super.dispose();
  }

  double? _doubleOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? _intOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  /// 선택 항목: 비우면 통과, 쓰면 0보다 큰 숫자 (서버 saveInbody의 requireOptionalPositiveDouble과 같다).
  String? _optionalPositive(String? value, {double? max}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final number = double.tryParse(trimmed);
    if (number == null) return '숫자만 입력해주세요.';
    if (number <= 0) return '0보다 큰 값을 입력해주세요.';
    if (max != null && number > max) {
      return '${max.toStringAsFixed(0)} 이하로 입력해주세요.';
    }
    return null;
  }

  /// 오늘 (날짜만). 측정일은 미래를 고를 수 없다.
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final today = _today;
    final current = DateTime.tryParse(_dateCtrl.text);
    final selected = await showAppDatePicker(
      context: context,
      initialDate: current == null || current.isAfter(today) ? today : current,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      title: '측정일 선택',
    );
    if (selected == null || !mounted) return;
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(selected);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final inbody = Inbody(
        id: const Uuid().v4(),
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        memberName: widget.member.name,
        trainerId: widget.trainer.uid,
        measurementDate: _dateCtrl.text.trim(),
        weight: double.parse(_weightCtrl.text.trim()),
        muscleMass: _doubleOrNull(_muscleCtrl),
        bodyFat: _doubleOrNull(_bodyFatCtrl),
        bodyFatPercent: _doubleOrNull(_bodyFatPercentCtrl),
        bmi: _doubleOrNull(_bmiCtrl),
        bmr: _doubleOrNull(_bmrCtrl),
        visceralFat: _intOrNull(_visceralFatCtrl),
        createdAt: now,
        updatedAt: now,
      );

      await FirestoreService.saveInbody(inbody);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberType = const TextInputType.numberWithOptions(decimal: true);
    final numberFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
    ];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBottomSheetHeader(
            title: 'InBody 입력',
            subtitle: '${widget.member.name} 회원의 측정 기록',
            mutedSubtitle: true,
            gap: AppSpacing.md,
          ),
          const _SheetSection(label: '날짜', first: true),
          AppTextField(
            label: '측정일',
            controller: _dateCtrl,
            readOnly: true,
            onTap: _pickDate,
            suffix: AppIconButton(
              icon: AppIcons.calendar,
              label: '측정일 선택',
              onPressed: _pickDate,
              color: AppColors.body,
            ),
            validator: (v) {
              final date = DateTime.tryParse(v?.trim() ?? '');
              if (date == null) return '측정일을 선택해주세요.';
              if (date.isAfter(_today)) return '오늘 이후 날짜는 고를 수 없습니다.';
              return null;
            },
          ),
          const _SheetSection(label: '체성분'),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: '체중 (kg)',
                  controller: _weightCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: (v) {
                    final value = double.tryParse(v?.trim() ?? '');
                    if (value == null) return '체중을 입력해주세요.';
                    if (value <= 0) return '0보다 큰 값을 입력해주세요.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: '골격근량 (kg)',
                  controller: _muscleCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalPositive,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: '체지방량 (kg)',
                  controller: _bodyFatCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalPositive,
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: '체지방률 (%)',
                  controller: _bodyFatPercentCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: (v) => _optionalPositive(v, max: 100),
                ),
              ),
            ],
          ),
          const _SheetSection(label: '지표'),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'BMI',
                  controller: _bmiCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalPositive,
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: '기초대사량 (kcal)',
                  controller: _bmrCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalPositive,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
          AppTextField(
            label: '내장지방 레벨',
            controller: _visceralFatCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final trimmed = v?.trim() ?? '';
              if (trimmed.isEmpty) return null;
              final level = int.tryParse(trimmed);
              if (level == null) return '숫자만 입력해주세요.';
              // 서버 requireOptionalPositiveInt와 같이 0은 받지 않는다.
              if (level <= 0) return '0보다 큰 값을 입력해주세요.';
              return null;
            },
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '저장',
            onPressed: _save,
            isLoading: _isSaving,
            fullWidth: true,
            size: AppButtonSize.lg,
          ),
        ],
      ),
    );
  }
}

/// 시트 안 묶음 머리말 (시안 Tr-Inbody-Input): 15 mute, 위 18 (첫 묶음은 0) · 아래 8.
/// 시트가 이미 좌우 20을 두므로 머리말 좌우 여백은 0.
class _SheetSection extends StatelessWidget {
  final String label;
  final bool first;

  const _SheetSection({required this.label, this.first = false});

  @override
  Widget build(BuildContext context) {
    return AppMonthHeader(
      label: label,
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: AppSpacing.sm),
    );
  }
}

/// 'yyyy-MM-dd' 측정일을 '10월 7일 (수)'로. 형식이 다르면 원문.
String inbodyDayLabel(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : appDayLabel(parsed);
}

/// InBody 기록 상세 시트 (시안 Tr-Inbody-Detail): 측정일 보조 줄 → 회색 카드(반경 18, 줄 52)
/// → '기록 삭제' 행. 삭제를 고르면 true를 돌려준다 (확인 창은 부른 쪽에서 띄운다).
/// 규칙상 자기가 입력한 기록만 지울 수 있으므로 [canDelete]가 false면 삭제 행을 두지 않는다.
Future<bool?> showTrainerInbodyDetailSheet(
  BuildContext context,
  Inbody item, {
  required bool canDelete,
}) {
  final number = NumberFormat('#,##0.#');
  String fmt(num v) => number.format(v);
  final rows = <(String, String, String)>[
    ('체중', fmt(item.weight), 'kg'),
    if (item.muscleMass != null) ('골격근량', fmt(item.muscleMass!), 'kg'),
    if (item.bodyFat != null) ('체지방량', fmt(item.bodyFat!), 'kg'),
    if (item.bodyFatPercent != null) ('체지방률', fmt(item.bodyFatPercent!), '%'),
    if (item.bmi != null) ('BMI', fmt(item.bmi!), ''),
    if (item.bmr != null) ('기초대사량', fmt(item.bmr!), 'kcal'),
    if (item.visceralFat != null) ('내장지방 레벨', '${item.visceralFat}', ''),
  ];
  return showAppBottomSheet<bool>(
    context: context,
    child: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBottomSheetHeader(
            title: 'InBody 기록',
            subtitle: inbodyDayLabel(item.measurementDate),
            mutedSubtitle: true,
            gap: AppSpacing.md,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.canvasCard,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  AppKeyValueRow(
                    label: rows[i].$1,
                    value: rows[i].$2,
                    unit: rows[i].$3,
                    divider: i < rows.length - 1,
                    dividerColor: AppColors.line,
                  ),
              ],
            ),
          ),
          if (canDelete) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSheetAction(
              icon: AppIcons.trash,
              label: '기록 삭제',
              destructive: true,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ],
      ),
    ),
  );
}
