import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/notice.dart';
import '../../services/firestore_service.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';

/// 공지 작성·수정 (시안 Nt-Admin-Compose): 대상 3칸 + 인원 안내 → 제목·내용(글자 수) → 띠 → 스위치 줄.
/// 저장하면 true를 돌려준다.
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

  /// 센터의 승인된 회원·트레이너 수 (대상 안내용, 못 불러오면 null)
  ({int members, int trainers})? _counts;

  bool get _isEdit => widget.notice != null;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final centerId = context.read<UserProvider>().user?.centerId;
    if (centerId == null) return;
    try {
      final counts = await FirestoreService.countApprovedUsers(centerId);
      if (mounted) setState(() => _counts = counts);
    } catch (_) {
      // 안내 문구만 빠진다 (작성에는 지장 없음)
    }
  }

  /// 지금 고른 대상의 인원 (모르면 null)
  int? get _audienceCount {
    final c = _counts;
    if (c == null) return null;
    return switch (_audience) {
      NoticeAudience.all => c.members + c.trainers,
      NoticeAudience.member => c.members,
      NoticeAudience.trainer => c.trainers,
    };
  }

  /// 시안 '회원 128명 · 트레이너 6명에게 보여요'
  String? get _audienceLine {
    final c = _counts;
    if (c == null) return null;
    return switch (_audience) {
      NoticeAudience.all => '회원 ${c.members}명 · 트레이너 ${c.trainers}명에게 보여요',
      NoticeAudience.member => '회원 ${c.members}명에게 보여요',
      NoticeAudience.trainer => '트레이너 ${c.trainers}명에게 보여요',
    };
  }

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
      final count = _audienceCount;
      // 시안 Nt-Admin-Posted: 두 줄 토스트 (알림을 보냈으면 아래 줄에 인원)
      if (!_isEdit && _notify) {
        AppToast.show(
          context,
          title: '공지를 등록했어요',
          message: count == null ? '대상에게 알림을 보내요' : '$count명에게 알림을 보내요',
        );
      } else {
        AppToast.show(context, message: _isEdit ? '공지를 수정했어요' : '공지를 등록했어요');
      }
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
    final count = _audienceCount;
    final audienceLine = _audienceLine;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 시안 Nt-Admin-Compose: 닫기(X) + 가운데 17/500 제목
            AppScreenHeader.centered(
              title: _isEdit ? '공지 수정' : '공지 작성',
              close: true,
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xl2,
                  ),
                  children: [
                    // ── 대상 (3칸 44 · 반경 14) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('누구에게 보일까요', style: AppTextStyles.fieldLabel),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              for (final a in NoticeAudience.values) ...[
                                if (a.index > 0)
                                  const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppChip(
                                    label: a.label,
                                    cell: true,
                                    selected: _audience == a,
                                    onTap: () => setState(() => _audience = a),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (audienceLine != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(audienceLine, style: AppTextStyles.bodySm),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            label: '제목',
                            hint: '공지 제목을 입력하세요',
                            controller: _title,
                            maxLength: Notice.titleMax,
                            labelCounter: true,
                            validator: _validateTitle,
                          ),
                          const SizedBox(height: AppSpacing.base),
                          AppTextField(
                            label: '내용',
                            hint: '회원과 트레이너에게 전할 내용을 입력하세요',
                            controller: _body,
                            maxLines: 10,
                            fieldHeight: 200,
                            maxLength: Notice.bodyMax,
                            labelCounter: true,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            validator: _validateBody,
                          ),
                        ],
                      ),
                    ),
                    // ── 표시 · 알림 (8 띠 → 68 스위치 줄) ──
                    const AppSectionBand(top: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm,
                        AppSpacing.screenH,
                        0,
                      ),
                      child: Column(
                        children: [
                          AppSwitchRow(
                            label: '상단 고정',
                            description: '목록 맨 위에 계속 보여요',
                            value: _pinned,
                            onChanged: (v) => setState(() => _pinned = v),
                          ),
                          AppSwitchRow(
                            label: '중요 공지로 띄우기',
                            description: '앱을 열면 한 번 크게 보여요',
                            value: _important,
                            onChanged: (v) => setState(() => _important = v),
                          ),
                          if (!_isEdit)
                            AppSwitchRow(
                              label: '푸시 알림 보내기',
                              description: count == null
                                  ? '대상에게 알림이 가고 알림함에도 남아요'
                                  : '$count명에게 알림이 가고 알림함에도 남아요',
                              value: _notify,
                              onChanged: (v) => setState(() => _notify = v),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomActionBar(
              primaryLabel: _isEdit ? '수정 저장' : '등록하기',
              loading: _saving,
              onPrimary: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
