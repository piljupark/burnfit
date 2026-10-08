import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../models/user.dart';

/// 회원 신체 정보 (키·체중·골격근량·체지방량·목표).
///
/// 회원의 '신체 정보 공유' 설정을 규칙으로 지키기 위해 사용자 문서와 나눠
/// `users/{uid}/body_profile/current`에 둔다 (firestore.rules 참고).
/// 예전에는 사용자 문서의 `profile` 필드에 있었다 — [loadOwn]이 본인 것을 옮긴다.
class BodyProfileService {
  BodyProfileService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _ref(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('body_profile')
      .doc('current');

  static Future<UserProfile?> get(String uid) async {
    ServiceValidator.requireText(uid, '사용자 ID');

    final doc = await _ref(uid).get();
    final data = doc.data();
    return data == null ? null : UserProfile.fromMap(data);
  }

  static Future<void> save(String uid, UserProfile profile) async {
    ServiceValidator.requireText(uid, '사용자 ID');

    await _ref(
      uid,
    ).set({...profile.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// 본인 신체 정보. 예전 위치(사용자 문서 `profile`)에만 있으면 새 위치로 옮기고 예전 필드를 지운다.
  static Future<UserProfile?> loadOwn(AppUser user) async {
    final current = await get(user.uid);
    final legacy = user.profile;
    if (legacy == null) return current;

    try {
      final batch = _db.batch();
      if (current == null) {
        batch.set(_ref(user.uid), {
          ...legacy.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_db.collection('users').doc(user.uid), {
        'profile': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      // 옮기기에 실패해도 화면에는 값을 보여주고, 다음 실행 때 다시 시도한다.
      AppLogger.debug('[BodyProfile] 예전 신체 정보 옮기기 실패: $e');
    }
    return current ?? legacy;
  }

  /// 담당 트레이너가 보는 회원 신체 정보. 회원이 공유를 껐으면 읽지 않는다.
  /// 아직 옮겨지지 않은 회원은 예전 값을 쓴다.
  static Future<UserProfile?> loadShared(AppUser member) async {
    if (!member.shareSettings.body) return null;
    return await get(member.uid) ?? member.profile;
  }
}
