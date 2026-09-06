import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_logger.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/member/member_home_screen.dart';
import 'screens/member/onboarding_screens.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/trainer/trainer_home_screen.dart';
import 'services/user_provider.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stopwatch = Stopwatch()..start();
  AppLogger.debug('[Main] Firebase 초기화 시작');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.debug('[Main] Firebase 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await initializeDateFormatting('ko_KR', null);
  AppLogger.debug('[Main] 로케일 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');

  await FcmService.initialize(messengerKey: scaffoldMessengerKey);
  AppLogger.debug('[Main] FCM 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');

  stopwatch.stop();
  runApp(const PtSolutionApp());
}

class PtSolutionApp extends StatelessWidget {
  const PtSolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: MaterialApp(
        title: 'PT Solution',
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        locale: const Locale('ko', 'KR'),
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.memberLogin: (_) => const LoginScreen(),
          AppRoutes.pendingApproval: (_) => const PendingApprovalScreen(),
          AppRoutes.onboardingBasic: (_) => const OnboardingBasicScreen(),
          AppRoutes.onboardingBody: (_) => const OnboardingBodyScreen(),
          AppRoutes.memberHome: (_) => const MemberHomeScreen(),
          AppRoutes.trainerHome: (_) => const TrainerHomeScreen(),
          AppRoutes.adminHome: (_) => const AdminHomeScreen(),
        },
      ),
    );
  }
}
