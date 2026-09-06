import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
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
      final profile = UserProfile(
        height: double.tryParse(_heightCtrl.text.trim()),
        weight: double.tryParse(_weightCtrl.text.trim()),
        muscleMass: double.tryParse(_muscleCtrl.text.trim()),
        bodyFat: double.tryParse(_bodyFatCtrl.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppBottomSheetHeader(
          title: '신체 정보 수정',
          subtitle: '트레이너와 공유되는 핵심 정보입니다.',
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: '키 (cm)',
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체중 (kg)',
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: '골격근량 (kg)',
                controller: _muscleCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: '체지방량 (kg)',
                controller: _bodyFatCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        AppTextField(
          label: '목표',
          hint: '예: 체지방 감량, 근육량 증가',
          controller: _goalCtrl,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const Gap(AppSpacing.lg),
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
