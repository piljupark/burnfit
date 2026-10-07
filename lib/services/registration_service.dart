import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/center.dart' as center_model;
import '../models/join_request.dart';
import '../models/user.dart';
import 'auth_service.dart';

/// 회원·트레이너 가입 (공통).
///
/// 인증 계정 → 사용자 문서 + 가입 신청(한 배치) 순서로 만든다. 문서 저장이 실패하면 방금 만든
/// 인증 계정을 지워, "이메일은 이미 쓰였는데 계정 정보는 없는" 상태가 남지 않게 한다.
class RegistrationService {
  RegistrationService._();

  static Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required center_model.Center center,
  }) async {
    assert(role == UserRole.member || role == UserRole.trainer);
    final cred = await AuthService.signUp(
      email: email.trim(),
      password: password,
    );
    final authUser = cred.user!;
    final now = DateTime.now();
    final user = AppUser(
      uid: authUser.uid,
      email: email.trim(),
      name: name.trim(),
      role: role,
      status: UserStatus.pending,
      centerId: center.id,
      centerName: center.name,
      createdAt: now,
      updatedAt: now,
    );
    final request = JoinRequest(
      id: const Uuid().v4(),
      userId: user.uid,
      userName: user.name,
      userEmail: user.email,
      centerId: center.id,
      centerName: center.name,
      role: role.name,
      status: JoinRequestStatus.pending,
      createdAt: now,
    );

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch()
        ..set(db.collection('users').doc(user.uid), user.toMap())
        ..set(db.collection('join_requests').doc(request.id), request.toMap());
      await batch.commit();
    } catch (_) {
      // 되돌리기: 인증 계정만 남지 않게 한다 (실패해도 원래 오류를 보여준다).
      try {
        await authUser.delete();
      } catch (_) {}
      rethrow;
    }
    return user;
  }
}
