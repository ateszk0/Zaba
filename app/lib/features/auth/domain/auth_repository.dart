import 'app_user.dart';

enum AuthFailureReason {
  invalidCredentials,
  emailTaken,
  weakPassword,
  emailNotConfirmed,
  tooManyRequests,
  network,
  unknown,
}

/// The only error the auth screens have to handle. It carries a reason, never
/// the server's own message, so nothing technical reaches the user.
class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure($reason)';
}

/// Email and password accounts. The session itself (token, refresh) is the
/// implementation's business.
abstract interface class AuthRepository {
  /// The user of the stored session, if any.
  AppUser? get currentUser;

  /// Emits when somebody signs in or out, or the account data changes. Does not
  /// repeat the current user on subscription: read [currentUser] for that.
  Stream<AppUser?> get userChanges;

  /// Throws [AuthFailure].
  Future<AppUser> signIn({required String email, required String password});

  /// Creates the account and signs in. Throws [AuthFailure].
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  Future<void> signOut();
}
