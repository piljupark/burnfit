import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_logger.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/app_routing.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/user_provider.dart';
import '../widgets/app_loader.dart';
import '../widgets/brand_marks.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
      AppLogger.debug('[Splash] 유저 문서 없음 → 로그인 화면');
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

  @override
  Widget build(BuildContext context) {
    // 시안 Com-Splash: 가운데 브랜드 표시 + 이름, 아래쪽 로딩 점.
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Center(
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
                Text(
                  '피트니스 센터',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
                ),
              ],
            ),
          ),
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
