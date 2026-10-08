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
import '../../widgets/gender_selector.dart';

/// 기본 정보(생년월일·성별) 편집. 센터·담당 트레이너는 관리자만 바꾼다.
/// 저장 형식과 검사는 온보딩과 같다 (yyyyMMdd, [Validators.birthDate]).
class EditBasicInfoSheet extends StatefulWidget {
  final AppUser user;

  const EditBasicInfoSheet({super.key, required this.user});

  @override
  State<EditBasicInfoSheet> createState() => _EditBasicInfoSheetState();
}

class _EditBasicInfoSheetState extends State<EditBasicInfoSheet> {
  late final TextEditingController _birthCtrl = TextEditingController(
    text: widget.user.birthDate?.trim() ?? '',
  );
  late Gender? _gender = widget.user.gender;
  bool _isSaving = false;

  @override
  void dispose() {
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final birth = _birthCtrl.text.trim();
    final birthError = Validators.birthDate(birth);
    if (birthError != null) {
      AppFeedback.showWarning(context, birthError);
      return;
    }
    final gender = _gender;
    if (gender == null) {
      AppFeedback.showWarning(context, '성별을 선택해주세요.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirestoreService.updateUser(widget.user.uid, {
        'birthDate': birth,
        'gender': gender.name,
      });
      if (!mounted) return;
      context.read<UserProvider>().updateUserLocally(
        widget.user.copyWith(birthDate: birth, gender: gender),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(title: '기본 정보 수정'),
        AppTextField(
          label: '생년월일 (8자리)',
          hint: '19900101',
          controller: _birthCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
        ),
        // 시안 MemB-EditBasicSheet: 성별 라벨 위 20 · 14 mute · 아래 6
        const SizedBox(height: AppSpacing.lg),
        Text('성별', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 6),
        GenderSelector(
          value: _gender,
          onChanged: (g) => setState(() => _gender = g),
        ),
        const SizedBox(height: 28),
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
