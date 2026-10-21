import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Supabase Auth (GoTrue) behind the [AuthRepository] interface. The session is
/// kept and refreshed by the Supabase client; on the web it lives in the
/// browser's local storage.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  // Token refreshes emit the same user again; `distinct` hides them.
  @override
  Stream<AppUser?> get userChanges => _auth.onAuthStateChange
      .map((change) => _toUser(change.session?.user))
      .distinct();

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(response.user);
    } on Exception catch (error) {
      throw authFailureFrom(error);
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final name = fullName?.trim();
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // The database trigger copies this into the profile.
        data: {if (name != null && name.isNotEmpty) 'full_name': name},
      );
      // No session means the project wants the email confirmed first, which the
      // demo does not support.
      if (response.session == null) {
        throw const AuthFailure(AuthFailureReason.emailNotConfirmed);
      }
      return _requireUser(response.user);
    } on Exception catch (error) {
      throw authFailureFrom(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on Exception catch (error) {
      throw authFailureFrom(error);
    }
  }

  AppUser _requireUser(User? user) {
    final mapped = _toUser(user);
    if (mapped == null) {
      throw const AuthFailure(AuthFailureReason.unknown);
    }
    return mapped;
  }

  static AppUser? _toUser(User? user) {
    if (user == null) {
      return null;
    }
    final name = user.userMetadata?['full_name'];
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      fullName: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }
}

/// Turns whatever the Supabase client threw into the one error the UI knows.
/// Goes by the stable error `code` of the server, not by its message text.
AuthFailure authFailureFrom(Object error) {
  if (error is AuthFailure) {
    return error;
  }
  if (error is AuthWeakPasswordException) {
    return const AuthFailure(AuthFailureReason.weakPassword);
  }
  if (error is AuthRetryableFetchException) {
    return const AuthFailure(AuthFailureReason.network);
  }
  if (error is AuthException) {
    return AuthFailure(switch (error.code) {
      'invalid_credentials' => AuthFailureReason.invalidCredentials,
      'user_already_exists' || 'email_exists' => AuthFailureReason.emailTaken,
      'weak_password' => AuthFailureReason.weakPassword,
      'email_not_confirmed' => AuthFailureReason.emailNotConfirmed,
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' => AuthFailureReason.tooManyRequests,
      _ when error.statusCode == '429' => AuthFailureReason.tooManyRequests,
      _ => AuthFailureReason.unknown,
    });
  }
  // Not from the auth server: a socket, a timeout, a browser fetch error.
  return const AuthFailure(AuthFailureReason.network);
}
