import 'dart:async';

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
import '../models/center.dart' as center_model;
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart';
import '../services/user_provider.dart';
import '../widgets/app_action_row.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/orb_loader.dart';
import '../widgets/password_reset_sheet.dart';
import 'member/member_register_screen.dart';
import 'trainer/trainer_register_screen.dart';
import 'admin/admin_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _roleIndex = 0; // 0=회원 1=트레이너 2=관리자
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _centerSearchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  center_model.Center? _selectedCenter;
  bool _isLoading = false;

  static const _roles = [
    (label: '회원', role: 'member'),
    (label: '트레이너', role: 'trainer'),
    (label: '관리자', role: 'admin'),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _centerSearchController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCenter == null) {
      _showError('센터를 선택해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = await FirestoreService.getUser(cred.user!.uid);
      if (!mounted) return;

      if (user == null) {
        _showError('계정 정보를 찾을 수 없습니다.');
        await AuthService.signOut();
        return;
      }

      if (user.centerId != _selectedCenter!.id) {
        _showError('선택한 센터와 계정 정보가 일치하지 않습니다.');
        await AuthService.signOut();
        return;
      }

      if (user.role.name != _roles[_roleIndex].role) {
        _showError('올바른 로그인 경로를 선택해주세요.');
        await AuthService.signOut();
        return;
      }

      final route = startRouteFor(user);
      if (route == null) {
        _showError('가입이 거절된 계정입니다.');
        await AuthService.signOut();
        return;
      }

      context.read<UserProvider>().setUser(user);
      // 로그아웃 때 지운 알림 토큰을 다시 저장한다 (승인된 사용자만).
      if (user.isApproved) unawaited(FcmService.saveToken(user.uid));
      Navigator.of(context).pushReplacementNamed(route);
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

  void _showError(String msg) => AppFeedback.showWarning(context, msg);

  void _goRegister() {
    final screen = switch (_roleIndex) {
      0 => const MemberRegisterScreen(),
      1 => const TrainerRegisterScreen(),
      _ => const AdminRegisterScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openCenterPicker() async {
    _centerSearchController.clear();
    final selected = await showAppBottomSheet<center_model.Center>(
      context: context,
      child: _CenterPickerSheet(controller: _centerSearchController),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCenter = selected);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.only(
            top: media.padding.top + AppSpacing.xl2,
            bottom: media.padding.bottom + AppSpacing.xl2,
          ),
          child: ConstrainedBox(
            // 폼이 화면보다 작으면 세로 가운데, 키보드가 올라오면 스크롤
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight -
                  media.padding.vertical -
                  AppSpacing.xl2 * 2,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 보이는 제목은 없지만 스크린리더에는 화면 이름을 알린다
                  Semantics(
                    header: true,
                    label: 'BurnFit 로그인',
                    child: const SizedBox.shrink(),
                  ),
                  // 화면 가운데: 역할 → 센터·이메일·비밀번호 → 로그인 → 가입
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoleSelector(
                          labels: [for (final r in _roles) r.label],
                          selectedIndex: _roleIndex,
                          onSelect: (i) => setState(() => _roleIndex = i),
                        ),
                        const Gap(AppSpacing.lg),
                        _CenterSelector(
                          centerName: _selectedCenter?.name,
                          onTap: _openCenterPicker,
                        ),
                        const Gap(AppSpacing.base),
                        AppTextField(
                          label: '이메일',
                          hint: 'name@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          textInputAction: TextInputAction.next,
                        ),
                        const Gap(AppSpacing.base),
                        AppTextField(
                          label: '비밀번호',
                          hint: '비밀번호',
                          controller: _passwordController,
                          obscureText: true,
                          validator: Validators.password,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            label: '비밀번호를 잊으셨나요?',
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            onPressed: () => showPasswordResetSheet(
                              context,
                              initialEmail: _emailController.text,
                            ),
                          ),
                        ),
                        const Gap(AppSpacing.xs),
                        AppButton(
                          label: '로그인',
                          onPressed: _login,
                          isLoading: _isLoading,
                          fullWidth: true,
                          size: AppButtonSize.lg,
                        ),
                        const Gap(AppSpacing.sm),
                        AppButton(
                          label: '처음이에요 · 가입하기',
                          variant: AppButtonVariant.ghost,
                          onPressed: _goRegister,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 역할 선택: 같은 폭 pill 3개 (선택 = 흰 채움)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _RoleSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '로그인 역할',
      container: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const Gap(AppSpacing.sm),
            Expanded(
              child: _RolePill(
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RolePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSize.touchMin,
          child: Center(
            child: Container(
              height: AppSize.buttonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.outline,
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.buttonLabel.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 센터 선택 (입력창 모양, 누르면 검색 시트)
// ─────────────────────────────────────────────────────────────────────────────

class _CenterSelector extends StatelessWidget {
  final String? centerName;
  final VoidCallback onTap;

  const _CenterSelector({required this.centerName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            '센터',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
          ),
        ),
        const Gap(AppSpacing.sm),
        Semantics(
          button: true,
          label: centerName == null ? '센터 선택' : '센터, $centerName. 바꾸기',
          excludeSemantics: true,
          child: Material(
            color: AppColors.canvasSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: AppColors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              highlightColor: AppColors.canvasMid,
              splashFactory: NoSplash.splashFactory,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const Gap(AppSpacing.base),
                    Expanded(
                      child: Text(
                        centerName ?? '센터를 선택해주세요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: centerName == null
                              ? AppColors.mute
                              : AppColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: AppSize.touchMin,
                      child: Icon(
                        AppIcons.search,
                        size: AppSize.icon,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 센터 선택 바텀시트
// ─────────────────────────────────────────────────────────────────────────────

class _CenterPickerSheet extends StatefulWidget {
  final TextEditingController controller;

  const _CenterPickerSheet({required this.controller});

  @override
  State<_CenterPickerSheet> createState() => _CenterPickerSheetState();
}

class _CenterPickerSheetState extends State<_CenterPickerSheet> {
  List<center_model.Center> _centers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final centers = await FirestoreService.searchCenters(query.trim());
      if (!mounted) return;
      setState(() => _centers = centers);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(title: '센터 선택'),
        AppTextField(
          label: '센터 검색',
          hint: '센터 이름을 입력해주세요',
          controller: widget.controller,
          onChanged: _search,
          textInputAction: TextInputAction.search,
          prefix: const Icon(AppIcons.search),
        ),
        const Gap(AppSpacing.md),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl2),
            child: Center(child: OrbLoader.screen()),
          )
        else if (_centers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
            child: Text(
              '검색된 센터가 없습니다.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
          )
        else
          for (var i = 0; i < _centers.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _CenterRow(
              center: _centers[i],
              onTap: () => Navigator.of(context).pop(_centers[i]),
            ),
          ],
      ],
    );
  }
}

class _CenterRow extends StatelessWidget {
  final center_model.Center center;
  final VoidCallback onTap;

  const _CenterRow({required this.center, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final address = center.address ?? '';
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(center.name, style: AppTextStyles.bodyLg),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.forward,
                  size: AppSize.icon,
                  color: AppColors.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
