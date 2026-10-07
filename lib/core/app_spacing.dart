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

  static const double screenH = 16; // 화면 좌우 여백
  static const double itemV = 12;
}

/// 모서리는 세 가지뿐: 사진 0 · 카드/입력/시트 8 · 버튼/배지 pill
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double card = 8;
  static const double pill = 9999;

  // 기존 이름 — 모두 카드 반경(8)으로 통일
  static const double xs = card;
  static const double sm = card;
  static const double md = card;
  static const double lg = card;
  static const double xl = card;
  static const double xxl = card;
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
  static const double buttonHeightLg = 52;
  static const double icon = 20;
  static const double iconSm = 14;
  static const double iconNav = 24;
  static const double avatar = 40;
  static const double orbLoader = 64;
  static const double orbInline = 20;
  static const double appBar = 56;
}
