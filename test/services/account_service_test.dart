import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/services/account_service.dart';

void main() {
  test('탈퇴 안내의 PT 이력 보관 기간이 서버 값과 같다 (functions/account_deletion.js)', () {
    final source = File('functions/account_deletion.js').readAsStringSync();
    final match = RegExp(r'const RETENTION_YEARS = (\d+);').firstMatch(source);

    expect(match, isNotNull, reason: 'RETENTION_YEARS를 찾지 못했습니다');
    expect(AccountService.ptRecordRetentionYears, int.parse(match!.group(1)!));
  });
}
