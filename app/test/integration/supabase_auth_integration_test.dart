@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/auth/data/supabase_auth_repository.dart';
import 'package:zaba/features/auth/domain/auth_repository.dart';

import 'integration_env.dart';

// Runs the real [SupabaseAuthRepository] against a real Supabase (see
// integration_env.dart for how to start it and pass the values).

Matcher failsWith(AuthFailureReason reason) =>
    throwsA(isA<AuthFailure>().having((f) => f.reason, 'reason', reason));

String newEmail(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@example.test';

void main() {
  late SupabaseClient client;
  late SupabaseAuthRepository auth;

  setUpAll(() {
    // flutter_test answers every HTTP request with an error; this test needs the
    // real network.
    HttpOverrides.global = null;
  });

  setUp(() {
    client = newIntegrationClient();
    auth = SupabaseAuthRepository(client.auth);
  });
  tearDown(() => client.dispose());

  group('against a real Supabase', () {
    test('sign-up signs in, keeps the name and creates the profile', () async {
      final email = newEmail('signup');
      final changes = <Object?>[];
      final subscription = auth.userChanges.listen(changes.add);

      final user = await auth.signUp(
        email: email,
        password: 'hosszu-jelszo-1',
        fullName: '  Kovács Anna ',
      );

      expect(user.email, email);
      expect(user.fullName, 'Kovács Anna');
      expect(auth.currentUser, user);

      // The database trigger made the profile, and row level security lets the
      // owner read it.
      final profiles = await client.from('profiles').select('id, full_name');
      expect(profiles, [
        {'id': user.id, 'full_name': 'Kovács Anna'},
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(changes, contains(user));
      await subscription.cancel();
    });

    test(
      'sign-out closes the session, and a guest cannot read profiles',
      () async {
        final email = newEmail('signout');
        await auth.signUp(email: email, password: 'hosszu-jelszo-1');
        await auth.signOut();

        expect(auth.currentUser, isNull);
        // A guest has no access to profiles at all (permission denied).
        await expectLater(
          client.from('profiles').select('id'),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );

        final again = await auth.signIn(
          email: email,
          password: 'hosszu-jelszo-1',
        );
        expect(again.email, email);
        expect(again.fullName, isNull);
      },
    );

    test('the failures arrive as the reasons the screens know', () async {
      final email = newEmail('failures');
      await auth.signUp(email: email, password: 'hosszu-jelszo-1');
      await auth.signOut();

      await expectLater(
        auth.signIn(email: email, password: 'rossz-jelszo-1'),
        failsWith(AuthFailureReason.invalidCredentials),
      );
      await expectLater(
        auth.signIn(email: newEmail('nobody'), password: 'hosszu-jelszo-1'),
        failsWith(AuthFailureReason.invalidCredentials),
      );
      await expectLater(
        auth.signUp(email: email, password: 'hosszu-jelszo-1'),
        failsWith(AuthFailureReason.emailTaken),
      );
      await expectLater(
        auth.signUp(email: newEmail('weak'), password: 'rovid'),
        failsWith(AuthFailureReason.weakPassword),
      );
    });

    test('a name that is far too long does not break the sign-up', () async {
      final user = await auth.signUp(
        email: newEmail('longname'),
        password: 'hosszu-jelszo-1',
        fullName: 'x' * 300,
      );
      final profiles = await client.from('profiles').select('full_name');
      expect((profiles.single['full_name'] as String).length, 200);
      expect(user.fullName, hasLength(300));
    });

    test('an unreachable server is a network failure', () async {
      final offline = SupabaseAuthRepository(
        newIntegrationClient('http://127.0.0.1:9').auth,
      );
      await expectLater(
        offline.signIn(email: 'a@example.test', password: 'hosszu-jelszo-1'),
        failsWith(AuthFailureReason.network),
      );
    });
  }, skip: integrationSkip);
}
