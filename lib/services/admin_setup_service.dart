import 'package:cloud_functions/cloud_functions.dart';

import 'auth_service.dart';

/// 센터 관리자 가입.
///
/// 관리자 계정과 센터 문서는 서버 함수(`registerCenterAdmin`)만 만들 수 있다.
/// 설정 코드 검증·시도 횟수 제한도 서버에서 한다 (functions/admin_setup.js).
class AdminSetupService {
  AdminSetupService._();

  /// 서버 검증 기준과 같다 (functions/admin_setup.js `LIMITS.passwordMin`).
  static const int passwordMinLength = 8;

  static final HttpsCallable _registerCenterAdmin = FirebaseFunctions.instance
      .httpsCallable('registerCenterAdmin');

  /// 관리자 계정과 센터를 만든 뒤 그 계정으로 로그인한다.
  ///
  /// 서버 단계에서 실패하면 [FirebaseFunctionsException]을 던진다
  /// (사용자 문구는 `details.userMessage`, `AppFeedback.errorMessage`가 표시).
  /// 가입은 됐지만 로그인에서 실패하면 [AdminRegisteredButSignInFailed]를 던진다.
  static Future<void> registerCenterAdmin({
    required String name,
    required String email,
    required String password,
    required String centerName,
    String? centerAddress,
    required String setupCode,
  }) async {
    await _registerCenterAdmin.call<Map<String, dynamic>>({
      'name': name,
      'email': email,
      'password': password,
      'centerName': centerName,
      'centerAddress': centerAddress,
      'setupCode': setupCode,
    });

    try {
      await AuthService.signIn(email: email, password: password);
    } on Exception catch (e) {
      throw AdminRegisteredButSignInFailed(e);
    }
  }
}

/// 계정 생성은 끝났고 자동 로그인만 실패한 경우.
/// 같은 정보로 다시 가입하면 "이미 가입된 이메일"이 되므로 로그인 화면으로 안내해야 한다.
class AdminRegisteredButSignInFailed implements Exception {
  final Exception cause;

  const AdminRegisteredButSignInFailed(this.cause);

  @override
  String toString() => 'AdminRegisteredButSignInFailed($cause)';
}
