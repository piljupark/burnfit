import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/notice.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';

/// 공지 작성·수정. 저장하면 true를 돌려준다.
class AdminNoticeEditScreen extends StatefulWidget {
  final Notice? notice;
  const AdminNoticeEditScreen({super.key, this.notice});

  @override
  State<AdminNoticeEditScreen> createState() => _AdminNoticeEditScreenState();
}

class _AdminNoticeEditScreenState extends State<AdminNoticeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.notice?.title ?? '');
  late final _body = TextEditingController(text: widget.notice?.body ?? '');
  late NoticeAudience _audience = widget.notice?.audience ?? NoticeAudience.all;
  late bool _pinned = widget.notice?.pinned ?? false;
  late bool _important = widget.notice?.important ?? false;
  bool _notify = false;
  bool _saving = false;

  bool get _isEdit => widget.notice != null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await NoticeService.update(
          widget.notice!.id,
          title: _title.text,
          body: _body.text,
          audience: _audience,
          pinned: _pinned,
          important: _important,
        );
      } else {
        await NoticeService.create(
          centerId: user.centerId,
          authorId: user.uid,
          title: _title.text,
          body: _body.text,
          audience: _audience,
          pinned: _pinned,
          important: _important,
          notify: _notify,
        );
      }
      if (!mounted) return;
      AppToast.show(context, message: _isEdit ? '공지를 수정했어요' : '공지를 등록했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  static String? _validateTitle(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '제목을 입력해 주세요';
    if (t.length > Notice.titleMax) {
      return '제목은 ${Notice.titleMax}자 이내로 입력해 주세요';
    }
    return null;
  }

  static String? _validateBody(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '내용을 입력해 주세요';
    if (t.length > Notice.bodyMax) return '내용은 ${Notice.bodyMax}자 이내로 입력해 주세요';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: _isEdit ? '공지 수정' : '공지 작성',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.lg,
                    AppSpacing.screenH,
                    AppSpacing.xl2,
                  ),
                  children: [
                    Text('누구에게 보일까요', style: AppTextStyles.bodySm),
                    const SizedBox(height: AppSpacing.sm),
                    AppFilterTabs(
                      tabs: [for (final a in NoticeAudience.values) a.label],
                      selectedIndex: _audience.index,
                      onChanged: (i) =>
                          setState(() => _audience = NoticeAudience.values[i]),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: '제목',
                      hint: '공지 제목을 입력하세요',
                      controller: _title,
                      maxLength: Notice.titleMax,
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: '내용',
                      hint: '회원과 트레이너에게 전할 내용을 입력하세요',
                      controller: _body,
                      maxLines: 10,
                      maxLength: Notice.bodyMax,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      validator: _validateBody,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SwitchRow(
                      label: '상단 고정',
                      description: '목록 맨 위에 계속 보여요',
                      value: _pinned,
                      onChanged: (v) => setState(() => _pinned = v),
                    ),
                    _SwitchRow(
                      label: '중요 공지로 띄우기',
                      description: '앱을 열면 한 번 크게 보여요',
                      value: _important,
                      onChanged: (v) => setState(() => _important = v),
                    ),
                    if (!_isEdit)
                      _SwitchRow(
                        label: '푸시 알림 보내기',
                        description: '대상에게 알림이 가고 알림함에도 남아요',
                        value: _notify,
                        onChanged: (v) => setState(() => _notify = v),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: AppButton(
                label: _isEdit ? '수정 저장' : '등록하기',
                fullWidth: true,
                size: AppButtonSize.lg,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMd),
                Text(description, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
