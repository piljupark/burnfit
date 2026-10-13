import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/user.dart';

Map<String, dynamic> _doc({Object? updatedAt}) => {
  'uid': 'u1',
  'email': 'a@b.c',
  'name': '김민지',
  'role': 'member',
  'status': 'approved',
  'centerId': 'c1',
  'centerName': '센터',
  'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
  'updatedAt': updatedAt,
};

void main() {
  test('수정 시각이 아직 정해지지 않았으면(빈칸) 가입 시각으로 읽는다', () {
    final user = AppUser.fromMap(_doc());
    expect(user.updatedAt, DateTime(2026, 10, 1));
  });

  test('수정 시각이 있으면 그대로', () {
    final user = AppUser.fromMap(
      _doc(updatedAt: Timestamp.fromDate(DateTime(2026, 10, 14))),
    );
    expect(user.updatedAt, DateTime(2026, 10, 14));
  });

  test('수정 시각 형식이 틀리면 여전히 오류', () {
    expect(() => AppUser.fromMap(_doc(updatedAt: '')), throwsArgumentError);
  });
}
