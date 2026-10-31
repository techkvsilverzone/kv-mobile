import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'savings_models.dart';

/// A Razorpay order for one installment (`POST /savings/:id/pay/create-order`).
class InstallmentOrder {
  const InstallmentOrder({required this.id, required this.amountInPaise, required this.currency});
  final String id;
  final int amountInPaise;
  final String currency;
}

/// kv-ui savingsService + schemePlanService (customer endpoints only).
class SavingsRepository {
  SavingsRepository(this._api);

  final ApiClient _api;

  /// Public catalogue of active plans.
  Future<List<SchemePlan>> fetchPlans() async {
    final data = unwrapData(await _api.get('/scheme-plans'));
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => SchemePlan.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<List<SavingsEnrollment>> fetchMySchemes() async {
    final data = await _api.get('/savings/my-schemes');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => SavingsEnrollment.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Own schemes only (403 for another customer's passbook).
  Future<SavingsEnrollment> fetchByPassbook(String passbookNumber) async {
    final data =
        await _api.get('/savings/passbook/${Uri.encodeComponent(passbookNumber.trim())}');
    return SavingsEnrollment.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Sends the enrollment confirmation code. Returns the channel: 'whatsapp' | 'email'.
  Future<String> requestEnrollOtp() async {
    final data = await _api.post('/savings/enroll/request-otp', data: const <String, dynamic>{});
    return data is Map ? (data['channel'] ?? 'whatsapp').toString() : 'whatsapp';
  }

  Future<SavingsEnrollment> enroll({
    required String schemeType,
    required double monthlyAmount,
    required String startDate,
    required String otp,
  }) async {
    final data = await _api.post('/savings/enroll', data: {
      'schemeType': schemeType,
      'monthlyAmount': monthlyAmount,
      'startDate': startDate,
      'otp': otp,
    });
    return SavingsEnrollment.fromJson((data as Map).cast<String, dynamic>());
  }

  /// FIXED schemes: the server uses the scheme's own monthly amount and ignores
  /// `amount`. FLEXIBLE schemes: `amount` is required (>= the plan minimum).
  Future<InstallmentOrder> createInstallmentOrder(String schemeId, {double? amount}) async {
    final data = await _api.post('/savings/$schemeId/pay/create-order',
        data: amount == null ? const <String, dynamic>{} : {'amount': amount});
    final m = (data as Map).cast<String, dynamic>();
    return InstallmentOrder(
      id: m['id'].toString(),
      amountInPaise: (m['amount'] as num).toInt(),
      currency: (m['currency'] ?? 'INR').toString(),
    );
  }

  /// Returns the updated scheme, or null when the server answers `success: false`.
  Future<SavingsEnrollment?> verifyInstallment(
    String schemeId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final data = await _api.post('/savings/$schemeId/pay/verify', data: {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    if (data is! Map || data['success'] != true || data['scheme'] is! Map) return null;
    return SavingsEnrollment.fromJson((data['scheme'] as Map).cast<String, dynamic>());
  }
}

final savingsRepositoryProvider =
    Provider<SavingsRepository>((ref) => SavingsRepository(ref.watch(apiClientProvider)));

final schemePlansProvider =
    FutureProvider<List<SchemePlan>>((ref) => ref.watch(savingsRepositoryProvider).fetchPlans());

final mySchemesProvider = FutureProvider<List<SavingsEnrollment>>(
    (ref) => ref.watch(savingsRepositoryProvider).fetchMySchemes());

final passbookProvider = FutureProvider.family<SavingsEnrollment, String>(
    (ref, number) => ref.watch(savingsRepositoryProvider).fetchByPassbook(number));

/// Whether a scheme type's plan is FLEXIBLE (the web looks this up in the catalogue).
final isFlexibleTypeProvider = Provider.family<bool, String>((ref, type) =>
    ref.watch(schemePlansProvider).valueOrNull?.where((p) => p.type == type).firstOrNull?.isFlexible ??
    false);
