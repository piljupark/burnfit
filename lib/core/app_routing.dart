import '../models/user.dart';
import 'constants.dart';

/// 로그인한 사용자가 처음 갈 화면 (스플래시·로그인·승인 대기 공통).
/// 거절된 계정은 null — 호출하는 쪽이 로그아웃시키고 로그인 화면으로 보낸다.
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
