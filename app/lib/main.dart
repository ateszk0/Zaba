import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/storage/preferences.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/cart/application/cart_providers.dart';
import 'features/cart/data/shared_preferences_cart_store.dart';
import 'features/cart/data/supabase_quote_service.dart';
import 'features/catalog/application/catalog_providers.dart';
import 'features/catalog/data/supabase_catalog_repository.dart';
import 'features/delivery/application/delivery_providers.dart';
import 'features/delivery/data/supabase_delivery_slot_service.dart';
import 'features/delivery/data/supabase_delivery_zone_repository.dart';
import 'features/orders/application/order_providers.dart';
import 'features/orders/data/supabase_order_repository.dart';
import 'features/payment/application/payment_providers.dart';
import 'features/payment/data/supabase_payment_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await openPreferences();
  final overrides = <Override>[
    if (preferences != null)
      cartStoreProvider.overrideWithValue(
        SharedPreferencesCartStore(preferences),
      ),
  ];
  if (AppConfig.hasBackend) {
    final client = await initSupabase(persistSession: preferences != null);
    overrides.addAll([
      authRepositoryProvider.overrideWith(
        (ref) => SupabaseAuthRepository(client.auth),
      ),
      catalogRepositoryProvider.overrideWith(
        (ref) => SupabaseCatalogRepository(client),
      ),
      quoteServiceProvider.overrideWith(
        (ref) => SupabaseQuoteService(
          client,
          loadProducts: () => ref.read(productsProvider.future),
        ),
      ),
      deliveryZoneRepositoryProvider.overrideWith(
        (ref) => SupabaseDeliveryZoneRepository(client),
      ),
      deliverySlotServiceProvider.overrideWith(
        (ref) => SupabaseDeliverySlotService(client),
      ),
      orderRepositoryProvider.overrideWith(
        (ref) => SupabaseOrderRepository(client),
      ),
      paymentServiceProvider.overrideWith(
        (ref) => SupabasePaymentService(
          client,
          orders: ref.watch(orderRepositoryProvider),
          processingDelay: ref.watch(paymentProcessingDelayProvider),
        ),
      ),
      // The kitchen is the admin page now, not a button in the customer app.
      kitchenSimulationProvider.overrideWithValue(false),
    ]);
  }

  runApp(ProviderScope(overrides: overrides, child: const ZabaApp()));
}
