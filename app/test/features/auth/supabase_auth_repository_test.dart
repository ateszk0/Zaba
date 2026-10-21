import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/auth/data/supabase_auth_repository.dart';
import 'package:zaba/features/auth/domain/auth_repository.dart';

void main() {
  group('authFailureFrom goes by the error code, not the message', () {
    AuthFailureReason reasonOf(Object error) => authFailureFrom(error).reason;

    test('credentials, duplicates, weak passwords', () {
      expect(
        reasonOf(
          const AuthApiException(
            'anything',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        AuthFailureReason.invalidCredentials,
      );
      for (final code in ['user_already_exists', 'email_exists']) {
        expect(
          reasonOf(AuthApiException('x', statusCode: '422', code: code)),
          AuthFailureReason.emailTaken,
          reason: code,
        );
      }
      expect(
        reasonOf(
          AuthWeakPasswordException(
            message: 'x',
            statusCode: '422',
            reasons: const ['length'],
          ),
        ),
        AuthFailureReason.weakPassword,
      );
      expect(
        reasonOf(
          const AuthApiException('x', statusCode: '422', code: 'weak_password'),
        ),
        AuthFailureReason.weakPassword,
      );
    });

    test('confirmation and rate limits', () {
      expect(
        reasonOf(
          const AuthApiException(
            'x',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
        ),
        AuthFailureReason.emailNotConfirmed,
      );
      expect(
        reasonOf(
          const AuthApiException(
            'x',
            statusCode: '429',
            code: 'over_request_rate_limit',
          ),
        ),
        AuthFailureReason.tooManyRequests,
      );
      // Older servers send the status but no code.
      expect(
        reasonOf(const AuthApiException('x', statusCode: '429')),
        AuthFailureReason.tooManyRequests,
      );
    });

    test('network trouble, including errors from outside the auth server', () {
      expect(
        reasonOf(AuthRetryableFetchException()),
        AuthFailureReason.network,
      );
      expect(reasonOf(Exception('Failed to fetch')), AuthFailureReason.network);
    });

    test('everything else is unknown, and an AuthFailure passes unchanged', () {
      expect(
        reasonOf(const AuthApiException('boom', statusCode: '500')),
        AuthFailureReason.unknown,
      );
      const failure = AuthFailure(AuthFailureReason.emailTaken);
      expect(authFailureFrom(failure), same(failure));
    });
  });
}
