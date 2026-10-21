import 'package:flutter/material.dart';

/// Puts [below] (the notification strip) above the app. The strip is empty most
/// of the time; while it shows, it sits under the status bar.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child, this.below});

  final Widget child;

  /// Shown above the app, for example a notification.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?below,
        Expanded(child: child),
      ],
    );
  }
}
