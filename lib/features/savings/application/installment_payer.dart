import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/env.dart';
import '../../../core/format/currency.dart';
import '../data/savings_models.dart';
import '../data/savings_repository.dart';

String formatGrams(double g) => '${g.toStringAsFixed(3)}g';
final _plain = NumberFormat('#,##,##0.##', 'en_IN');

/// The success toast's (title, body) after a verified installment, as the web
/// words it. The credited row is matched by Razorpay payment id, so a bonus row
/// landing in the same response is never mistaken for this payment.
(String, String) installmentSuccessMessage({
  required SavingsEnrollment before,
  required SavingsEnrollment after,
  required bool isFlexible,
  required double paidAmount,
  required String razorpayPaymentId,
}) {
  final credited = after.payments
      .where((p) => p.razorpayPaymentId == razorpayPaymentId)
      .firstOrNull;
  final metal = before.isGold ? 'Gold' : 'Silver';
  if (isFlexible) {
    final note = credited != null && credited.materialWeight > 0
        ? " — ${formatGrams(credited.materialWeight)} $metal credited at today's rate of "
            '${formatInr(credited.materialRate)}/g.'
        : '';
    return (
      'Payment Successful!',
      '₹${_plain.format(paidAmount)} recorded on your passbook.$note'
    );
  }
  final s = summarizeScheme(after);
  final grams = s.hasGrams && credited != null
      ? ' ${formatGrams(credited.materialWeight)} added at ${formatInr(credited.materialRate)}/g'
          ' · total now ${formatGrams(s.totalGrams)}.'
      : '';
  return (
    'Month ${s.paidMonths} of ${s.totalMonths} paid',
    '₹${_plain.format(paidAmount)} received.$grams ${s.pendingMonths} month'
        '${s.pendingMonths == 1 ? '' : 's'} pending.',
  );
}

void showToast(BuildContext context, String title, String body,
    {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  // A newer toast replaces the current one rather than queueing behind it.
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? scheme.error : null,
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body.isNotEmpty) Text(body),
          ]),
    ));
}

/// Pays a savings installment through Razorpay (kv-ui useInstallmentPayment).
/// Owned by a screen's State: create in initState, [dispose] in dispose.
class InstallmentPayer {
  InstallmentPayer(
      {required this.ref,
      required this.context,
      required this.onChanged,
      this.onPaid}) {
    _razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (_) => _finish())
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) => _finish());
  }

  final WidgetRef ref;
  final BuildContext Function() context;

  /// Called when [payingSchemeId] changes, so the screen can rebuild.
  final VoidCallback onChanged;
  final void Function(SavingsEnrollment)? onPaid;

  final _razorpay = Razorpay();
  String? payingSchemeId;
  SavingsEnrollment? _scheme;
  bool _flexible = false;
  double _paidAmount = 0;
  String? _orderId;

  void dispose() => _razorpay.clear();

  /// The screen may have closed while a request was in flight.
  void _toast(String title, String body, {bool error = false}) {
    final c = context();
    if (c.mounted) showToast(c, title, body, error: error);
  }

  void _finish() {
    payingSchemeId = null;
    onChanged();
  }

  Future<void> pay(SavingsEnrollment scheme,
      {required bool isFlexible, double? customAmount}) async {
    payingSchemeId = scheme.id;
    onChanged();
    if (!Env.hasRazorpayKey) {
      _toast('Payment Error', 'Failed to load payment gateway.', error: true);
      _finish();
      return;
    }
    try {
      final order = await ref
          .read(savingsRepositoryProvider)
          .createInstallmentOrder(scheme.id, amount: customAmount);
      _scheme = scheme;
      _flexible = isFlexible;
      _paidAmount = order.amountInPaise / 100;
      _orderId = order.id;
      final user = ref.read(currentUserProvider);
      _razorpay.open({
        'key': Env.razorpayKeyId,
        'amount': order.amountInPaise,
        'currency': order.currency,
        'name': 'KV Silver Zone',
        'description':
            'Savings installment - ${scheme.planName ?? 'Savings Scheme'}',
        'order_id': order.id,
        'prefill': {
          'name': user?.name ?? '',
          'email': user?.email ?? '',
          'contact': user?.phone ?? ''
        },
        'theme': {'color': '#1a1a1a'},
      });
    } catch (e) {
      _toast('Payment failed',
          e is ApiException ? e.message : 'Could not initiate payment.',
          error: true);
      _finish();
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final scheme = _scheme;
    if (scheme == null) return _finish();
    try {
      final paymentId = r.paymentId ?? '';
      final updated =
          await ref.read(savingsRepositoryProvider).verifyInstallment(
                scheme.id,
                razorpayOrderId: r.orderId ?? _orderId ?? '',
                razorpayPaymentId: paymentId,
                razorpaySignature: r.signature ?? '',
              );
      if (updated == null) return;
      final (title, body) = installmentSuccessMessage(
          before: scheme,
          after: updated,
          isFlexible: _flexible,
          paidAmount: _paidAmount,
          razorpayPaymentId: paymentId);
      _toast(title, body);
      onPaid?.call(updated);
    } catch (_) {
      _toast('Verification Failed',
          'Payment verification failed. Contact support.',
          error: true);
    } finally {
      _finish();
    }
  }
}
