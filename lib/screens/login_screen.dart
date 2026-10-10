import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/app_routing.dart';
import '../core/validators.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/saved_account_store.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_icon_box.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_parts.dart';
import '../widgets/password_reset_sheet.dart';
import 'register_flow_screen.dart';

/// 로그인: 이메일·비밀번호만 받는다. 센터와 역할은 계정(사용자 문서)에 있으므로
/// 로그인한 뒤 [startRouteFor]가 들어갈 화면을 정한다.
///
/// 이 기기에서 로그인한 적이 있으면 '다시 오셨네요' + 계정 카드 + 비밀번호만 보여 준다
/// ([SavedAccountStore]). '바꾸기'를 누르면 이메일 입력으로 펼친다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// 저장된 계정을 읽기 전에는 아무것도 그리지 않는다 (두 화면이 번갈아 보이지 않게).
  bool _ready = false;
  SavedAccount? _saved;

  /// 저장된 계정 카드로 로그인하는 중인지. false면 이메일을 입력받는다.
  bool _useSaved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedAccountStore.load();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _useSaved = saved != null;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _useSaved ? _saved!.email : _emailController.text.trim();

  Future<void> _login() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final firstTimeHere = !_useSaved;
    setState(() => _isLoading = true);
    final password = _passwordController.text;
    try {
      final cred = await AuthService.signIn(email: _email, password: password);

      final user = await FirestoreService.getUser(cred.user!.uid);
      if (!mounted) return;

      if (user == null) {
        AppFeedback.showWarning(context, '계정 정보를 찾을 수 없습니다.');
        await AuthService.signOut();
        return;
      }

      final route = startRouteFor(user);
      if (route == null) {
        await _offerRejectedAccountCleanup(user.uid, password);
        return;
      }

      await SavedAccountStore.save(user);
      if (!mounted) return;
      // 알림 토큰 저장·계정 상태 구독도 함께 시작된다.
      context.read<UserProvider>().setUser(user);
      Navigator.of(context).pushReplacementNamed(route);
      // 처음 이메일로 들어왔으면 어느 센터의 어떤 계정으로 들어갔는지 알려 준다.
      if (firstTimeHere) {
        AppToast.show(
          null,
          message: '${user.centerName} ${user.role.label} 계정으로 들어왔어요.',
          kind: AppToastKind.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // 잘못된 비밀번호·네트워크 오류 등을 구분해 안내한다.
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 거절된 계정: 그냥 로그아웃시키면 같은 이메일로 다시 가입할 수 없으므로
  /// 계정 삭제(기존 탈퇴 서버 함수)를 안내한다. 삭제하지 않으면 로그아웃만 한다.
  Future<void> _offerRejectedAccountCleanup(String uid, String password) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '가입이 거절되었습니다',
      message:
          '센터에서 가입 신청을 거절했어요. 계정을 삭제하면 같은 이메일로 다시 가입 신청할 수 있어요. '
          '거절 사유는 센터에 문의해주세요.',
      confirmLabel: '계정 삭제',
      cancelLabel: '닫기',
    );
    if (!confirmed || !mounted) {
      await AuthService.signOut();
      return;
    }
    try {
      await AccountService.deleteMyAccount(uid: uid, password: password);
      await SavedAccountStore.clear();
      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _saved = null;
        _useSaved = false;
      });
      AppFeedback.showSuccessSnackBar(context, '계정을 삭제했어요. 다시 가입 신청할 수 있어요.');
    } catch (e) {
      await AuthService.signOut();
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  void _useOtherAccount() {
    _emailController.clear();
    _passwordController.clear();
    setState(() => _useSaved = false);
  }

  void _backToSaved() {
    _passwordController.clear();
    setState(() => _useSaved = true);
  }

  void _goRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterFlowScreen()));
  }

  /// 시안 `up`: 아래 12에서 올라오며 나타남 (.5s ease-out, 순번 × 0.05초 늦게)
  Widget _up(int index, Widget child) => AppEntrance(
    offset: const Offset(0, 12),
    delay: Duration(milliseconds: 50 * index),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (!_ready) return Scaffold(backgroundColor: AppColors.canvas);
    final saved = _saved;
    final useSaved = _useSaved && saved != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 위: 가운데 제목 → 계정 카드 또는 이메일 → 비밀번호
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                ),
                child: Form(
                  key: _formKey,
                  // 카드 화면과 이메일 화면을 바꾸면 칸을 새로 만들어 지난 오류 문구가 남지 않게 한다.
                  child: _LoginFields(
                    key: ValueKey(useSaved),
                    up: _up,
                    saved: useSaved ? saved : null,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onChangeAccount: _useOtherAccount,
                    onSubmit: _login,
                    onForgot: () => showPasswordResetSheet(
                      context,
                      initialEmail: useSaved
                          ? saved.email
                          : _emailController.text,
                    ),
                    onBackToSaved: !useSaved && saved != null
                        ? _backToSaved
                        : null,
                  ),
                ),
              ),
            ),
            // 아래 고정: 로그인 → 가입·다른 계정 링크 (키보드 위로 따라 올라온다)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(AppSpacing.md),
                  _up(
                    4,
                    AppButton(
                      label: '로그인',
                      onPressed: _login,
                      isLoading: _isLoading,
                      fullWidth: true,
                      size: AppButtonSize.lg,
                    ),
                  ),
                  _up(
                    5,
                    useSaved
                        ? AuthTextLink(
                            lead: '다른 계정으로',
                            action: '로그인',
                            onTap: _useOtherAccount,
                          )
                        : AuthTextLink(
                            lead: '처음이에요',
                            action: '가입하기',
                            onTap: _goRegister,
                          ),
                  ),
                  Gap(math.max(bottomInset - AppSpacing.md, AppSpacing.sm)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 폼 위쪽 묶음. 계정 카드 화면과 이메일 화면을 [key]로 나눠 그때마다 새로 들어오게 한다.
class _LoginFields extends StatelessWidget {
  final Widget Function(int index, Widget child) up;
  final SavedAccount? saved;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onChangeAccount;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback? onBackToSaved;

  const _LoginFields({
    super.key,
    required this.up,
    required this.saved,
    required this.emailController,
    required this.passwordController,
    required this.onChangeAccount,
    required this.onSubmit,
    required this.onForgot,
    required this.onBackToSaved,
  });

  @override
  Widget build(BuildContext context) {
    final saved = this.saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(40),
        up(
          0,
          AuthHeading(
            title: saved != null ? '다시 오셨네요' : '로그인',
            subtitle: saved != null
                ? '지난번 계정으로 들어가요.'
                : '센터와 역할은 계정에서 알아서 찾아요.',
          ),
        ),
        const Gap(AppSpacing.xl),
        if (saved != null)
          up(1, _SavedAccountCard(account: saved, onChange: onChangeAccount))
        else
          up(
            1,
            AppTextField(
              label: '이메일',
              hint: 'name@example.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              textInputAction: TextInputAction.next,
            ),
          ),
        const Gap(AppSpacing.base),
        up(
          2,
          AppTextField(
            label: '비밀번호',
            hint: '비밀번호',
            controller: passwordController,
            obscureText: true,
            // 로그인은 틀린 비밀번호를 확인하는 일이 잦아 보기 단추를 켠다 (2026-10-10 결정)
            showVisibilityToggle: true,
            validator: Validators.existingPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        up(3, ForgotPasswordLink(onPressed: onForgot)),
        if (onBackToSaved != null)
          up(
            3,
            Center(
              child: AppButton(
                label: '지난번 계정으로 돌아가기',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.md,
                onPressed: onBackToSaved,
              ),
            ),
          ),
        const Gap(AppSpacing.base),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 계정 카드: 회색 면(반경 20) · 아이콘 상자(흰 면) · 센터 이름 16/500 · '역할 · 이메일' 13 body ·
// 오른쪽 흰 알약 '바꾸기'(32, 터치 44)
// ─────────────────────────────────────────────────────────────────────────────

class _SavedAccountCard extends StatelessWidget {
  final SavedAccount account;
  final VoidCallback onChange;

  const _SavedAccountCard({required this.account, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          AppIconBox(icon: AppIcons.profile, background: AppColors.canvas),
          const Gap(AppSpacing.md),
          Expanded(
            child: Semantics(
              label:
                  '지난번 계정, ${account.centerName} ${account.role.label}, ${account.email}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.centerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.listTitle,
                  ),
                  const Gap(2),
                  Text(
                    '${account.role.label} · ${account.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                  ),
                ],
              ),
            ),
          ),
          const Gap(AppSpacing.sm),
          Semantics(
            button: true,
            label: '다른 계정으로 바꾸기',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onChange,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: AppSize.touchMin,
                child: Center(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('바꾸기', style: AppTextStyles.buttonLabel.medium),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
