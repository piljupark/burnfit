import '../models/user.dart';
import 'constants.dart';

/// 로그인한 사용자가 처음 갈 화면 (스플래시·로그인·승인 대기 공통).
/// 거절된 계정은 null — 호출하는 쪽이 로그아웃시키고 로그인 화면으로 보낸다.
/// 로그인 중 관리자가 계정 상태를 바꿨을 때 앱이 할 일.
enum AccountStatusChange {
  /// 승인됨 → 역할별 첫 화면으로
  approved,

  /// 승인이 취소되어 다시 대기 → 승인 대기 화면으로
  backToPending,

  /// 거절됨 → 로그아웃 후 로그인 화면으로
  rejected,
}

/// 같은 계정의 상태가 [before]에서 [after]로 바뀌었을 때만 값을 준다.
/// 로그인·로그아웃·계정 전환(uid가 다름)은 상태 변화로 보지 않는다.
AccountStatusChange? accountStatusChange(AppUser? before, AppUser? after) {
  if (before == null || after == null) return null;
  if (before.uid != after.uid || before.status == after.status) return null;
  switch (after.status) {
    case UserStatus.approved:
      return AccountStatusChange.approved;
    case UserStatus.pending:
      return AccountStatusChange.backToPending;
    case UserStatus.rejected:
      return AccountStatusChange.rejected;
  }
}

String? startRouteFor(AppUser user) {
  switch (user.status) {
    case UserStatus.rejected:
      return null;
    case UserStatus.pending:
      return AppRoutes.pendingApproval;
    case UserStatus.approved:
      break;
  }
  switch (user.role) {
    case UserRole.admin:
      return AppRoutes.adminHome;
    case UserRole.trainer:
      return AppRoutes.trainerHome;
    case UserRole.member:
      // 생년월일·성별·신체 정보를 아직 입력하지 않은 회원은 온보딩부터.
      return user.birthDate == null
          ? AppRoutes.onboardingBasic
          : AppRoutes.memberHome;
  }
}
