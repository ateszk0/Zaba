import 'dart:ui';

/// The Zaba "salad" palette: leaf greens as the brand, tomato red as the accent
/// on warm cream. Contrast of the text pairs is enforced in
/// test/core/theme/app_colors_test.dart.
abstract final class AppColors {
  // Greens
  static const green900 = Color(0xFF1F4D2B);
  static const green700 = Color(0xFF2F7A3E);
  static const green500 = Color(0xFF4C9F50);
  static const green100 = Color(0xFFDCEFD9);
  static const green50 = Color(0xFFF0F8EE);

  // Tomato
  static const tomato700 = Color(0xFFA42F22);
  static const tomato600 = Color(0xFFD43F2F);
  static const tomato100 = Color(0xFFFBE0DC);

  // Neutrals
  static const cream = Color(0xFFFBF8F1);
  static const surface = Color(0xFFFFFFFF);
  // Decorative hairlines (dividers, card borders) vs. borders that carry meaning
  // (inputs), which need 3:1 non-text contrast.
  static const outline = Color(0xFFE3DED2);
  static const outlineStrong = Color(0xFF8A9488);
  static const ink = Color(0xFF1E2A21);
  static const inkMuted = Color(0xFF5E6B61);

  // Feedback
  static const error = Color(0xFFB3261E);
}
