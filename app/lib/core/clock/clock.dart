import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Clock = DateTime Function();

/// The current time, as a provider so tests can pin it.
final clockProvider = Provider<Clock>((ref) => DateTime.now);
