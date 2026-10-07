// 생년월일은 Firestore에 'yyyyMMdd' 8자리 문자열로 저장한다 (온보딩·프로필 편집 공통).

/// 8자리 문자열 → 날짜. 형식이 다르거나 없는 날짜(2월 30일 등)면 null.
DateTime? parseBirthDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (!RegExp(r'^\d{8}$').hasMatch(s)) return null;
  final y = int.parse(s.substring(0, 4));
  final m = int.parse(s.substring(4, 6));
  final d = int.parse(s.substring(6, 8));
  final date = DateTime(y, m, d);
  // DateTime은 넘친 날짜를 다음 달로 넘기므로 되돌려 비교한다.
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}

/// 화면 표시용: '1994.05.12'. 읽을 수 없으면 null.
String? formatBirthDate(String? raw) {
  final date = parseBirthDate(raw);
  if (date == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)}';
}

/// 만 나이. 읽을 수 없으면 null.
int? ageFromBirthDate(String? raw, {DateTime? now}) {
  final birth = parseBirthDate(raw);
  if (birth == null) return null;
  final today = now ?? DateTime.now();
  final beforeBirthday =
      today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day);
  return today.year - birth.year - (beforeBirthday ? 1 : 0);
}
