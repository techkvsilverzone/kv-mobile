import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'models/order.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  /// The customer list is `/orders/me` — there is no `GET /orders` for
  /// customers; a bare `/orders` would 404.
  Future<List<Order>> fetchMyOrders() async {
    final data = await _api.get('/orders/me');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Order.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// A real endpoint, unlike on web — which fetches the whole list and finds
  /// the order locally.
  Future<Order> fetchOrder(String id) async {
    final data = await _api.get('/orders/$id');
    return Order.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> resendConfirmation(String id) =>
      _api.post('/orders/$id/resend-confirmation');
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

final myOrdersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).fetchMyOrders();
});

final orderProvider = FutureProvider.family<Order, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).fetchOrder(id);
});
