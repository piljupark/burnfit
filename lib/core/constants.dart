class AppConstants {
  AppConstants._();

  static const int imageMaxWidth = 1080;
  static const int imageMaxHeight = 1080;
  static const int imageQuality = 75;

  /// 사진첩에서 고를 때 긴 변을 여기까지 줄인다 (원본 크기로 다시 만드는 시간 · 미리보기 메모리 절약).
  /// 저장할 때 압축(짧은 변 [imageMaxWidth])과 결과 크기가 같다.
  static const double imagePickMaxEdge = 1440;
  static const int imageMaxCount = 5;
  static const int imageMaxMegabytes = 5;
  static const int imageMaxBytes = imageMaxMegabytes * 1024 * 1024;

  static const int listPageSize = 20;

  static const int recentDays = 30;
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String memberLogin = '/login';
  static const String trainerLogin = '/#/trainer';
  static const String adminLogin = '/#/admin';

  static const String memberHome = '/member/home';
  static const String trainerHome = '/trainer/home';
  static const String adminHome = '/admin/home';

  static const String onboardingBasic = '/onboarding/basic';
  static const String onboardingBody = '/onboarding/body';
  static const String pendingApproval = '/pending';
}
