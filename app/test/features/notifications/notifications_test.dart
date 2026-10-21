import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/app.dart';
import 'package:zaba/features/auth/application/auth_providers.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';
import 'package:zaba/features/notifications/application/notification_providers.dart';
import 'package:zaba/features/notifications/domain/app_notification.dart';
import 'package:zaba/features/orders/application/order_providers.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import '../../support/checkout_steps.dart';
import '../../support/order_fixtures.dart';
import '../../support/pump_zaba.dart';

AppNotification note(String id, {OrderStatus status = OrderStatus.preparing}) =>
    AppNotification(
      id: id,
      orderId: 'order-1',
      orderNumber: 'ZB-1001',
      status: status,
      refunded: false,
      createdAt: fixedNow,
    );

void main() {
  group('statusChanges', () {
    test('the first load is not news', () {
      expect(statusChanges(null, [sampleOrder()]), isEmpty);
    });

    test('an unchanged order is not a change', () {
      expect(statusChanges([sampleOrder()], [sampleOrder()]), isEmpty);
    });

    test('a new status is a change, with the one it came from', () {
      final changes = statusChanges(
        [sampleOrder(status: OrderStatus.received)],
        [sampleOrder(status: OrderStatus.preparing)],
      );

      expect(changes, hasLength(1));
      expect(changes.single.order.status, OrderStatus.preparing);
      expect(changes.single.from, OrderStatus.received);
    });

    test('an order that appears for the first time is not a change', () {
      expect(
        statusChanges(
          [sampleOrder(id: 'old')],
          [
            sampleOrder(id: 'old'),
            sampleOrder(id: 'new', status: OrderStatus.pendingPayment),
          ],
        ),
        isEmpty,
      );
    });

    test(
      'each order is compared with itself, whatever the order of the list',
      () {
        final changes = statusChanges(
          [
            sampleOrder(id: 'a', status: OrderStatus.received),
            sampleOrder(id: 'b', status: OrderStatus.preparing),
          ],
          [
            sampleOrder(id: 'b', status: OrderStatus.outForDelivery),
            sampleOrder(id: 'a', status: OrderStatus.received),
          ],
        );

        expect(changes.map((c) => c.order.id), ['b']);
      },
    );
  });

  group('the notification state', () {
    late ProviderContainer container;
    NotificationsNotifier notifier() =>
        container.read(notificationsProvider.notifier);
    NotificationsState state() => container.read(notificationsProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('a notification is listed, unread and shown as the banner', () {
      notifier().add(note('1'));

      expect(state().items.map((n) => n.id), ['1']);
      expect(state().unread, 1);
      expect(state().banner?.id, '1');
    });

    test('the newest is first, and only the latest 30 are kept', () {
      for (var i = 0; i < 35; i++) {
        notifier().add(note('$i'));
      }

      expect(state().items, hasLength(30));
      expect(state().items.first.id, '34');
      expect(state().unread, 35);
    });

    test('dismissing the banner keeps the list and the unread count', () {
      notifier().add(note('1'));
      notifier().dismissBanner();

      expect(state().banner, isNull);
      expect(state().items, hasLength(1));
      expect(state().unread, 1);
    });

    test('reading clears the count and keeps the list', () {
      notifier().add(note('1'));
      notifier().markAllRead();

      expect(state().unread, 0);
      expect(state().items, hasLength(1));
    });

    test('a different person starts with nothing', () async {
      final auth = InMemoryAuthRepository(
        accounts: [offlineDemoAccount],
        signedInAs: offlineDemoAccount.email,
      );
      addTearDown(auth.dispose);
      container.dispose();
      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      container.listen(notificationsProvider, (_, _) {});
      container.read(sessionProvider);
      notifier().add(note('1'));
      expect(state().items, hasLength(1));

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(state().items, isEmpty);
      expect(state().unread, 0);
    });

    test('the in-app sender puts a notification into that state', () {
      container.read(notificationSenderProvider).send(note('1'));

      expect(state().items.single.id, '1');
    });
  });

  group('in the app', () {
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(ZabaApp)));

    Future<String> paidOrder(WidgetTester tester) async {
      await reachCheckout(tester);
      await placeOrder(tester);
      await fillCard(tester);
      await pay(tester);
      // The app itself follows the orders (to announce changes), so the list is
      // already there; asking the store for a stream would wait for events that
      // a widget test only delivers while it pumps.
      return containerOf(tester).read(ordersProvider).requireValue.single.id;
    }

    testWidgets(
      'the kitchen moving an order shows a banner, and a tap opens the order',
      (tester) async {
        final orderId = await paidOrder(tester);
        await tester.tap(navTab('Profil'));
        await tester.pumpAndSettle();
        // Paying already announced that the order was received; let that go.
        await tester.pump(const Duration(seconds: 8));
        expect(find.text('Készül a rendelésed'), findsNothing);

        await containerOf(tester)
            .read(orderAdminProvider)
            .setStatus(orderId, OrderStatus.preparing);
        await tester.pumpAndSettle();

        expect(find.text('Készül a rendelésed'), findsOneWidget);
        expect(
          find.textContaining('Elkezdtük elkészíteni az ételeidet.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Készül a rendelésed'));
        await tester.pumpAndSettle();
        // The banner is gone and the order's page is open.
        expect(find.text('Készül a rendelésed'), findsNothing);
        expect(find.textContaining('Rendelés ZB-'), findsWidgets);
      },
    );

    testWidgets('the banner goes away by itself', (tester) async {
      final orderId = await paidOrder(tester);
      await containerOf(tester)
          .read(orderAdminProvider)
          .setStatus(orderId, OrderStatus.preparing);
      await tester.pumpAndSettle();
      expect(find.text('Készül a rendelésed'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(find.text('Készül a rendelésed'), findsNothing);
    });

    testWidgets(
      'the list keeps them, the bell counts the unread ones and opening reads them',
      (tester) async {
        final orderId = await paidOrder(tester);
        final admin = containerOf(tester).read(orderAdminProvider);
        await admin.setStatus(orderId, OrderStatus.preparing);
        await admin.setStatus(orderId, OrderStatus.outForDelivery);
        await tester.pumpAndSettle();

        await tester.tap(navTab('Rendeléseim'));
        await tester.pumpAndSettle();
        // Let the banner go, so only the list shows each text once.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        // received (paid), preparing, out for delivery.
        expect(
          find.descendant(of: find.byType(Badge), matching: find.text('3')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Értesítések'));
        await tester.pumpAndSettle();

        expect(find.text('Megkaptuk a rendelésed'), findsOneWidget);
        expect(find.text('Készül a rendelésed'), findsOneWidget);
        expect(find.text('Úton a futár'), findsOneWidget);
        expect(find.textContaining('push értesítés nincs'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: find.byType(Badge), matching: find.text('3')),
          findsNothing,
        );
      },
    );

    testWidgets('a cancelled paid order says the money comes back', (
      tester,
    ) async {
      final orderId = await paidOrder(tester);
      await containerOf(tester)
          .read(orderRepositoryProvider)
          .cancelOrder(orderId);
      await tester.pumpAndSettle();

      await tester.tap(navTab('Rendeléseim'));
      await tester.pumpAndSettle();
      // Let the banner go, so only the list shows the text.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Értesítések'));
      await tester.pumpAndSettle();

      expect(find.text('A rendelésed lemondva'), findsOneWidget);
      expect(find.textContaining('visszatérítjük'), findsOneWidget);
    });

    testWidgets('with no notifications the screen says so', (tester) async {
      await pumpZaba(tester);
      await tester.tap(navTab('Rendeléseim'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Értesítések'));
      await tester.pumpAndSettle();

      expect(find.text('Még nincs értesítésed'), findsOneWidget);
    });

    testWidgets('a guest has no bell and gets no banner', (tester) async {
      await pumpZaba(tester, signedIn: false);
      await tester.tap(navTab('Rendeléseim'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Értesítések'), findsNothing);
    });
  });
}
