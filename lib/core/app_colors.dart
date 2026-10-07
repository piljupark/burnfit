import 'package:flutter/material.dart';

/// Galloway 디자인 시스템 색 토큰 (다크 단일 테마).
///
/// 원칙
/// - 캔버스는 하나: 모든 화면 바탕은 [canvas]. 라이트 모드는 없다.
/// - UI는 흰색과 회색만. 상태는 색이 아니라 모양(채움/외곽선)으로 구분한다.
/// - [danger]는 되돌릴 수 없는 행동의 글자에만.
/// - accent* 는 일러스트·아바타·차트 계열 구분 전용. 버튼·아이콘 등 UI 컨트롤에는 쓰지 않는다.
/// - 그림자 대신 [hairline] 테두리와 면 색(canvas → canvasCard)으로 층을 나눈다.
class AppColors {
  AppColors._();

  // ── Galloway 기본 토큰 ─────────────────────────────────────────────────────
  static const Color canvas = Color(0xFF0A0A0A); // 유일한 페이지 바탕
  static const Color canvasCard = Color(0xFF191919); // 카드·시트·다이얼로그·토스트 면
  static const Color canvasSoft = Color(0xFF1A1C20); // 입력창, 눌림, 로딩 자리
  static const Color canvasMid = Color(0xFF363A3F); // 중첩 면, 진행 막대 바탕, 손잡이
  static const Color hairline = Color(0xFF212327); // 1px 테두리·구분선
  static const Color outline = Color(0x40FFFFFF); // 외곽선 pill 버튼 테두리 (25%)

  static const Color ink = Color(0xFFFFFFFF); // 기본 글자·아이콘
  static const Color body = Color(0xFFDADBDF); // 보조 본문 (캔버스·카드 모두)
  static const Color mute = Color(0xFF7D8187); // 캡션 (캔버스 위 전용. 카드 위에서는 body)

  static const Color primary = Color(0xFFFFFFFF); // 화면당 하나의 주 행동 채움
  static const Color onPrimary = Color(0xFF0A0A0A); // primary 위 글자

  static const Color scrim = Color(0x8C000000); // 사진 위 배지 배경 (55%)
  static const Color dim = Color(0x59000000); // 비활성 덮개 (35%)
  static const Color select = Color(0x80000000); // 선택 덮개 (50%)
  static const Color backdrop = Color(0x99000000); // 시트·다이얼로그 뒤 (60%)

  static const Color danger = Color(0xFFE5484D); // 파괴적 행동 글자 전용

  // 일러스트·아바타·차트 전용
  static const Color accentSunset = Color(0xFFFF7A17);
  static const Color accentSunsetSoft = Color(0xFFFFC285);
  static const Color accentDusk = Color(0xFF7C3AED);
  static const Color accentTwilight = Color(0xFFC4B5FD);
  static const Color accentBreeze = Color(0xFFA0C3EC);
  static const Color accentMidnight = Color(0xFF0D1726);

  /// 아바타 이니셜 원 색 (사용자 id로 고정 순환).
  static const List<Color> avatarColors = [accentTwilight, accentBreeze, accentSunsetSoft];

  /// 차트 계열 구분 색 (밝기 차이가 나는 순서).
  static const List<Color> chartSeries = [ink, accentBreeze, accentSunsetSoft, accentTwilight, mute];

  // ═══════════════════════════════════════════════════════════════════════════
  // 기존 이름 → Galloway 값. 새 코드는 위 토큰을 쓴다.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color brand = primary;
  static const Color brandDark = body;
  static const Color brandLight = canvasSoft;

  // 도메인 색은 쓰지 않는다 (색 대신 모양·글자로 구분).
  static const Color workout = ink;
  static const Color diet = ink;
  static const Color trainer = ink;
  static const Color destructive = danger;

  static const Color bg = canvas;
  static const Color bgElevated = canvasCard;
  static const Color bgLogin = canvas;

  static const Color card = canvasCard;
  static const Color cardHover = canvasSoft;

  static const Color textPrimary = ink;
  static const Color textSecondary = body;
  static const Color textTertiary = mute;
  static const Color textDisabled = Color(0x997D8187);
  static const Color textOnAccent = onPrimary;
  static const Color textNeutral = ink;

  static const Color border = hairline;
  static const Color borderFocus = ink;
  static const Color divider = hairline;

  static const Color success = ink;
  static const Color warning = body;
  static const Color error = danger;
  static const Color info = ink;

  static const Color statusPending = body;
  static const Color statusApproved = ink;
  static const Color statusRejected = danger;

  static const Color mealBreakfast = accentSunsetSoft;
  static const Color mealLunch = accentBreeze;
  static const Color mealDinner = accentTwilight;
  static const Color mealSnack = accentSunset;

  static const Color categoryUpper = accentBreeze;
  static const Color categoryLower = accentTwilight;
  static const Color categoryCore = accentSunsetSoft;
  static const Color categoryCardio = accentSunset;

  static const Color navBg = canvas;
  static const Color navBorder = hairline;

  static const Color surface0 = canvas;
  static const Color surface1 = canvasCard;
  static const Color surface2 = canvasSoft;
  static const Color surface3 = canvasMid;
  static const Color separator = hairline;
  static const Color separatorStrong = canvasMid;
  static const Color label = ink;
  static const Color labelSecondary = body;
  static const Color labelTertiary = mute;
  static const Color labelQuaternary = canvasMid;
  static const Color brandOrange = primary;
  static const Color brandDim = canvasMid;

  static const Color primaryActive = body;
  static const Color primaryDisabled = canvasMid;
  static const Color background = canvas;
  static const Color surface = canvasCard;
  static const Color surfaceCard = canvasCard;
  static const Color surfaceElevated = canvasCard;
  static const Color surfaceVariant = canvasSoft;
  static const Color surfaceSoft = canvasSoft;
  static const Color hairlineStrong = canvasMid;
  static const Color onDark = ink;
  static const Color bodyStrong = body;
  static const Color muted = mute;
  static const Color mutedSoft = mute;
  static const Color accent = primary;
  static const Color accentMuted = body;
  static const Color brandActive = body;

  static const Color navGlass = canvas;
  static const Color navGlassBorder = hairline;
}
