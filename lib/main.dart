import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

/// 개발용: `--dart-define=USE_FIREBASE_EMULATOR=true`로 빌드하면 로컬 Firebase 에뮬레이터에 붙는다.
/// 정식 빌드에는 이 값이 없으므로 항상 실제 프로젝트를 쓴다.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const String _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapApp();
  runApp(const PtSolutionApp());
}

/// Firebase·로케일·(선택) 알림 초기화. 화면 투어 통합 테스트도 이 함수를 쓴다.
Future<void> bootstrapApp({bool withMessaging = true}) async {
  final stopwatch = Stopwatch()..start();
  AppLogger.debug('[Main] Firebase 초기화 시작');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.debug('[Main] Firebase 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');

  if (useFirebaseEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, 5001);
    AppLogger.debug('[Main] Firebase 에뮬레이터 연결: $_emulatorHost');
  }

  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !useFirebaseEmulator,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await initializeDateFormatting('ko_KR', null);
  AppLogger.debug('[Main] 로케일 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');

  if (withMessaging) {
    await FcmService.initialize(messengerKey: scaffoldMessengerKey);
    AppLogger.debug('[Main] FCM 초기화 완료: ${stopwatch.elapsedMilliseconds}ms');
  }
  stopwatch.stop();
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
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
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
