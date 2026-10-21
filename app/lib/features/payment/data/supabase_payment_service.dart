import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/domain/order.dart';
import '../../orders/domain/order_repository.dart';
import '../domain/card_outcome.dart';
import '../domain/payment_service.dart';

/// Pays through the Edge Functions. `payments-create` starts the payment attempt
/// as the signed-in customer and opens a provider session; the fake provider's
/// page (`fake-provider-confirm`) is told how the card step ended, and its
/// backend delivers a signed event to the webhook. Only that event can make the
/// order paid: this class never writes to an order, it reads the result back.
class SupabasePaymentService implements PaymentService {
  SupabasePaymentService(
    this._client, {
    required this.orders,
    this.processingDelay = const Duration(milliseconds: 1200),
  });

  final SupabaseClient _client;
  final OrderRepository orders;

  /// Simulated time the provider needs to process the payment.
  final Duration processingDelay;

  @override
  Future<PaymentStatus> submit({
    required String orderId,
    required CardOutcome outcome,
  }) async {
    if (processingDelay > Duration.zero) {
      await Future<void>.delayed(processingDelay);
    }
    try {
      final created = await _client.functions.invoke(
        'payments-create',
        body: {'order_id': orderId},
      );
      final session = (created.data as Map<String, dynamic>)['session_token'];
      await _client.functions.invoke(
        'fake-provider-confirm',
        body: {
          'session_token': session,
          'outcome': switch (outcome) {
            CardOutcome.approved => 'approved',
            CardOutcome.declined => 'declined',
            CardOutcome.cancelled => 'cancelled',
          },
        },
      );
      final order = await orders.findOrder(orderId);
      return order?.paymentStatus ?? PaymentStatus.failed;
    } on FunctionException catch (error) {
      throw PaymentUnavailableException(error);
    } on PostgrestException catch (error) {
      throw PaymentUnavailableException(error);
    } catch (error) {
      // The network (a socket, a timeout, a browser fetch error), or an answer
      // the app cannot read: either way the payment did not go through here.
      throw PaymentUnavailableException(error);
    }
  }
}
