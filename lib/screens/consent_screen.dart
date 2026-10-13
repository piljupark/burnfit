import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_routing.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/user.dart';
import '../services/contact_service.dart';
import '../services/firestore_service.dart';
import '../services/user_provider.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_text_field.dart';
import '../widgets/consent_checklist.dart';

/// 동의 화면: 지금 판의 동의가 없는 계정이 로그인하면 먼저 온다 ([startRouteFor]).
///
/// 2026-10-13 전 가입자 · 서버가 만든 관리자 계정 · 동의서 판이 바뀐 경우.
/// 회원 · 트레이너는 휴대폰 번호가 없으면 여기서 함께 받는다. 동의하면 원래 가려던 첫 화면으로.
/// 동의하지 않으면 '로그아웃'만 할 수 있다.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _privacy = false;
  bool _health = false;
  bool _saving = false;

  /// 휴대폰 번호를 받아야 하는지 (회원 · 트레이너인데 저장된 번호가 없음). 읽는 동안 null.
  bool? _needsPhone;

  AppUser? get _user => context.read<UserProvider>().user;

  @override
  void initState() {
    super.initState();
    _checkPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkPhone() async {
    final user = _user;
    if (user == null || user.isAdmin) {
      setState(() => _needsPhone = false);
      return;
    }
    try {
      final phone = await ContactService.getPhone(user.uid);
      if (mounted) setState(() => _needsPhone = phone == null);
    } catch (_) {
      // 읽지 못하면 받는다 (덮어써도 같은 번호면 문제없다).
      if (mounted) setState(() => _needsPhone = true);
    }
  }

  bool get _agreed {
    final user = _user;
    return _privacy && (user == null || !user.isMember || _health);
  }

  Future<void> _submit() async {
    final user = _user;
    if (user == null || _saving || !_agreed) return;
    if (_needsPhone == true && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch()
        ..update(db.collection('users').doc(user.uid), {
          'consents': ConsentRecord.nowFor(health: user.isMember),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (_needsPhone == true) {
        batch.set(
          ContactService.ref(user.uid),
          ContactService.dataFor(_phoneController.text),
        );
      }
      await batch.commit();
      final fresh = await FirestoreService.getUser(user.uid);
      if (!mounted) return;
      if (fresh != null) context.read<UserProvider>().setUser(fresh);
      final route = fresh == null ? null : startRouteFor(fresh);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(route ?? AppRoutes.memberLogin, (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _signOut() async {
    await context.read<UserProvider>().signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.memberLogin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null || _needsPhone == null) {
      return const Scaffold(body: AppLoadingView());
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl2,
                    AppSpacing.screenH,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text('개인정보 동의가 필요해요', style: AppTextStyles.displayMd),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      user.isMember
                          ? '계속 쓰려면 개인정보와 건강 정보 수집 · 이용에 동의해 주세요.'
                          : '계속 쓰려면 개인정보 수집 · 이용에 동의해 주세요.',
                      style: AppTextStyles.note,
                    ),
                    if (_needsPhone == true) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        label: '휴대폰 번호',
                        hint: '010-1234-5678',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                          LengthLimitingTextInputFormatter(13),
                        ],
                        validator: Validators.phone,
                        helper: '센터 명단과 맞춰 보는 데만 써요. 트레이너에게는 보이지 않아요.',
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    ConsentChecklist(
                      privacy: _privacy,
                      onPrivacy: (v) => setState(() => _privacy = v),
                      health: user.isMember ? _health : null,
                      onHealth: (v) => setState(() => _health = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _signOut,
                        child: Text(
                          '동의하지 않고 로그아웃',
                          style: AppTextStyles.bodySm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomActionBar(
              primaryLabel: '동의하고 계속',
              loading: _saving,
              onPrimary: _agreed && !_saving ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
