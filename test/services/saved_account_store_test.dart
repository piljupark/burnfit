import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:pt_solution_v2/services/saved_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user({UserRole role = UserRole.member}) {
  final now = DateTime(2026, 10, 10);
  return AppUser(
    uid: 'u1',
    email: 'minji@burnfit.kr',
    name: '김민지',
    role: role,
    status: UserStatus.approved,
    centerId: 'c1',
    centerName: '버닝짐 강남점',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장한 계정이 없으면 null', () async {
    expect(await SavedAccountStore.load(), isNull);
  });

  test('저장한 계정을 그대로 읽는다 (비밀번호는 저장하지 않는다)', () async {
    await SavedAccountStore.save(_user(role: UserRole.trainer));
    final saved = await SavedAccountStore.load();
    expect(saved, isNotNull);
    expect(saved!.email, 'minji@burnfit.kr');
    expect(saved.centerName, '버닝짐 강남점');
    expect(saved.role, UserRole.trainer);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_login_account')!;
    expect(raw.contains('password'), isFalse);
  });

  test('다른 계정으로 저장하면 덮어쓴다', () async {
    await SavedAccountStore.save(_user());
    await SavedAccountStore.save(_user(role: UserRole.admin));
    expect((await SavedAccountStore.load())!.role, UserRole.admin);
  });

  test('지우면 null', () async {
    await SavedAccountStore.save(_user());
    await SavedAccountStore.clear();
    expect(await SavedAccountStore.load(), isNull);
  });

  test('깨졌거나 모르는 역할이면 null (로그인 화면은 이메일 입력으로)', () async {
    SharedPreferences.setMockInitialValues({
      'saved_login_account': '{"email":',
    });
    expect(await SavedAccountStore.load(), isNull);

    SharedPreferences.setMockInitialValues({
      'saved_login_account':
          '{"email":"a@b.kr","centerName":"센터","role":"owner"}',
    });
    expect(await SavedAccountStore.load(), isNull);
  });

  test('역할 이름표', () {
    expect(UserRole.member.label, '회원');
    expect(UserRole.trainer.label, '트레이너');
    expect(UserRole.admin.label, '관리자');
  });
}
