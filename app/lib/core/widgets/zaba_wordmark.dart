import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Placeholder brand mark: a green disc with a "Z" next to the name.
/// The real logo (smiling face, bowl mouth) is drawn at the very end of the
/// demo build; replace the contents of [_PlaceholderMark] then.
class ZabaWordmark extends StatelessWidget {
  const ZabaWordmark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final name = AppLocalizations.of(context).appTitle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlaceholderMark(size: size),
        SizedBox(width: size * 0.3),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppColors.green900, fontSize: size * 0.8),
        ),
      ],
    );
  }
}

class _PlaceholderMark extends StatelessWidget {
  const _PlaceholderMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.green700,
          shape: BoxShape.circle,
        ),
        child: Text(
          'Z',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.62,
            height: 1,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}
