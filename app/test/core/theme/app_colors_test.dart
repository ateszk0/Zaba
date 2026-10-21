import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/theme/app_colors.dart';

/// WCAG 2.x contrast ratio between two colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // Normal text needs 4.5:1 (WCAG AA); the body ink on its backgrounds is held
  // to the stricter 7:1 (AAA). Borders that carry meaning need 3:1 (non-text).
  group('palette meets WCAG contrast', () {
    final pairs = <String, (Color, Color, double)>{
      'input border on surface': (
        AppColors.outlineStrong,
        AppColors.surface,
        3.0,
      ),
      'ink on cream': (AppColors.ink, AppColors.cream, 7.0),
      'ink on surface': (AppColors.ink, AppColors.surface, 7.0),
      'muted ink on cream': (AppColors.inkMuted, AppColors.cream, 4.5),
      'muted ink on surface': (AppColors.inkMuted, AppColors.surface, 4.5),
      'white on primary green': (AppColors.surface, AppColors.green700, 4.5),
      'green text on cream': (AppColors.green700, AppColors.cream, 4.5),
      'dark green on light green': (
        AppColors.green900,
        AppColors.green100,
        7.0,
      ),
      'white on tomato accent': (AppColors.surface, AppColors.tomato600, 4.5),
      'dark tomato on light tomato': (
        AppColors.tomato700,
        AppColors.tomato100,
        4.5,
      ),
      'white on error': (AppColors.surface, AppColors.error, 4.5),
    };

    pairs.forEach((name, pair) {
      final (foreground, background, minimum) = pair;
      test(name, () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(minimum));
      });
    });
  });
}
