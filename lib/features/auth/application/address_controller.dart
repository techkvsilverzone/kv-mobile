import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/address_repository.dart';
import '../data/models/address.dart';

/// The address list, owned by the server.
///
/// Every mutation re-fetches instead of patching in place: a single write can
/// change rows the client did not touch (adding the first address forces it
/// default; setting a default unsets the previous one; deleting the default
/// promotes another), so local patching would drift from the server.
class AddressListController extends StateNotifier<AsyncValue<List<Address>>> {
  AddressListController(this._repo) : super(const AsyncValue.loading());

  final AddressRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.list);
  }

  Future<void> add(Address address) async {
    await _repo.create(address);
    await load();
  }

  Future<void> update(String id, Address address) async {
    await _repo.update(id, address);
    await load();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final addressListProvider =
    StateNotifierProvider<AddressListController, AsyncValue<List<Address>>>((ref) {
  return AddressListController(ref.watch(addressRepositoryProvider));
});
