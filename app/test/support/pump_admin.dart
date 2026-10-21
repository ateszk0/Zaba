import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/admin_app.dart';
import 'package:zaba/features/admin/application/admin_providers.dart';
import 'package:zaba/features/auth/application/auth_providers.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';

import 'fake_admin_repository.dart';

const staffAccount = (
  email: 'konyha@example.test',
  password: 'Konyha-jelszo-1',
  fullName: null,
);
const customerAccount = (
  email: 'vevo@example.test',
  password: 'Vevo-jelszo-1',
  fullName: null,
);

/// Pumps the admin page on a desktop-sized window (1280 x 800), or [width] x
/// [height] logical pixels, signed in as [signedInAs] if given.
Future<void> pumpAdmin(
  WidgetTester tester, {
  required FakeAdminRepository admin,
  String? signedInAs,
  double width = 1280,
  double height = 800,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          InMemoryAuthRepository(
            accounts: [staffAccount, customerAccount],
            signedInAs: signedInAs,
          ),
        ),
        adminRepositoryProvider.overrideWithValue(admin),
        ...overrides,
      ],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
}
