import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/birth_date.dart';
import 'package:pt_solution_v2/core/validators.dart';

void main() {
  group('parseBirthDate', () {
    test('8자리 날짜를 읽는다', () {
      expect(parseBirthDate('19940512'), DateTime(1994, 5, 12));
      expect(parseBirthDate(' 20000229 '), DateTime(2000, 2, 29));
    });

    test('없는 날짜·다른 형식은 null', () {
      for (final raw in [
        null,
        '',
        '1994-05-12',
        '1994051',
        '19940230',
        '19941301',
        '20010229',
      ]) {
        expect(parseBirthDate(raw), isNull, reason: '$raw');
      }
    });
  });

  test('formatBirthDate는 점으로 나눈다', () {
    expect(formatBirthDate('19940512'), '1994.05.12');
    expect(formatBirthDate('abc'), isNull);
  });

  test('ageFromBirthDate는 생일 전후로 만 나이를 센다', () {
    final now = DateTime(2026, 5, 12);
    expect(ageFromBirthDate('19940512', now: now), 32);
    expect(ageFromBirthDate('19940513', now: now), 31);
    expect(ageFromBirthDate(null, now: now), isNull);
  });

  test('Validators.birthDate', () {
    expect(Validators.birthDate('19940512'), isNull);
    expect(Validators.birthDate('1994'), contains('8자리'));
    expect(Validators.birthDate('18991231'), isNotNull);
    expect(Validators.birthDate('19940230'), isNotNull);
    expect(Validators.birthDate('29990101'), isNotNull);
  });
}
