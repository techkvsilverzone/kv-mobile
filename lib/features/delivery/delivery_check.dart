import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// `GET /delivery/check?pincode=` — real serviceability from the postal directory.
class DeliveryCheck {
  const DeliveryCheck({
    required this.available,
    required this.verified,
    this.city,
    this.state,
    this.deliveryFee,
    this.estimatedDays,
    this.reason,
  });

  final bool available;

  /// False when the postal directory was unreachable: available, but unconfirmed.
  final bool verified;
  final String? city, state, estimatedDays, reason;
  final double? deliveryFee;

  factory DeliveryCheck.fromJson(Map<String, dynamic> j) => DeliveryCheck(
        available: j['available'] == true,
        verified: j['verified'] != false,
        city: j['city'] as String?,
        state: j['state'] as String?,
        deliveryFee: (j['deliveryFee'] as num?)?.toDouble(),
        estimatedDays: j['estimatedDays'] as String?,
        reason: j['reason'] as String?,
      );
}

class DeliveryRepository {
  DeliveryRepository(this._api);
  final ApiClient _api;

  Future<DeliveryCheck> check(String pincode) async {
    final data = await _api.get('/delivery/check', query: {'pincode': pincode});
    return DeliveryCheck.fromJson((data as Map).cast<String, dynamic>());
  }
}

final deliveryRepositoryProvider =
    Provider<DeliveryRepository>((ref) => DeliveryRepository(ref.watch(apiClientProvider)));
