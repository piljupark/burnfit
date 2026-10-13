import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/service_validator.dart';
import '../core/validators.dart';

/// 휴대폰 번호 (`users/{uid}/contact/current`).
///
/// 사용자 문서(`users/{uid}`)는 같은 센터 트레이너도 읽을 수 있어 번호를 거기 두지 않는다.
/// 이 문서는 본인과 그 센터 관리자만 읽는다 (규칙). 쓰기는 본인만. 탈퇴하면 서버가 함께 지운다.
class ContactService {
  ContactService._();

  static DocumentReference<Map<String, dynamic>> ref(String uid) {
    ServiceValidator.requireText(uid, '사용자 ID');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('contact')
        .doc('current');
  }

  /// 저장할 내용 ('010-1234-5678' 형태로 맞춘다). 형식이 아니면 ArgumentError.
  static Map<String, dynamic> dataFor(String phone) {
    final normalized = Validators.normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError('010으로 시작하는 휴대폰 번호를 입력해주세요.');
    }
    return {'phone': normalized, 'updatedAt': FieldValue.serverTimestamp()};
  }

  /// 저장된 번호. 없으면 null.
  static Future<String?> getPhone(String uid) async {
    final snap = await ref(uid).get();
    final phone = snap.data()?['phone'];
    return phone is String && phone.isNotEmpty ? phone : null;
  }

  static Future<void> savePhone(String uid, String phone) =>
      ref(uid).set(dataFor(phone));
}
