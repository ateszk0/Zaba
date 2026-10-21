import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/application/order_providers.dart';
import '../data/fake_payment_service.dart';
import '../domain/payment_service.dart';

/// How long the fake provider "processes" a payment. Tests set it to zero.
final paymentProcessingDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1200),
);

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => FakePaymentService(
    sink: ref.watch(paymentEventSinkProvider),
    orders: ref.watch(orderRepositoryProvider),
    processingDelay: ref.watch(paymentProcessingDelayProvider),
  ),
);
