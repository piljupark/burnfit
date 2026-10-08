import '../models/center.dart' as center_model;
import 'firestore_service.dart';

/// 센터 검색 (로그인·가입 공통).
///
/// 운영 중인 센터 목록은 처음 한 번만 읽고, 이후 입력은 기기에서 거른다.
/// 그래서 글자를 칠 때마다 서버를 다시 읽지 않고, 늦게 온 응답이 최신 결과를 덮어쓰지도 않는다.
/// 읽기에 실패하면 예외를 그대로 던지고, 다음 검색 때 다시 읽는다.
/// 화면(State)마다 하나씩 만들어 쓴다.
class CenterSearch {
  /// 운영 중인 센터 전체를 읽는 함수 (테스트에서 바꿔 끼운다).
  final Future<List<center_model.Center>> Function() _loadActive;

  CenterSearch({Future<List<center_model.Center>> Function()? loadActive})
    : _loadActive = loadActive ?? (() => FirestoreService.searchCenters(''));

  Future<List<center_model.Center>>? _all;

  Future<List<center_model.Center>> search(String query) async {
    final loading = _all ??= _loadActive();
    final List<center_model.Center> all;
    try {
      all = await loading;
    } catch (_) {
      if (identical(_all, loading)) _all = null;
      rethrow;
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }
}
