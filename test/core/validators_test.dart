import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/validators.dart';

void main() {
  test('신체 정보: 빈 칸은 null, 범위 안의 숫자는 그대로', () {
    final m = Validators.bodyMetrics(height: ' 165 ', weight: '', muscleMass: '31.4', bodyFat: '12');
    expect(m.height, 165);
    expect(m.weight, isNull);
    expect(m.muscleMass, 31.4);
    expect(m.bodyFat, 12);
  });

  test('신체 정보: 숫자가 아니거나 범위 밖이면 안내 문구와 함께 거부 (조용히 지우지 않는다)', () {
    expect(
      () => Validators.bodyMetrics(height: '1.2.3', weight: '', muscleMass: '', bodyFat: ''),
      throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('키'))),
    );
    expect(
      () => Validators.bodyMetrics(height: '', weight: '0', muscleMass: '', bodyFat: ''),
      throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('20~300'))),
    );
  });

  test('새 비밀번호는 공통 기준(8자) 이상이어야 한다', () {
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('1234567'), contains('8자'));
    expect(Validators.password('12345678'), isNull);
  });

  test('로그인 비밀번호는 비어 있는지만 본다 (예전에 만든 짧은 비밀번호 허용)', () {
    expect(Validators.existingPassword(''), isNotNull);
    expect(Validators.existingPassword(null), isNotNull);
    expect(Validators.existingPassword('123456'), isNull);
  });
}
