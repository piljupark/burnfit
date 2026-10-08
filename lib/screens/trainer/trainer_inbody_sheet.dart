import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/inbody.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
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

  String? _optionalNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed) == null ? '숫자만 입력해주세요.' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showAppDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateCtrl.text) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      title: '측정일 선택',
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
            validator: (v) => DateTime.tryParse(v?.trim() ?? '') == null
                ? '측정일을 선택해주세요.'
                : null,
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
                  validator: _optionalNumber,
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
                  validator: _optionalNumber,
                ),
              ),
              const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
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
          const _SheetSection(label: '지표'),
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
              const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
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
          const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
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
class _SheetSection extends StatelessWidget {
  final String label;
  final bool first;

  const _SheetSection({required this.label, this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(label, style: AppTextStyles.eyebrow.natural),
      ),
    );
  }
}

/// InBody 기록 상세 시트 (시안 Tr-Inbody-Detail): 측정일 보조 줄 → 회색 카드(반경 18, 줄 52)
/// → '기록 삭제' 행. 삭제를 고르면 true를 돌려준다 (확인 창은 부른 쪽에서 띄운다).
Future<bool?> showTrainerInbodyDetailSheet(BuildContext context, Inbody item) {
  final number = NumberFormat('#,##0.#');
  String fmt(num v) => number.format(v);
  final rows = <(String, String, String)>[
    ('체중', fmt(item.weight), 'kg'),
    if (item.muscleMass != null) ('골격근량', fmt(item.muscleMass!), 'kg'),
    if (item.bodyFat != null) ('체지방량', fmt(item.bodyFat!), 'kg'),
    if (item.bodyFatPercent != null) ('체지방률', fmt(item.bodyFatPercent!), '%'),
    if (item.bmi != null) ('BMI', fmt(item.bmi!), ''),
    if (item.bmr != null) ('BMR', fmt(item.bmr!), 'kcal'),
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
            subtitle: item.measurementDate,
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
                  _DetailRow(
                    label: rows[i].$1,
                    value: rows[i].$2,
                    unit: rows[i].$3,
                    divider: i < rows.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSheetAction(
            icon: AppIcons.trash,
            label: '기록 삭제',
            destructive: true,
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    ),
  );
}

/// 상세 카드 한 줄: 52 높이, 라벨 15 body · 값 16/500 + 단위 400 mute, 아래 line 구분선.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool divider;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.mute,
                    ),
                  ),
              ],
            ),
            style: AppTextStyles.input.medium,
          ),
        ],
      ),
    );
  }
}
