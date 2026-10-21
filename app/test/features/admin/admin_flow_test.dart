import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaba/features/admin/domain/staff.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import '../../support/fake_admin_repository.dart';
import '../../support/order_fixtures.dart';
import '../../support/pump_admin.dart';

DeliverySlot slotAt(int hour) => DeliverySlot(
  id: 'slot-$hour',
  start: DateTime(2026, 10, 21, hour),
  end: DateTime(2026, 10, 21, hour + 1),
);

Order order(
  String id,
  String number,
  OrderStatus status,
  int hour, {
  PaymentStatus? payment,
  String note = '',
}) => sampleOrder(
  id: id,
  number: number,
  status: status,
  slot: slotAt(hour),
  note: note,
  paymentStatus:
      payment ??
      (status == OrderStatus.pendingPayment
          ? PaymentStatus.pending
          : PaymentStatus.succeeded),
);

FakeAdminRepository kitchen({StaffRole? role = StaffRole.operator}) =>
    FakeAdminRepository(
      role: role,
      orders: [
        order(
          'a',
          'ZB-1001',
          OrderStatus.received,
          12,
          note: 'Csengess kétszer.',
        ),
        order('b', 'ZB-1002', OrderStatus.preparing, 13),
        order('c', 'ZB-1003', OrderStatus.pendingPayment, 14),
        order('d', 'ZB-1004', OrderStatus.delivered, 11),
      ],
    );

Finder tile(String number) => find.widgetWithText(Card, number);

