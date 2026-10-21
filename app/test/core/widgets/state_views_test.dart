import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/theme/app_theme.dart';
import 'package:zaba/core/widgets/state_views.dart';
import 'package:zaba/l10n/generated/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('hu'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('LoadingView shows a spinner and the default Hungarian label', (
    tester,
  ) async {
    await tester.pumpWidget(host(const LoadingView()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Betöltés…'), findsOneWidget);
  });

  testWidgets(
    'ErrorView shows retry only when a callback is given and calls it',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(host(ErrorView(onRetry: () => retries++)));

      expect(find.text('Hoppá, valami elromlott'), findsOneWidget);
      await tester.tap(find.text('Újra'));
      expect(retries, 1);

      await tester.pumpWidget(host(const ErrorView()));
      expect(find.text('Újra'), findsNothing);
    },
  );

  testWidgets('EmptyView shows title, body and action', (tester) async {
    await tester.pumpWidget(
      host(
        EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Nincs találat',
          body: 'Próbálj másik keresőszót.',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Szűrők törlése'),
          ),
        ),
      ),
    );

    expect(find.text('Nincs találat'), findsOneWidget);
    expect(find.text('Próbálj másik keresőszót.'), findsOneWidget);
    expect(find.text('Szűrők törlése'), findsOneWidget);
  });

  testWidgets('state views do not overflow at 160% text scale', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: host(ErrorView(onRetry: () {})),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
