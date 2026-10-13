import 'package:pt_solution_v2/core/app_routing.dart';
import 'package:pt_solution_v2/core/constants.dart';
import 'package:pt_solution_v2/core/consent_terms.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

final _consented = ConsentRecord(
  version: ConsentTerms.version,
  privacyAt: DateTime(2026, 10, 13),
  healthAt: DateTime(2026, 10, 13),
);

AppUser _user({
  String uid = 'u1',
  UserRole role = UserRole.member,
  UserStatus status = UserStatus.pending,
  String? birthDate,
  ConsentRecord? consents,
  bool noConsent = false,
}) {
  final now = DateTime(2026, 1, 1);
  return AppUser(
    uid: uid,
    email: '$uid@example.com',
    name: '홍길동',
    role: role,
    status: status,
    centerId: 'c1',
    centerName: '센터',
    birthDate: birthDate,
    consents: noConsent ? null : (consents ?? _consented),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('accountStatusChange', () {
    test('대기 → 승인', () {
      expect(
        accountStatusChange(_user(), _user(status: UserStatus.approved)),
        AccountStatusChange.approved,
      );
    });

    test('승인 → 대기', () {
      expect(
        accountStatusChange(_user(status: UserStatus.approved), _user()),
        AccountStatusChange.backToPending,
      );
    });

    test('대기·승인 → 거절', () {
      for (final from in [UserStatus.pending, UserStatus.approved]) {
        expect(
          accountStatusChange(
            _user(status: from),
            _user(status: UserStatus.rejected),
          ),
          AccountStatusChange.rejected,
        );
      }
    });

    test('상태가 같으면 변화 없음', () {
      expect(accountStatusChange(_user(), _user()), isNull);
    });

    test('로그인·로그아웃·계정 전환은 변화로 보지 않는다', () {
      final approved = _user(status: UserStatus.approved);
      expect(accountStatusChange(null, approved), isNull);
      expect(accountStatusChange(approved, null), isNull);
      expect(
        accountStatusChange(
          _user(),
          _user(uid: 'u2', status: UserStatus.approved),
        ),
        isNull,
      );
    });
  });

  group('startRouteFor', () {
    test('승인된 회원은 생년월일이 없으면 온보딩부터', () {
      expect(
        startRouteFor(_user(status: UserStatus.approved)),
        AppRoutes.onboardingBasic,
      );
      expect(
        startRouteFor(
          _user(status: UserStatus.approved, birthDate: '19900101'),
        ),
        AppRoutes.memberHome,
      );
    });

    test('대기는 승인 대기 화면, 거절은 null', () {
      expect(startRouteFor(_user()), AppRoutes.pendingApproval);
      expect(startRouteFor(_user(status: UserStatus.rejected)), isNull);
    });
  });

  group('가입 동의', () {
    test('동의 기록이 없거나 예전 판이면 (거절 계정 빼고) 동의 화면부터', () {
      expect(startRouteFor(_user(noConsent: true)), AppRoutes.consent);
      expect(
        startRouteFor(
          _user(
            status: UserStatus.approved,
            role: UserRole.admin,
            noConsent: true,
          ),
        ),
        AppRoutes.consent,
      );
      expect(
        startRouteFor(
          _user(
            consents: ConsentRecord(
              version: ConsentTerms.version - 1,
              privacyAt: DateTime(2026),
              healthAt: DateTime(2026),
            ),
          ),
        ),
        AppRoutes.consent,
      );
      expect(
        startRouteFor(_user(status: UserStatus.rejected, consents: null)),
        isNull,
      );
    });

    test('회원은 건강 정보 동의도 있어야, 트레이너는 개인정보만', () {
      final privacyOnly = ConsentRecord(
        version: ConsentTerms.version,
        privacyAt: DateTime(2026, 10, 13),
      );
      expect(startRouteFor(_user(consents: privacyOnly)), AppRoutes.consent);
      expect(
        startRouteFor(
          _user(
            role: UserRole.trainer,
            status: UserStatus.approved,
            consents: privacyOnly,
          ),
        ),
        AppRoutes.trainerHome,
      );
    });
  });
}
