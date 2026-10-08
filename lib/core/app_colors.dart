import 'package:flutter/material.dart';

/// 화면 테마 한 벌의 색. 라이트(기본)와 다크 두 벌이 있다.
/// 구조·모양은 같고 면과 글자 색만 뒤집는다 (라이트의 주 행동은 검은 채움).
class AppPalette {
  final Brightness brightness;
  final Color canvas;
  final Color canvasCard;
  final Color canvasSoft;
  final Color canvasMid;
  final Color hairline;
  final Color outline;
  final Color ink;
  final Color body;
  final Color mute;
  final Color primary;
  final Color onPrimary;
  final Color danger;
  final List<Color> chartSeries;

  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.canvasCard,
    required this.canvasSoft,
    required this.canvasMid,
    required this.hairline,
    required this.outline,
    required this.ink,
    required this.body,
    required this.mute,
    required this.primary,
    required this.onPrimary,
    required this.danger,
    required this.chartSeries,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0A0A),
    canvasCard: Color(0xFF191919),
    canvasSoft: Color(0xFF1A1C20),
    canvasMid: Color(0xFF363A3F),
    hairline: Color(0xFF212327),
    outline: Color(0x40FFFFFF),
    ink: Color(0xFFFFFFFF),
    body: Color(0xFFDADBDF),
    mute: Color(0xFF7D8187),
    primary: Color(0xFFFF7A33),
    onPrimary: Color(0xFF191919),
    danger: Color(0xFFE5484D),
    chartSeries: [
      Color(0xFFFFFFFF),
      AppColors.accentBreeze,
      AppColors.accentSunsetSoft,
      AppColors.accentTwilight,
      Color(0xFF7D8187),
    ],
  );

  /// 대비: ink·body는 흰 바탕에서 7:1 이상, mute는 4.5:1 이상 (캔버스 위 캡션).
  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFFFFFFF),
    canvasCard: Color(0xFFF6F6F7),
    canvasSoft: Color(0xFFF3F3F5),
    canvasMid: Color(0xFFD4D4D8),
    hairline: Color(0xFFF0F0F2),
    outline: Color(0xFFD4D4D8),
    ink: Color(0xFF191919),
    body: Color(0xFF4A4A4A),
    mute: Color(0xFF6B6B70),
    primary: Color(0xFFFF7A33),
    onPrimary: Color(0xFF191919),
    danger: Color(0xFFD93036),
    // 흰 바탕에서 구분되도록 진한 계열 (둘째가 강조색)
    chartSeries: [
      Color(0xFF191919),
      Color(0xFFFF7A33),
      Color(0xFF3E7BC4),
      Color(0xFF7C5CE0),
      Color(0xFF6B6F76),
    ],
  );
}

/// BurnFit 디자인 시스템 색 토큰 (미니멀 · 강조색 하나). 지금 테마([AppPalette])의 값을 돌려준다.
///
/// 원칙
/// - 캔버스는 하나: 모든 화면 바탕은 [canvas]. 라이트(기본)·다크는 같은 구조에서 색만 다르다.
/// - 강조색은 [primary](오렌지) 하나, 그 위 글자는 [onPrimary](검정). 나머지 UI는 무채색.
/// - 상태는 색만이 아니라 모양(채움/외곽선)으로도 구분한다.
/// - [danger]는 되돌릴 수 없는 행동의 글자에만.
/// - accent* 는 일러스트·아바타·차트 계열 구분 전용. 버튼·아이콘 등 UI 컨트롤에는 쓰지 않는다.
/// - 그림자 대신 [hairline] 테두리와 면 색(canvas → canvasCard)으로 층을 나눈다.
///
/// 토큰이 테마에 따라 바뀌므로 `const` 위젯·장식 안에서 쓸 수 없다.
/// 테마 전환은 [ThemeController]가 맡는다 (팔레트 교체 + 화면 전체 다시 그리기).
class AppColors {
  AppColors._();

  /// 지금 팔레트. [ThemeController]만 바꾼다.
  static AppPalette palette = AppPalette.light;

  static AppPalette get _p => palette;

  static bool get isLight => _p.brightness == Brightness.light;

  // ── Galloway 기본 토큰 ─────────────────────────────────────────────────────
  static Color get canvas => _p.canvas; // 유일한 페이지 바탕
  static Color get canvasCard => _p.canvasCard; // 카드·시트·다이얼로그·토스트 면
  static Color get canvasSoft => _p.canvasSoft; // 입력창, 눌림, 로딩 자리
  static Color get canvasMid => _p.canvasMid; // 중첩 면, 진행 막대 바탕, 손잡이
  static Color get hairline => _p.hairline; // 1px 테두리·구분선
  static Color get outline => _p.outline; // 외곽선 pill 버튼 테두리

