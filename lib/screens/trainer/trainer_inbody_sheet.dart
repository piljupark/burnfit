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
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_text_field.dart';

class TrainerInbodyInputSheet extends StatefulWidget {
  final AppUser member;
  final AppUser trainer;

  const TrainerInbodyInputSheet({super.key, required this.member, required this.trainer});

  @override
  State<TrainerInbodyInputSheet> createState() => _TrainerInbodyInputSheetState();
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

  String? _optionalNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed) == null ? '숫자만 입력해주세요.' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateCtrl.text) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null) return;
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
    final numberFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBottomSheetHeader(title: 'InBody 입력', subtitle: '${widget.member.name} 회원의 측정 기록'),
          const _SheetSection(label: 'DATE', first: true),
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
            validator: (v) => DateTime.tryParse(v?.trim() ?? '') == null ? '측정일을 선택해주세요.' : null,
          ),
          const _SheetSection(label: 'BODY COMPOSITION'),
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
              const SizedBox(width: AppSpacing.md, height: AppSpacing.base),
              Expanded(
                child: AppTextField(
                  label: '골격근량 (kg)',
                  controller: _muscleCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalNumber,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md, height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: '체지방량 (kg)',
                  controller: _bodyFatCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalNumber,
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.base),
              Expanded(
                child: AppTextField(
                  label: '체지방률 (%)',
                  controller: _bodyFatPercentCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalNumber,
                ),
              ),
            ],
          ),
          const _SheetSection(label: 'INDEX'),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'BMI',
                  controller: _bmiCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalNumber,
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.base),
              Expanded(
                child: AppTextField(
                  label: 'BMR',
                  controller: _bmrCtrl,
                  keyboardType: numberType,
                  inputFormatters: numberFormatters,
                  validator: _optionalNumber,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md, height: AppSpacing.base),
          AppTextField(
            label: '내장지방 레벨',
            controller: _visceralFatCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final trimmed = v?.trim() ?? '';
              if (trimmed.isEmpty) return null;
              return int.tryParse(trimmed) == null ? '숫자만 입력해주세요.' : null;
            },
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: '저장', onPressed: _save, isLoading: _isSaving, fullWidth: true, size: AppButtonSize.lg),
        ],
      ),
    );
  }
}

/// 시트 안 묶음 머리말: 모노 라벨 + 남은 폭 hairline.
class _SheetSection extends StatelessWidget {
  final String label;
  final bool first;

  const _SheetSection({required this.label, this.first = false});

  @override
  Widget build(BuildContext context) {
    return AppMonthHeader(
      label: label,
      padding: EdgeInsets.only(top: first ? 0 : AppSpacing.xl, bottom: AppSpacing.md),
    );
  }
}
