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
}
