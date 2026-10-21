import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';

/// The Zaba logo mark (the Z with the scooter) next to the name. The mark is a
/// picture drawn from app/assets/brand/zaba-mark.svg by tool/brand/make_icons.py
/// (1x, 2x and 3x), so it stays sharp at any size.
class ZabaWordmark extends StatelessWidget {
  const ZabaWordmark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final name = AppLocalizations.of(context).appTitle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decorative: the name next to it says the same.
        ExcludeSemantics(
          child: Image.asset(
            'assets/brand/logo_mark.png',
            height: size,
            filterQuality: FilterQuality.medium,
          ),
        ),
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
