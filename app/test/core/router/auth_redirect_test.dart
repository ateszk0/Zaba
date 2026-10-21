import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/router/app_router.dart';

String? redirect(String location, {required bool signedIn}) =>
    authRedirect(signedIn: signedIn, location: Uri.parse(location));

void main() {
  group('a guest', () {
    test('may browse', () {
      for (final path in ['/menu', '/cart', '/orders', '/profile', '/login']) {
        expect(redirect(path, signedIn: false), isNull, reason: path);
      }
    });

    test('is sent to the sign-in page from the ordering routes', () {
      expect(redirect('/checkout', signedIn: false), '/login?from=%2Fcheckout');
      expect(redirect('/pay/abc', signedIn: false), '/login?from=%2Fpay%2Fabc');
      expect(
        redirect('/orders/abc', signedIn: false),
        '/login?from=%2Forders%2Fabc',
      );
    });
  });

  group('a signed-in customer', () {
    test('is never blocked', () {
      for (final path in ['/menu', '/checkout', '/pay/abc', '/orders/abc']) {
        expect(redirect(path, signedIn: true), isNull, reason: path);
      }
    });

    test('leaves the sign-in pages for where they were heading', () {
      expect(redirect('/login?from=%2Fcheckout', signedIn: true), '/checkout');
      expect(redirect('/register', signedIn: true), '/profile');
    });

    test('ignores a return path that points outside the app', () {
      expect(
        redirect('/login?from=https%3A%2F%2Fevil.example', signedIn: true),
        '/profile',
      );
    });
  });
}
