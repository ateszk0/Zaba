import 'dart:async';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_rules.dart';

typedef InMemoryAccount = ({String email, String password, String? fullName});

/// The throw-away customer of the offline demo (no Supabase configured). Also
/// the account the tests sign in with.
const offlineDemoAccount = (
  email: 'demo@zaba.example',
  password: 'Demo-jelszo-1',
  fullName: 'Demó Dóra',
);

/// Accounts kept in memory, for the offline demo and for tests. Follows the
/// rules of the real server: addresses are unique regardless of case, and a
/// password needs [minPasswordLength] characters.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    Iterable<InMemoryAccount> accounts = const [],
    String? signedInAs,
  }) {
    for (final account in accounts) {
      _add(account);
    }
    if (signedInAs != null) {
      _current = _accounts[_key(signedInAs)]!.user;
    }
  }

  final _accounts = <String, _Account>{};
  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  static String _key(String email) => email.trim().toLowerCase();

  _Account _add(InMemoryAccount account) {
    final user = AppUser(
      id: 'user-${_accounts.length + 1}',
      email: _key(account.email),
      fullName: account.fullName,
    );
    return _accounts[user.email] = _Account(user, account.password);
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  void _setCurrent(AppUser? user) {
    _current = user;
    _changes.add(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final account = _accounts[_key(email)];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _setCurrent(account.user);
    return account.user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (password.length < minPasswordLength) {
      throw const AuthFailure(AuthFailureReason.weakPassword);
    }
    if (_accounts.containsKey(_key(email))) {
      throw const AuthFailure(AuthFailureReason.emailTaken);
    }
    final name = fullName?.trim();
    final account = _add((
      email: email,
      password: password,
      fullName: name == null || name.isEmpty ? null : name,
    ));
    _setCurrent(account.user);
    return account.user;
  }

  @override
  Future<void> signOut() async => _setCurrent(null);

  void dispose() => _changes.close();
}

class _Account {
  _Account(this.user, this.password);

  final AppUser user;
  final String password;
}
