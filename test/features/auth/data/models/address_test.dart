import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';

Map<String, dynamic> addressJson({String? id, String? mongoId}) => {
      if (id != null) 'id': id,
      if (mongoId != null) '_id': mongoId,
      'firstName': 'Asha',
      'lastName': 'K',
      'address': '12 MG Road',
      'city': 'Erode',
      'state': 'Tamil Nadu',
      'pincode': '638001',
      'phone': '9876543210',
      'isDefault': true,
    };

void main() {
  group('Address.fromJson', () {
    test('reads the `id` the address-book endpoints return', () {
      expect(Address.fromJson(addressJson(id: 'addr-1')).id, 'addr-1');
    });

    test('also reads `_id`, the shape embedded in GET /users/me', () {
      // The same entity is keyed differently depending on which endpoint
      // returned it, so both have to parse.
      expect(Address.fromJson(addressJson(mongoId: 'addr-2')).id, 'addr-2');
    });

    test('keeps pincode and phone as strings so leading zeros survive', () {
      final json = addressJson(id: 'a')..['pincode'] = '001001';
      final address = Address.fromJson(json);
      expect(address.pincode, '001001');
      expect(address.phone, isA<String>());
    });

    test('defaults isDefault to false when absent', () {
      final json = addressJson(id: 'a')..remove('isDefault');
      expect(Address.fromJson(json).isDefault, isFalse);
    });

    test('composes a full name', () {
      expect(Address.fromJson(addressJson(id: 'a')).fullName, 'Asha K');
    });
  });

  group('Address.toJson', () {
    test('omits the id — it travels in the URL, not the body', () {
      final json = Address.fromJson(addressJson(id: 'addr-1')).toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('_id'), isFalse);
    });

    test('omits an empty label rather than sending a blank string', () {
      final json = Address.fromJson(addressJson(id: 'a')).toJson();
      expect(json.containsKey('label'), isFalse);
    });

    test('includes every field the server requires', () {
      final json = Address.fromJson(addressJson(id: 'a')).toJson();
      for (final key in [
        'firstName', 'lastName', 'address', 'city', 'state', 'pincode', 'phone',
      ]) {
        expect(json.containsKey(key), isTrue, reason: key);
      }
    });
  });

  test('copyWith replaces only the named field', () {
    final original = Address.fromJson(addressJson(id: 'a'));
    final updated = original.copyWith(isDefault: false);
    expect(updated.isDefault, isFalse);
    expect(updated.city, 'Erode');
    expect(updated.id, 'a');
  });
}
