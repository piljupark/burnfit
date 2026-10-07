import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Galloway 테마 (지금 [AppColors.palette]로 만든다 — 다크·라이트 공통 구조). 그림자·elevation 없음, 모서리는 0 / 8 / pill.
class AppTheme {
  AppTheme._();

  static const _font = AppTextStyles.sans;

  static ThemeData get current {
    final light = AppColors.isLight;
    final pill = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());
    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      fontFamily: _font,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.canvasSoft,
      colorScheme: (light ? ColorScheme.light : ColorScheme.dark)(
        surface: AppColors.canvas,
        surfaceContainer: AppColors.canvasCard,
        surfaceContainerHigh: AppColors.canvasCard,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.body,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.body,
        outline: AppColors.outline,
        outlineVariant: AppColors.hairline,
        error: AppColors.danger,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLg,
        displayMedium: AppTextStyles.displayMd,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.bodyLg,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodyMd,
        bodySmall: AppTextStyles.bodySm,
        labelLarge: AppTextStyles.buttonLabel,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: AppSize.appBar,
        shape: Border(bottom: BorderSide(color: AppColors.hairline)),
        systemOverlayStyle: overlayStyle,
        titleTextStyle: AppTextStyles.title,
        iconTheme: IconThemeData(color: AppColors.ink, size: AppSize.icon),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvasSoft,
        border: _inputBorder(AppColors.hairline),
        enabledBorder: _inputBorder(AppColors.hairline),
        focusedBorder: _inputBorder(AppColors.ink),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger),
        disabledBorder: _inputBorder(AppColors.hairline),
        labelStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
        hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
        errorStyle: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: 13,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.canvasMid,
        selectionHandleColor: AppColors.ink,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.primary),
          foregroundColor: WidgetStatePropertyAll(AppColors.onPrimary),
          elevation: const WidgetStatePropertyAll(0),
          shape: pill,
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSize.buttonHeight),
          ),
          textStyle: WidgetStatePropertyAll(AppTextStyles.buttonLabel),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.primary),
          foregroundColor: WidgetStatePropertyAll(AppColors.onPrimary),
          shape: pill,
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSize.buttonHeight),
          ),
          textStyle: WidgetStatePropertyAll(AppTextStyles.buttonLabel),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.ink),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
          shape: pill,
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSize.buttonHeight),
          ),
          textStyle: WidgetStatePropertyAll(AppTextStyles.buttonLabel),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.ink),
          shape: pill,
          textStyle: WidgetStatePropertyAll(AppTextStyles.buttonLabel),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.ink),
          minimumSize: WidgetStatePropertyAll(
            Size(AppSize.touchMin, AppSize.touchMin),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.canvasCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.canvasCard,
        elevation: 0,
        barrierColor: AppColors.backdrop,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: AppTextStyles.title,
        contentTextStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.canvasCard,
        modalBackgroundColor: AppColors.canvasCard,
        modalBarrierColor: AppColors.backdrop,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.canvasMid,
        circularTrackColor: AppColors.canvasMid,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.mute,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.canvasSoft,
        ),
        trackOutlineColor: WidgetStatePropertyAll(AppColors.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(AppColors.onPrimary),
        side: BorderSide(color: AppColors.outline, width: 1.5),
        shape: const CircleBorder(),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.canvasCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        headerForegroundColor: AppColors.ink,
        todayBorder: BorderSide(color: AppColors.outline),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.canvasCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.ink, size: AppSize.icon),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.canvasCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        textStyle: AppTextStyles.bodyMd,
      ),
    );
  }

  /// 상태 표시줄 글자 색: 다크 캔버스면 흰 글자, 라이트면 검은 글자.
  static SystemUiOverlayStyle get overlayStyle => AppColors.isLight
      ? SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.canvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        )
      : SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.canvas,
          systemNavigationBarIconBrightness: Brightness.light,
        );

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderSide: BorderSide(color: color),
    borderRadius: BorderRadius.circular(AppRadius.card),
  );
}
