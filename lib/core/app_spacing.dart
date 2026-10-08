/// Galloway 간격: 2 · 4 · 8 · 12 · 16 · 24 · 32 · 48
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2; // 사진 그리드 간격
  static const double xs = 4; // 배지 ↔ 가장자리
  static const double sm = 8; // 아이콘 ↔ 라벨, 버튼 세로
  static const double md = 12; // 목록 항목 세로 패딩
  static const double base = 16; // 화면 좌우, 카드 안쪽
  static const double lg = 20;
  static const double xl = 24; // 시트·다이얼로그 안쪽, 섹션 사이
  static const double xl2 = 32; // 큰 섹션 사이
  static const double xl3 = 48; // 빈 상태 위아래
  static const double xl4 = 64;
  static const double section = 32;

  static const double screenH = 20; // 화면 좌우 여백
  static const double itemV = 12;
}

/// 모서리: 아이콘 박스 12 · 입력/작은 버튼 14 · 버튼/숫자 칸 18 · 카드 20 · 시트 28 · 알약 pill
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double iconBox = 12;
  static const double field = 14;
  static const double button = 18;
  static const double card = 20;
  static const double sheet = 28;
  static const double pill = 9999;

  // 기존 이름
  static const double xs = iconBox;
  static const double sm = field;
  static const double md = button;
  static const double lg = card;
  static const double xl = card;
  static const double xxl = sheet;
  static const double full = pill;
}

/// 크기 토큰
class AppSize {
  AppSize._();

  static const double touchMin = 44;

  /// 목록 한 줄 최소 높이 (AppActionRow와 같은 규칙: 56 + 위아래 8 여백, 두 줄이면 내용만큼 늘어남).
  static const double listRow = 56;

  /// 스크롤 목록 맨 아래 여백: 하단 탭(84)에 마지막 줄이 가리지 않게.
  static const double navClearance = 120;
  static const double buttonHeight = 40;
  static const double buttonHeightSm = 32;
  static const double buttonHeightLg = 56;
  static const double icon = 20;
  static const double iconSm = 14;
  static const double iconNav = 24;
  static const double avatar = 40;
  static const double orbLoader = 64;
  static const double orbInline = 20;
  static const double appBar = 56;
}
