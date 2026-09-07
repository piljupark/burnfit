import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_provider.dart';

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

    if (user.status == UserStatus.pending) {
      AppLogger.debug('[Splash] 승인 대기: ${stopwatch.elapsedMilliseconds}ms');
      Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
      return;
    }

    if (user.status == UserStatus.rejected) {
      await provider.signOut();
      if (!mounted) return;
      _goLogin();
      return;
    }

    AppLogger.debug('[Splash] 총 소요: ${stopwatch.elapsedMilliseconds}ms → 홈 이동');
    stopwatch.stop();

    switch (user.role) {
      case UserRole.admin:
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
      case UserRole.trainer:
        Navigator.of(context).pushReplacementNamed(AppRoutes.trainerHome);
      case UserRole.member:
        if (user.birthDate == null) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingBasic);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.memberHome);
        }
    }
  }

  void _goLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.memberLogin);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
