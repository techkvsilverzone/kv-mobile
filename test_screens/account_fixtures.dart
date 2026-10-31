// Sample data for the account / auth / notifications / info screenshots.
import 'dart:async';
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/auth/data/models/user.dart';
import 'package:kv_silver_mobile/features/notifications/notifications.dart';

User sampleUser({bool verified = false}) => User(
      id: 'u1',
      name: 'Vinoth Kumar',
      email: 'vinoth.kumar@example.com',
      phone: '9876543210',
      phoneVerified: verified,
      role: 'customer',
      dateOfBirth: DateTime(1990, 4, 12),
    );

const sampleAddresses = [
  Address(
    id: 'a1', label: 'Home', firstName: 'Vinoth', lastName: 'Kumar',
    address: '12, Anna Salai, T. Nagar', city: 'Chennai', state: 'Tamil Nadu',
    pincode: '600017', phone: '9876543210', isDefault: true,
  ),
  Address(
    id: 'a2', label: 'Office', firstName: 'Vinoth', lastName: 'Kumar',
    address: '4th Floor, Tidel Park, Rajiv Gandhi Salai, Taramani', city: 'Chennai', state: 'Tamil Nadu',
    pincode: '600113', phone: '9876543210',
  ),
  Address(
    id: 'a3', label: '', firstName: 'Lakshmi', lastName: 'Narayanan',
    address: '22/7, Gandhi Road', city: 'Coimbatore', state: 'Tamil Nadu',
    pincode: '641001', phone: '9123456780',
  ),
];

/// Serves [addresses]; `null` never completes (loading state).
class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository(this.addresses);
  final List<Address>? addresses;

  @override
  Future<List<Address>> list() => addresses == null ? Completer<List<Address>>().future : Future.value(addresses);
  @override
  Future<Address> create(Address address) async => address;
  @override
  Future<Address> update(String id, Address address) async => address;
  @override
  Future<void> delete(String id) async {}
}

NotificationInbox sampleInbox() {
  final now = DateTime.now();
  AppNotification n(String id, String kind, String title, String body, Duration ago, {bool read = false}) =>
      AppNotification(id: id, kind: kind, title: title, body: body, read: read, createdAt: now.subtract(ago));
  return NotificationInbox(unreadCount: 2, notifications: [
    n('1', 'order', 'Order shipped', 'Your order #000124 is on its way with BlueDart.', const Duration(minutes: 12)),
    n('2', 'payment', 'Payment received', '₹5,104.30 paid for order #000124.', const Duration(minutes: 40)),
    n('3', 'savings', 'Instalment due soon', 'Your Silver Purchase Plan instalment of ₹2,000 is due on 5 Nov.',
        const Duration(days: 1, hours: 2), read: true),
    n('4', 'return', 'Return approved', 'Return #A1B2C3 was approved. Refund in 5–7 business days.',
        const Duration(days: 3), read: true),
    n('5', 'general', 'Diwali collection is live', 'New kuthu vilakku and gift sets just arrived.',
        const Duration(days: 9), read: true),
  ]);
}
