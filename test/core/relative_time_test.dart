import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/core/relative_time.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  final now = DateTime(2026, 10, 7, 15, 0);

  test('시간 차이에 맞는 문구를 만든다', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
      '방금',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
      '5분 전',
    );
    expect(formatRelativeTime(DateTime(2026, 10, 7, 9), now: now), '6시간 전');
    expect(formatRelativeTime(DateTime(2026, 10, 6, 23), now: now), '어제');
    expect(formatRelativeTime(DateTime(2026, 10, 3), now: now), '4일 전');
    expect(formatRelativeTime(DateTime(2026, 9, 1), now: now), '9월 1일');
    expect(formatRelativeTime(DateTime(2025, 12, 31), now: now), '2025.12.31');
  });

  test('자정을 넘긴 몇 시간 전은 "어제"다', () {
    final earlyMorning = DateTime(2026, 10, 7, 1, 0);
    expect(
      formatRelativeTime(DateTime(2026, 10, 6, 22, 0), now: earlyMorning),
      '어제',
    );
  });

  test('미래 시각(기기 시계 오차)은 "방금"으로 둔다', () {
    expect(
      formatRelativeTime(now.add(const Duration(minutes: 3)), now: now),
      '방금',
    );
  });
}
