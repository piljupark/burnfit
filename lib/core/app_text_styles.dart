import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Pretendard';

  static TextStyle _base({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.5,
    double letterSpacing = -0.1,
  }) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle get display => _base(
    size: 36,
    weight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -1.2,
  );

  // ── Heading ───────────────────────────────────────────────────────────────
  static TextStyle get h1 => _base(
    size: 26,
    weight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
  );

  static TextStyle get h2 => _base(
    size: 22,
    weight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => _base(
    size: 18,
    weight: FontWeight.w700,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static TextStyle get h4 => _base(
    size: 16,
    weight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.1,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get headline => _base(
    size: 17,
    weight: FontWeight.w600,
    height: 1.45,
    letterSpacing: -0.1,
  );

  static TextStyle get body => _base(
    size: 15,
    weight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
    letterSpacing: -0.1,
  );

  static TextStyle get bodyLarge => _base(
    size: 17,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
    letterSpacing: -0.1,
  );

  static TextStyle get bodySmall => _base(
    size: 14,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
    letterSpacing: -0.1,
  );

  // ── Supporting ────────────────────────────────────────────────────────────
  static TextStyle get callout => _base(
    size: 16,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static TextStyle get caption => _base(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0,
  );

  static TextStyle get captionSmall => _base(
    size: 11,
    weight: FontWeight.w500,
    color: AppColors.textTertiary,
    height: 1.4,
    letterSpacing: 0,
  );

  static TextStyle get label => _base(
    size: 13,
    weight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0,
  );

  static TextStyle get labelSmall => _base(
    size: 11,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0,
  );

  static TextStyle get overline => _base(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.textTertiary,
    height: 1.3,
    letterSpacing: 1.0,
  );

  static TextStyle get button => _base(
    size: 16,
    weight: FontWeight.w600,
    color: AppColors.textOnAccent,
    height: 1.0,
    letterSpacing: -0.1,
  );

  // ── Numeric ───────────────────────────────────────────────────────────────
  static TextStyle get stat => _base(
    size: 48,
    weight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.0,
    letterSpacing: -2.0,
  );

  static TextStyle get numberLarge => _base(
    size: 32,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -1.0,
  );
}
