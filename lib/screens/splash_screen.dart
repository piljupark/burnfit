import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_logger.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/app_routing.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loader.dart';
import '../widgets/brand_marks.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// 사용자 정보를 읽다가 네트워크 등으로 실패함 → 다시 시도·로그아웃을 보여준다.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.debug('[Splash] 시작');

    final current = AuthService.currentUser;
    AppLogger.debug(
      '[Splash] Firebase Auth 확인: ${stopwatch.elapsedMilliseconds}ms',
    );

    if (current == null) {
      AppLogger.debug(
        '[Splash] 비로그인 → 로그인 화면: ${stopwatch.elapsedMilliseconds}ms',
      );
      if (!mounted) return;
      _goLogin();
      return;
    }

    AppLogger.debug('[Splash] 인증 사용자 Firestore 조회 시작');
    final provider = context.read<UserProvider>();
    await provider.loadUser();
    AppLogger.debug(
      '[Splash] Firestore 조회 완료: ${stopwatch.elapsedMilliseconds}ms',
    );

    if (!mounted) return;

    final user = provider.user;
    if (user == null) {
      if (provider.loadFailed) {
        // 계정이 없는 게 아니라 읽지 못한 것이므로 로그인 화면으로 보내지 않는다.
        AppLogger.debug('[Splash] 사용자 정보 읽기 실패 → 다시 시도 안내');
        setState(() => _failed = true);
        return;
      }
      AppLogger.debug('[Splash] 유저 문서 없음 → 로그아웃 후 로그인 화면');
      await provider.signOut();
      if (!mounted) return;
      _goLogin();
      return;
    }

    AppLogger.debug('[Splash] 사용자 상태 확인 완료');

    final route = startRouteFor(user);
    AppLogger.debug(
      '[Splash] 총 소요: ${stopwatch.elapsedMilliseconds}ms → ${route ?? '로그인(거절됨)'}',
    );
    stopwatch.stop();
    if (route == null) {
      await provider.signOut();
      if (!mounted) return;
      _goLogin();
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _goLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.memberLogin);
  }

  void _retry() {
    setState(() => _failed = false);
    _init();
  }

  Future<void> _signOut() async {
    await context.read<UserProvider>().signOut();
    if (!mounted) return;
    _goLogin();
  }

  @override
  Widget build(BuildContext context) {
    // 시안 Com-Splash: 브랜드 묶음은 위에서 300(844 화면) — 가운데보다 조금 위, 아래쪽 로딩 점(64).
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Align(
            // 묶음 중심이 화면 높이의 약 48.5% (시안 top 300 + 묶음 높이 218 / 844)
            alignment: const Alignment(0, -0.03),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(child: SplashFlameMark()),
                const SizedBox(height: AppSpacing.xl2),
                Text(
                  'BurnFit',
                  style: AppTextStyles.displayMd.copyWith(
                    fontSize: 32,
                    height: 38 / 32,
                    letterSpacing: 32 * -0.019,
                  ),
                ),
                const SizedBox(height: 6),
                Text('피트니스 센터', style: AppTextStyles.eyebrow),
              ],
            ),
          ),
          if (_failed)
            Positioned(
              left: AppSpacing.screenH,
              right: AppSpacing.screenH,
              bottom: AppSpacing.xl2 + MediaQuery.paddingOf(context).bottom,
              child: _LoadFailedActions(onRetry: _retry, onSignOut: _signOut),
            )
          else
            const Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xl4,
              child: Center(child: AppLoader.screen()),
            ),
        ],
      ),
    );
  }
}

/// 사용자 정보 읽기 실패 시 안내 + 다시 시도(주 행동) + 로그아웃.
class _LoadFailedActions extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _LoadFailedActions({required this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '계정 정보를 불러오지 못했어요.\n네트워크 연결을 확인해주세요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '다시 시도',
          icon: const Icon(AppIcons.refresh),
          onPressed: onRetry,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: '로그아웃',
          variant: AppButtonVariant.secondary,
          onPressed: onSignOut,
          fullWidth: true,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }
}
