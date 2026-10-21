import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.green700,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.green100,
      onPrimaryContainer: AppColors.green900,
      secondary: AppColors.tomato600,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.tomato100,
      onSecondaryContainer: AppColors.tomato700,
      error: AppColors.error,
      onError: AppColors.surface,
      errorContainer: AppColors.tomato100,
      onErrorContainer: AppColors.tomato700,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.outlineStrong,
      outlineVariant: AppColors.outline,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.textTheme();
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.cream,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: AppColors.green700,
          side: const BorderSide(color: AppColors.outlineStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: AppColors.green700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.green700,
        ),
        border: inputBorder(AppColors.outlineStrong),
        enabledBorder: inputBorder(AppColors.outlineStrong),
        focusedBorder: inputBorder(AppColors.green700, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.outline),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.green100,
        checkmarkColor: AppColors.green900,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.green100,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.green900
                : AppColors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.green900
                : AppColors.inkMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green700,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: const BorderSide(color: AppColors.outlineStrong),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.inkMuted,
          selectedBackgroundColor: AppColors.green100,
          selectedForegroundColor: AppColors.green900,
          side: const BorderSide(color: AppColors.outlineStrong),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.outlineStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.tomato600,
        textColor: AppColors.surface,
      ),
    );
  }
}
