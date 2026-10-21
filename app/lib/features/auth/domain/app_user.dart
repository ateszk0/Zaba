import 'package:flutter/foundation.dart';

/// The signed-in customer, as far as the UI needs to know.
@immutable
class AppUser {
  const AppUser({required this.id, required this.email, this.fullName});

  final String id;
  final String email;
  final String? fullName;

  /// What to call the person on screen.
  String get displayName => fullName ?? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName;

  @override
  int get hashCode => Object.hash(id, email, fullName);
}
