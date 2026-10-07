import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF0A84FF);
  static const Color brandDark = Color(0xFF0066CC);
  static const Color brandLight = Color(0xFFEAF2FF);

  // ── Semantic Accent ───────────────────────────────────────────────────────
  static const Color workout = Color(0xFF3E9C5C);
  static const Color diet = Color(0xFFD98A3D);
  static const Color trainer = Color(0xFF8C7FC4);
  static const Color destructive = Color(0xFFE15361);

  // ── Background ────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFFF2F5F5);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color bgLogin = Color(0xFFEAF2FF);

  // ── Surface (Card / Container) ────────────────────────────────────────────
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardHover = Color(0xFFF8F8FA);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0x993C3C43);
  static const Color textTertiary = Color(0x663C3C43);
  static const Color textDisabled = Color(0x4D3C3C43);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textNeutral = Color(0xFF1C1C1E);

  // ── Border / Separator ────────────────────────────────────────────────────
  static const Color border = Color(0x1F3C3C43);
  static const Color borderFocus = Color(0xFF0A84FF);
  static const Color divider = Color(0x1F3C3C43);

  // ── Semantic Status ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFD60A);
  static const Color error = Color(0xFFFF453A);
  static const Color info = Color(0xFF0A84FF);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color statusPending = Color(0xFFFFD60A);
  static const Color statusApproved = Color(0xFF30D158);
  static const Color statusRejected = Color(0xFFFF453A);

  // ── Meal ──────────────────────────────────────────────────────────────────
  static const Color mealBreakfast = Color(0xFFE8A87C);
  static const Color mealLunch = Color(0xFF85C1AE);
  static const Color mealDinner = Color(0xFF7B9EC7);
  static const Color mealSnack = Color(0xFFB9A0C9);

  // ── Workout Category ──────────────────────────────────────────────────────
  static const Color categoryUpper = Color(0xFF0A84FF);
  static const Color categoryLower = Color(0xFF30D158);
  static const Color categoryCore = Color(0xFFFF9500);
  static const Color categoryCardio = Color(0xFFFF453A);

  // ── Nav ───────────────────────────────────────────────────────────────────
  static const Color navBg = Color(0xFFFFFFFF);
  static const Color navBorder = Color(0x1F3C3C43);

  // ═══════════════════════════════════════════════════════════════════════════
  // Legacy aliases — 기존 코드 호환. 점진적으로 위 토큰으로 교체.
  // ═══════════════════════════════════════════════════════════════════════════

  // dark surface* → Splash/Pending 화면 호환
  static const Color surface0 = Color(0xFF0D0D0D);
  static const Color surface1 = Color(0xFF161616);
  static const Color surface2 = Color(0xFF1F1F1F);
  static const Color surface3 = Color(0xFF2A2A2A);
  static const Color canvas = Color(0xFF000000);
  static const Color separator = Color(0xFF1F1F1F);
  static const Color separatorStrong = Color(0xFF2E2E2E);
  static const Color label = Color(0xFFFFFFFF);
  static const Color labelSecondary = Color(0xFF9A9A9A);
  static const Color labelTertiary = Color(0xFF5A5A5A);
  static const Color labelQuaternary = Color(0xFF383838);
  static const Color brandOrange = Color(0xFFFF6B35);
  static const Color brandDim = Color(0xFF3D1A0D);

  // further aliases
  static const Color primary = brand;
  static const Color primaryActive = brandDark;
  static const Color primaryDisabled = brandDim;
  static const Color background = bg;
  static const Color surface = card;
  static const Color surfaceCard = card;
  static const Color surfaceElevated = card;
  static const Color surfaceVariant = cardHover;
  static const Color surfaceSoft = bg;
  static const Color hairline = border;
  static const Color hairlineStrong = divider;
  static const Color onDark = label;
  static const Color onPrimary = textOnAccent;
  static const Color body = textSecondary;
  static const Color bodyStrong = Color(0xFFD0D0D0);
  static const Color muted = textSecondary;
  static const Color mutedSoft = textTertiary;
  static const Color accent = brand;
  static const Color accentMuted = textSecondary;
  static const Color brandActive = brandDark;

  // Nav glass (dark, for splash/pending)
  static const Color navGlass = Color(0xE6161616);
  static const Color navGlassBorder = Color(0xFF1F1F1F);
}
