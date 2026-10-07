import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/validators.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class EditProfileSheet extends StatefulWidget {
  final AppUser user;

  const EditProfileSheet({super.key, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _muscleCtrl;
  late final TextEditingController _bodyFatCtrl;
  late final TextEditingController _goalCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.user.profile;
    _heightCtrl = TextEditingController(text: p?.height?.toString() ?? '');
    _weightCtrl = TextEditingController(text: p?.weight?.toString() ?? '');
    _muscleCtrl = TextEditingController(text: p?.muscleMass?.toString() ?? '');
    _bodyFatCtrl = TextEditingController(text: p?.bodyFat?.toString() ?? '');
    _goalCtrl = TextEditingController(text: p?.goal ?? '');
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _muscleCtrl.dispose();
    _bodyFatCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final m = Validators.bodyMetrics(
        height: _heightCtrl.text,
        weight: _weightCtrl.text,
        muscleMass: _muscleCtrl.text,
        bodyFat: _bodyFatCtrl.text,
      );
      final profile = UserProfile(
        height: m.height,
        weight: m.weight,
        muscleMass: m.muscleMass,
        bodyFat: m.bodyFat,
        goal: _goalCtrl.text.trim().isEmpty ? null : _goalCtrl.text.trim(),
      );
      await FirestoreService.updateUser(widget.user.uid, {
        'profile': profile.toMap(),
      });
      if (!mounted) return;
      context.read<UserProvider>().updateUserLocally(
        widget.user.copyWith(profile: profile),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _numberField(
    String label,
    String unit,
    TextEditingController controller,
  ) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      textInputAction: TextInputAction.next,
      suffix: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.base),
        child: Center(
          widthFactor: 1,
          child: Text(unit, style: AppTextStyles.counter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(
          title: '신체 정보 수정',
          subtitle: '트레이너와 공유되는 핵심 정보입니다.',
        ),
        Row(
          children: [
            Expanded(child: _numberField('키', 'cm', _heightCtrl)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _numberField('체중', 'kg', _weightCtrl)),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            Expanded(child: _numberField('골격근량', 'kg', _muscleCtrl)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _numberField('체지방량', 'kg', _bodyFatCtrl)),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          label: '목표',
          hint: '예: 체지방 감량, 근육량 증가',
          controller: _goalCtrl,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: '저장',
          onPressed: _save,
          isLoading: _isSaving,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }
}
