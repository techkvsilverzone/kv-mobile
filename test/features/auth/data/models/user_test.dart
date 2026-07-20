import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/auth/data/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('reads Mongo\'s _id as the id', () {
      final user = User.fromJson({'_id': '665f00', 'name': 'Asha', 'email': 'a@b.com'});
      expect(user.id, '665f00');
    });

    test('defaults role to customer when the server omits it', () {
      // PUT /users/me returns the raw Mongoose document, which has no computed
      // `role` — unlike GET /users/me, which adds one.
      final user = User.fromJson({'_id': '1', 'name': 'Asha', 'email': 'a@b.com'});
      expect(user.role, 'customer');
    });

    test('keeps an explicit role', () {
      final user = User.fromJson(
          {'_id': '1', 'name': 'A', 'email': 'a@b.com', 'role': 'admin', 'isAdmin': true});
      expect(user.role, 'admin');
      expect(user.isAdmin, isTrue);
    });

    test('treats a missing isActive as active and a missing isAdmin as not admin', () {
      final user = User.fromJson({'_id': '1', 'name': 'A', 'email': 'a@b.com'});
      expect(user.isActive, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('parses ISO dates and tolerates missing or unparseable ones', () {
      final user = User.fromJson({
        '_id': '1',
        'name': 'A',
        'email': 'a@b.com',
        'dateOfBirth': '1990-05-01T00:00:00.000Z',
        'anniversaryDate': 'not-a-date',
      });
      expect(user.dateOfBirth?.year, 1990);
      expect(user.anniversaryDate, isNull);
    });
  });

  group('AuthResult.fromJson', () {
    test('reads the token as a sibling of user, not nested inside it', () {
      final result = AuthResult.fromJson({
        'user': {'_id': '1', 'name': 'Asha', 'email': 'a@b.com'},
        'token': 'jwt-abc',
      });
      expect(result.token, 'jwt-abc');
      expect(result.user.name, 'Asha');
      expect(result.promoCoupon, isNull);
    });

    test('picks up a stall-event promo coupon when present', () {
      final result = AuthResult.fromJson({
        'user': {'_id': '1', 'name': 'A', 'email': 'a@b.com'},
        'token': 't',
        'promoCoupon': 'STALLABC123',
      });
      expect(result.promoCoupon, 'STALLABC123');
    });
  });
}
