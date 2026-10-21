import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Fonts are bundled in the app package (assets/fonts), never fetched from an
/// external host. Do not use emoji in UI copy: they would force the engine to
/// download a fallback font.
abstract final class AppFonts {
  static const heading = 'Baloo2';
  static const body = 'Inter';
  static const fallback = ['Arial', 'Helvetica', 'sans-serif'];
}

abstract final class AppTypography {
  /// Tabular figures keep prices aligned in lists and the cart summary.
  static const priceFeatures = [FontFeature.tabularFigures()];

  // Keep text inside inputs at 16 px or more: iOS Safari zooms the page when a
  // smaller input gets focus.
  static TextTheme textTheme() {
    TextStyle heading(double size, FontWeight weight, {double height = 1.2}) =>
        TextStyle(
          fontFamily: AppFonts.heading,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: AppColors.ink,
        );

    TextStyle body(
      double size,
      FontWeight weight, {
      double height = 1.45,
      Color? color,
    }) => TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? AppColors.ink,
    );

    return TextTheme(
      displayLarge: heading(48, FontWeight.w800, height: 1.1),
      displayMedium: heading(40, FontWeight.w800, height: 1.1),
      displaySmall: heading(34, FontWeight.w700, height: 1.15),
      headlineLarge: heading(30, FontWeight.w800, height: 1.15),
      headlineMedium: heading(26, FontWeight.w700),
      headlineSmall: heading(22, FontWeight.w700),
      titleLarge: heading(20, FontWeight.w700),
      titleMedium: body(16, FontWeight.w600, height: 1.35),
      titleSmall: body(14, FontWeight.w600, height: 1.35),
      bodyLarge: body(16, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, color: AppColors.inkMuted),
      labelLarge: body(15, FontWeight.w600, height: 1.2),
      labelMedium: body(12.5, FontWeight.w600, height: 1.2),
      labelSmall: body(
        11,
        FontWeight.w600,
        height: 1.2,
        color: AppColors.inkMuted,
      ),
    );
  }
}
