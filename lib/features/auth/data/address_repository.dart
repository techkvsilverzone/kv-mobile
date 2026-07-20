import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'models/address.dart';

/// Address book CRUD against `/users/me/addresses`.
///
/// The server owns default-address semantics: the first address added is forced
/// default, setting one default unsets the others, and deleting the default
/// promotes another. Because a single write can therefore change *other* rows,
/// callers should re-[list] after any mutation instead of patching local state.
class AddressRepository {
  AddressRepository(this._api);

  final ApiClient _api;

  Future<List<Address>> list() async {
    final data = await _api.get('/users/me/addresses');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Address.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Address> create(Address address) async {
    final data = await _api.post('/users/me/addresses', data: address.toJson());
    return Address.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Address> update(String id, Address address) async {
    final data = await _api.put('/users/me/addresses/$id', data: address.toJson());
    return Address.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Responds 204 with an empty body.
  Future<void> delete(String id) => _api.delete('/users/me/addresses/$id');
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(apiClientProvider));
});
