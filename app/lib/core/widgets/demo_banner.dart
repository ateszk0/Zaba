import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Permanent strip above every screen so nobody mistakes the demo for the real
/// service. It owns the top safe area (notch / status bar), so the screens
/// below it must not add their own: see [DemoFrame].
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.label});

  /// The text; the customer app's demo notice when null.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.tomato600,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Center(
            child: Text(
              label ?? AppLocalizations.of(context).demoBanner,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the [DemoBanner] above the app and removes the top inset from the
/// content, because the banner already sits below the status bar.
class DemoFrame extends StatelessWidget {
  const DemoFrame({super.key, required this.child, this.label, this.below});

  final Widget child;
  final String? label;

  /// Shown between the banner and the app, for example a notification.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DemoBanner(label: label),
        ?below,
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
