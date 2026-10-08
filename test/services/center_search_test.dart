import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/center.dart' as center_model;
import 'package:pt_solution_v2/services/center_search.dart';

center_model.Center _center(String id, String name) => center_model.Center(
  id: id,
  name: name,
  adminId: 'admin',
  status: 'active',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  final centers = [_center('a', '강남 센터'), _center('b', 'BurnFit 홍대')];

  test('목록은 한 번만 읽고 이후 검색은 기기에서 거른다 (대소문자 무시)', () async {
    var loads = 0;
    final search = CenterSearch(
      loadActive: () async {
        loads++;
        return centers;
      },
    );

    expect(await search.search(''), hasLength(2));
    expect((await search.search('강남')).single.id, 'a');
    expect((await search.search(' burnfit ')).single.id, 'b');
    expect(await search.search('없는 센터'), isEmpty);
    expect(loads, 1);
  });

  test('읽기에 실패하면 예외를 던지고 다음 검색 때 다시 읽는다', () async {
    var loads = 0;
    final search = CenterSearch(
      loadActive: () async {
        loads++;
        if (loads == 1) throw Exception('network');
        return centers;
      },
    );

    await expectLater(search.search('강남'), throwsException);
    expect((await search.search('강남')).single.id, 'a');
    expect(loads, 2);
  });
}
