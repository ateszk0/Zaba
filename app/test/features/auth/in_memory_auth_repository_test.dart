import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';
import 'package:zaba/features/auth/domain/auth_repository.dart';

Matcher failsWith(AuthFailureReason reason) =>
    throwsA(isA<AuthFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  late InMemoryAuthRepository auth;

  setUp(() {
    auth = InMemoryAuthRepository(accounts: [offlineDemoAccount]);
  });
  tearDown(() => auth.dispose());

  test('starts as a guest, or signed in when asked to', () {
    expect(auth.currentUser, isNull);
    final signedIn = InMemoryAuthRepository(
      accounts: [offlineDemoAccount],
      signedInAs: offlineDemoAccount.email,
    );
    expect(signedIn.currentUser?.fullName, offlineDemoAccount.fullName);
    signedIn.dispose();
  });

  test('signs in with the right password and announces the user', () async {
    final changes = <Object?>[];
    final subscription = auth.userChanges.listen(changes.add);

    final user = await auth.signIn(
      email: ' ${offlineDemoAccount.email.toUpperCase()} ',
      password: offlineDemoAccount.password,
    );
    await Future<void>.delayed(Duration.zero);

    expect(auth.currentUser, user);
    expect(changes, [user]);
    await subscription.cancel();
  });

  test('a wrong password or an unknown address is the same failure', () {
    expect(
      auth.signIn(email: offlineDemoAccount.email, password: 'wrong-pass'),
      failsWith(AuthFailureReason.invalidCredentials),
    );
    expect(
      auth.signIn(email: 'nobody@example.com', password: 'whatever-pass'),
      failsWith(AuthFailureReason.invalidCredentials),
    );
  });

  test('signUp creates the account, trims the name and signs in', () async {
    final user = await auth.signUp(
      email: 'Anna@Example.com',
      password: 'long-enough',
      fullName: '  Kovács Anna ',
    );

    expect(user.email, 'anna@example.com');
    expect(user.fullName, 'Kovács Anna');
    expect(auth.currentUser, user);

    await auth.signOut();
    expect(auth.currentUser, isNull);
    // The new account can sign in again.
    await auth.signIn(email: 'anna@example.com', password: 'long-enough');
    expect(auth.currentUser, user);
  });

  test('a blank name is stored as no name', () async {
    final user = await auth.signUp(
      email: 'b@example.com',
      password: 'long-enough',
      fullName: '   ',
    );
    expect(user.fullName, isNull);
    expect(user.displayName, 'b@example.com');
  });

  test('refuses a short password and a taken address', () {
    expect(
      auth.signUp(email: 'c@example.com', password: 'short'),
      failsWith(AuthFailureReason.weakPassword),
    );
    expect(
      auth.signUp(
        email: offlineDemoAccount.email.toUpperCase(),
        password: 'long-enough',
      ),
      failsWith(AuthFailureReason.emailTaken),
    );
  });
}
