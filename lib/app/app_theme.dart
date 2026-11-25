import 'package:flutter/material.dart';

abstract final class AppColors {
  static const olive = Color(0xFF555F43);
  static const oliveSoft = Color(0xFFE7EBDD);
  static const sage = Color(0xFFC9D3BE);
  static const terracotta = Color(0xFFA45D46);
  static const slateBlue = Color(0xFF526B7A);
  static const ochre = Color(0xFF9A793F);
  static const plum = Color(0xFF796477);
  static const pourColors = [olive, terracotta, slateBlue, ochre, plum];
  static const ink = Color(0xFF272A24);
  static const muted = Color(0xFF62665E);
  static const background = Color(0xFFF5F2EA);
  static const surface = Color(0xFFFFFDFA);
  static const dark = ink;
  static const border = Color(0xFFD9D7CE);
  static const warning = Color(0xFFAD7838);
  static const error = Color(0xFFB6453A);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
}

abstract final class AppRadius {
  static const field = 10.0;
  static const card = 16.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  static const wordmark = TextStyle(
    fontFamily: 'serif',
    fontSize: 31,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const pageTitle = TextStyle(
    fontFamily: 'serif',
    fontSize: 31,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const coffeeName = TextStyle(
    fontFamily: 'serif',
    fontSize: 38,
    height: 1.08,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const sessionCoffeeName = TextStyle(
    fontFamily: 'serif',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const totalWater = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 52,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: AppColors.olive,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const stageTime = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.olive,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const timer = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 64,
    height: 1,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Plus Jakarta Sans',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.olive,
      onPrimary: AppColors.surface,
      secondary: AppColors.sage,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.error,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodySmall: TextStyle(fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.olive),
      ),
    ),
  );
}
