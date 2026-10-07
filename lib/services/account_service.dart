import 'package:cloud_functions/cloud_functions.dart';

import 'auth_service.dart';
import 'fcm_service.dart';
import 'workout_draft_service.dart';

/// 계정 탈퇴.
///
/// 데이터 삭제는 서버 함수(`deleteMyAccount`, functions/account_deletion.js)만 한다.
/// 앱은 본인 확인(비밀번호 재입력)과 이 기기의 흔적 정리만 맡는다.
class AccountService {
  AccountService._();

  /// 탈퇴 회원의 PT 이용 내역 보관 기간(년). 서버 값과 같아야 한다
  /// (functions/account_deletion.js `RETENTION_YEARS`).
  static const int ptRecordRetentionYears = 3;

  static final HttpsCallable _deleteMyAccount =
      FirebaseFunctions.instance.httpsCallable('deleteMyAccount');

  /// 비밀번호로 본인 확인 → 서버에서 계정·기록 삭제 → 이 기기 정리 → 로그아웃.
  ///
  /// 비밀번호가 틀리면 FirebaseAuthException,
  /// 서버가 거부하면(예: 관리자 계정) FirebaseFunctionsException을 던진다.
  static Future<void> deleteMyAccount({
    required String uid,
    required String password,
  }) async {
    await AuthService.reauthenticate(password);
    await _deleteMyAccount.call<Map<String, dynamic>>();

    // 여기부터는 서버 삭제가 끝난 뒤의 정리라 실패해도 탈퇴 자체는 완료된 상태다.
    await FcmService.detachDevice();
    await WorkoutDraftService.clearAllFor(uid);
    await AuthService.signOut();
  }
}