void main() {
  group('signing in', () {
    testWidgets(
      'a guest sees the staff sign-in, and a wrong password is refused',
      (tester) async {
        await pumpAdmin(tester, admin: kitchen());

        expect(find.text('Munkatársi belépés'), findsOneWidget);
        expect(
          find.text('DEMÓ · kezelőfelület · kitalált adatok'),
          findsOneWidget,
        );
        // No registration and no demo button unless the build has one.
        expect(find.textContaining('Regisztr'), findsNothing);
        expect(find.text('Belépés demó munkatársként'), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail-cím'),
          staffAccount.email,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Jelszó'),
          'rossz-jelszo-1',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Belépés'));
        await tester.pumpAndSettle();

        expect(find.text('Hibás e-mail-cím vagy jelszó.'), findsOneWidget);
        expect(find.text('Rendelések'), findsNothing);
      },
    );

    testWidgets('a staff member signs in and sees the orders', (tester) async {
      await pumpAdmin(tester, admin: kitchen());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail-cím'),
        staffAccount.email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jelszó'),
        staffAccount.password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Belépés'));
      await tester.pumpAndSettle();

      expect(find.text('Rendelések'), findsOneWidget);
      expect(tile('ZB-1001'), findsOneWidget);
    });

    testWidgets(
      'a customer who signs in is told there is no access, and can sign out',
      (tester) async {
        await pumpAdmin(
          tester,
          admin: kitchen(role: null),
          signedInAs: customerAccount.email,
        );

        expect(find.text('Nincs jogosultságod'), findsOneWidget);
        expect(tile('ZB-1001'), findsNothing);

        await tester.tap(find.text('Kijelentkezés'));
        await tester.pumpAndSettle();
        expect(find.text('Munkatársi belépés'), findsOneWidget);
      },
    );

    testWidgets('signing out leads back to the sign-in', (tester) async {
      await pumpAdmin(tester, admin: kitchen(), signedInAs: staffAccount.email);

      await tester.tap(find.byTooltip('Kijelentkezés'));
      await tester.pumpAndSettle();

      expect(find.text('Munkatársi belépés'), findsOneWidget);
    });
  });

  group('the order list', () {
    testWidgets(
      'shows the active orders by delivery window, and the filters switch the set',
      (tester) async {
        await pumpAdmin(
          tester,
          admin: kitchen(),
          signedInAs: staffAccount.email,
        );

        expect(tile('ZB-1001'), findsOneWidget);
        expect(tile('ZB-1002'), findsOneWidget);
        expect(tile('ZB-1003'), findsNothing);
        expect(tile('ZB-1004'), findsNothing);
        expect(
          tester.getTopLeft(tile('ZB-1001')).dy,
          lessThan(tester.getTopLeft(tile('ZB-1002')).dy),
          reason: 'the earlier delivery window is first',
        );

        await tester.tap(find.widgetWithText(ChoiceChip, 'Fizetésre vár'));
        await tester.pumpAndSettle();
        expect(tile('ZB-1003'), findsOneWidget);
        expect(tile('ZB-1001'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Lezárt'));
        await tester.pumpAndSettle();
        expect(tile('ZB-1004'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Mind'));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsNWidgets(4));
      },
    );

    testWidgets('a new order appears without reloading', (tester) async {
      final admin = kitchen();
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      expect(tile('ZB-1010'), findsNothing);

      admin.put(order('n', 'ZB-1010', OrderStatus.received, 15));
      await tester.pumpAndSettle();

      expect(tile('ZB-1010'), findsOneWidget);
    });

    testWidgets('an empty set says so', (tester) async {
      await pumpAdmin(
        tester,
        admin: FakeAdminRepository(),
        signedInAs: staffAccount.email,
      );

      expect(find.text('Nincs ilyen rendelés'), findsOneWidget);
    });

    testWidgets('the role is shown, and an operator has no audit log button', (
      tester,
    ) async {
      await pumpAdmin(tester, admin: kitchen(), signedInAs: staffAccount.email);

      expect(find.text('Konyha'), findsOneWidget);
      expect(find.byTooltip('Naplózott műveletek'), findsNothing);
    });
  });

  group('one order', () {
    testWidgets(
      'on a wide screen the order opens next to the list, with what to do next',
      (tester) async {
        await pumpAdmin(
          tester,
          admin: kitchen(),
          signedInAs: staffAccount.email,
        );

        await tester.tap(tile('ZB-1001'));
        await tester.pumpAndSettle();

        // The list is still there.
        expect(tile('ZB-1002'), findsOneWidget);
        expect(find.text('Készítés megkezdése'), findsOneWidget);
        expect(find.text('Rendelés lemondása'), findsOneWidget);
        expect(find.text('2 × Spagetti carbonara'), findsOneWidget);
        expect(find.text('Csengess kétszer.'), findsOneWidget);
        expect(find.textContaining('Váci utca 12.'), findsOneWidget);
      },
    );

    testWidgets('on a phone-sized screen the order is a page with a way back', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        admin: kitchen(),
        signedInAs: staffAccount.email,
        width: 420,
        height: 800,
      );

      await tester.tap(tile('ZB-1001'));
      await tester.pumpAndSettle();
      expect(tile('ZB-1002'), findsNothing);
      expect(find.text('Készítés megkezdése'), findsOneWidget);

      await tester.tap(find.byTooltip('Vissza a rendelésekhez'));
      await tester.pumpAndSettle();
      expect(tile('ZB-1002'), findsOneWidget);
    });

    testWidgets(
      'the buttons are the moves the state machine allows from the status',
      (tester) async {
        await pumpAdmin(
          tester,
          admin: kitchen(),
          signedInAs: staffAccount.email,
        );

        await tester.tap(tile('ZB-1002'));
        await tester.pumpAndSettle();
        expect(find.text('Kiszállítás indítása'), findsOneWidget);
        expect(find.text('Készítés megkezdése'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Lezárt'));
        await tester.pumpAndSettle();
        await tester.tap(tile('ZB-1004'));
        await tester.pumpAndSettle();
        expect(
          find.text('Ezen a rendelésen már nincs további teendő.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'moving an order along changes it on screen and writes history',
      (tester) async {
        final admin = kitchen();
        await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
        await tester.tap(tile('ZB-1001'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Készítés megkezdése'));
        await tester.pumpAndSettle();

        expect(admin.setStatusCalls, [('a', OrderStatus.preparing)]);
        expect(find.text('Kiszállítás indítása'), findsOneWidget);
        expect(find.text('Készítés megkezdése'), findsNothing);
        // The history names the kitchen as the one who did it.
        expect(find.text('konyha'), findsOneWidget);
      },
    );

    testWidgets('an unpaid order can only be cancelled, and says why', (
      tester,
    ) async {
      await pumpAdmin(tester, admin: kitchen(), signedInAs: staffAccount.email);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fizetésre vár'));
      await tester.pumpAndSettle();

      await tester.tap(tile('ZB-1003'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'fizetésre vár: a konyha a fizetés után kezdheti el',
        ),
        findsOneWidget,
      );
      expect(find.text('Rendelés lemondása'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'cancelling asks first, and mentions the refund of a paid order',
      (tester) async {
        final admin = kitchen();
        await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
        await tester.tap(tile('ZB-1001'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rendelés lemondása'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'A vásárló kifizette, ezért a fizetés visszatérítésre kerül.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Mégsem'));
        await tester.pumpAndSettle();
        expect(
          admin.setStatusCalls,
          isEmpty,
          reason: 'nothing happens without the confirmation',
        );

        await tester.tap(find.text('Rendelés lemondása'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lemondom'));
        await tester.pumpAndSettle();

        expect(admin.setStatusCalls, [('a', OrderStatus.cancelled)]);
        expect(
          find.text('Ezen a rendelésen már nincs további teendő.'),
          findsOneWidget,
        );
        expect(find.text('Visszatérítve'), findsWidgets);
      },
    );

    testWidgets('a refused move says so instead of failing silently', (
      tester,
    ) async {
      final admin = kitchen()
        ..failNextMove = const InvalidOrderTransitionException(
          OrderStatus.received,
          OrderStatus.preparing,
        );
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      await tester.tap(tile('ZB-1001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Készítés megkezdése'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nem engedélyezett'), findsOneWidget);
    });

    testWidgets('a backend failure says so, and the buttons work again', (
      tester,
    ) async {
      final admin = kitchen()..failNextMove = Exception('offline');
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      await tester.tap(tile('ZB-1001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Készítés megkezdése'));
      await tester.pumpAndSettle();
      expect(
        find.text('A művelet nem sikerült. Próbáld újra.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Készítés megkezdése'));
      await tester.pumpAndSettle();
      expect(admin.setStatusCalls, hasLength(2));
      expect(find.text('Kiszállítás indítása'), findsOneWidget);
    });
  });

  group('an answer the page cannot read', () {
    testWidgets('is reported like any other failure', (tester) async {
      final admin = kitchen()..failNextMove = TypeError();
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      await tester.tap(tile('ZB-1001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Készítés megkezdése'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('A művelet nem sikerült. Próbáld újra.'),
        findsOneWidget,
      );
    });
  });

  group('the audit log', () {
    testWidgets('an administrator reads what the staff did', (tester) async {
      final admin = kitchen(role: StaffRole.admin);
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      expect(find.text('Admin'), findsOneWidget);

      await tester.tap(tile('ZB-1001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Készítés megkezdése'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Naplózott műveletek'));
      await tester.pumpAndSettle();

      expect(
        find.text('Állapotváltás: Rendelés fogadva → Készül'),
        findsOneWidget,
      );
    });

    testWidgets('an operator who types the address gets no access', (
      tester,
    ) async {
      final admin = kitchen();
      await pumpAdmin(tester, admin: admin, signedInAs: staffAccount.email);
      // The operator has no button for it; go there directly.
      GoRouter.of(tester.element(find.text('Rendelések').first)).go('/audit');
      await tester.pumpAndSettle();

      expect(find.text('Nincs jogosultságod'), findsOneWidget);
    });
  });
}
