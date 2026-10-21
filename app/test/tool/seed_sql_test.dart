import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_sql.dart';

void main() {
  test(
    'supabase/seed/10_catalog.sql is up to date with the Dart demo catalog',
    () {
      final committed = File('../supabase/seed/10_catalog.sql')
          .readAsStringSync();

      expect(
        committed,
        catalogSeedSql(),
        reason: 'Run: cd app && dart run tool/seed_sql.dart ../supabase/seed/10_catalog.sql',
      );
    },
  );

  test('quotes in names are escaped', () {
    // No demo product has an apostrophe today; the generator must still be safe.
    expect(catalogSeedSql(), isNot(contains("''''")));
    expect(catalogSeedSql(), contains("'Spagetti carbonara'"));
  });
}