  static Color get ink => _p.ink; // 기본 글자·아이콘
  static Color get body => _p.body; // 보조 본문 (캔버스·카드 모두)
  static Color get mute => _p.mute; // 캡션 (캔버스 위 전용. 카드 위에서는 body)

  static Color get primary => _p.primary; // 화면당 하나의 주 행동 채움
  static Color get onPrimary => _p.onPrimary; // primary 위 글자

  // 사진·화면 위에 덮는 색은 테마와 관계없이 어둡다.
  static const Color scrim = Color(0x8C000000); // 사진 위 배지 배경 (55%)
  static const Color dim = Color(0x59000000); // 비활성 덮개 (35%)
  static const Color select = Color(0x80000000); // 선택 덮개 (50%)
  static const Color backdrop = Color(0x99000000); // 시트·다이얼로그 뒤 (60%)

  static Color get danger => _p.danger; // 파괴적 행동 글자 전용

  // 안내·경고 줄: 연한 주황 바탕 + 진한 주황 글자 (두 테마 공통)
  static const Color noticeBg = Color(0xFFFFF1E8);
  static const Color noticeText = Color(0xFFA8400E);

  /// 새 소식 점 (알림 종, 바로가기)
  static const Color newDot = Color(0xFFFF5A1F);

  // 일러스트·차트 전용 (두 테마 공통)
  static const Color accentSunset = Color(0xFFFF7A17);
  static const Color accentSunsetSoft = Color(0xFFFFC285);
  static const Color accentDusk = Color(0xFF7C3AED);
  static const Color accentTwilight = Color(0xFFC4B5FD);
  static const Color accentBreeze = Color(0xFFA0C3EC);
  static const Color accentMidnight = Color(0xFF0D1726);

  /// 차트 계열 구분 색 (밝기 차이가 나는 순서).
  static List<Color> get chartSeries => _p.chartSeries;

  // ═══════════════════════════════════════════════════════════════════════════
  // 기존 이름 → Galloway 값. 새 코드는 위 토큰을 쓴다.
  // ═══════════════════════════════════════════════════════════════════════════

  static Color get brand => primary;
  static Color get brandDark => body;
  static Color get brandLight => canvasSoft;

  // 도메인 색은 쓰지 않는다 (색 대신 모양·글자로 구분).
  static Color get workout => ink;
  static Color get diet => ink;
  static Color get trainer => ink;
  static Color get destructive => danger;

  static Color get bg => canvas;
  static Color get bgElevated => canvasCard;
  static Color get bgLogin => canvas;

  static Color get card => canvasCard;
  static Color get cardHover => canvasSoft;

  static Color get textPrimary => ink;
  static Color get textSecondary => body;
  static Color get textTertiary => mute;
  static Color get textDisabled => _p.mute.withValues(alpha: 0.6);
  static Color get textOnAccent => onPrimary;
  static Color get textNeutral => ink;

  static Color get border => hairline;
  static Color get borderFocus => ink;
  static Color get divider => hairline;

  static Color get success => ink;
  static Color get warning => body;
  static Color get error => danger;
  static Color get info => ink;

  static Color get statusPending => body;
  static Color get statusApproved => ink;
  static Color get statusRejected => danger;

  static Color get mealBreakfast => accentSunsetSoft;
  static Color get mealLunch => accentBreeze;
  static Color get mealDinner => accentTwilight;
  static Color get mealSnack => accentSunset;

  static Color get categoryUpper => accentBreeze;
  static Color get categoryLower => accentTwilight;
  static Color get categoryCore => accentSunsetSoft;
  static Color get categoryCardio => accentSunset;

  static Color get navBg => canvas;
  static Color get navBorder => hairline;

  static Color get surface0 => canvas;
  static Color get surface1 => canvasCard;
  static Color get surface2 => canvasSoft;
  static Color get surface3 => canvasMid;
  static Color get separator => hairline;
  static Color get separatorStrong => canvasMid;
  static Color get label => ink;
  static Color get labelSecondary => body;
  static Color get labelTertiary => mute;
  static Color get labelQuaternary => canvasMid;
  static Color get brandOrange => primary;
  static Color get brandDim => canvasMid;

  static Color get primaryActive => body;
  static Color get primaryDisabled => canvasMid;
  static Color get background => canvas;
  static Color get surface => canvasCard;
  static Color get surfaceCard => canvasCard;
  static Color get surfaceElevated => canvasCard;
  static Color get surfaceVariant => canvasSoft;
  static Color get surfaceSoft => canvasSoft;
  static Color get hairlineStrong => canvasMid;
  static Color get onDark => ink;
  static Color get bodyStrong => body;
  static Color get muted => mute;
  static Color get mutedSoft => mute;
  static Color get accent => primary;
  static Color get accentMuted => body;
  static Color get brandActive => body;

  static Color get navGlass => canvas;
  static Color get navGlassBorder => hairline;
}
