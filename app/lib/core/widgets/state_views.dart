import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The three states every screen has besides its content: loading, error and
/// empty. Screens use these instead of improvising their own.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? AppLocalizations.of(context).commonLoading;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.title, this.body, this.onRetry});

  final String? title;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StateLayout(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.tomato700,
      iconBackground: AppColors.tomato100,
      title: title ?? l10n.commonErrorTitle,
      body: body ?? l10n.commonErrorBody,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
            ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: icon,
      iconColor: AppColors.green700,
      iconBackground: AppColors.green100,
      title: title,
      body: body,
      action: action,
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: iconColor),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
