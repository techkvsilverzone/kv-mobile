import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/env.dart';
import '../../../core/format/currency.dart';
import '../../auth/application/address_controller.dart';
import '../../auth/data/models/address.dart';
import '../../cart/application/cart_controller.dart';
import '../data/checkout_repository.dart';
import '../data/models/checkout_breakdown.dart';
import 'widgets/breakdown_table.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _couponCtrl = TextEditingController();

  Razorpay? _razorpay;
  Address? _selectedAddress;
  CouponResult? _coupon;
  String? _appliedCode;
  String? _error;
  bool _busy = false;

  /// Held between create-order and the Razorpay callback so verify can resend
  /// the exact same lines the server priced.
  RazorpayOrderDraft? _draft;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    Future.microtask(() => ref.read(addressListProvider.notifier).load());
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final subtotal = ref.read(cartSubtotalProvider);
      final result = await ref
          .read(checkoutRepositoryProvider)
          .applyCoupon(code: code, orderAmount: subtotal);
      if (!mounted) return;
      setState(() {
        _coupon = result;
        _appliedCode = result.valid ? code.toUpperCase() : null;
      });
    } on ApiException catch (e) {
      // The server's message is specific ("Coupon has expired", "Minimum order
      // amount of ₹X required") — show it rather than a generic string.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _coupon = null;
      _appliedCode = null;
      _couponCtrl.clear();
    });
  }

  /// Prices the order server-side, then shows the authoritative breakdown for
  /// confirmation before any payment sheet opens.
  Future<void> _reviewAndPay() async {
    final address = _selectedAddress;
    if (address == null) {
      setState(() => _error = 'Choose a delivery address to continue.');
      return;
    }
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final draft = await ref.read(checkoutRepositoryProvider).createRazorpayOrder(
            items: items,
            address: address,
            couponCode: _appliedCode,
          );
      if (!mounted) return;
      _draft = draft;

      final localEstimate = ref.read(cartSubtotalProvider);
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ConfirmSheet(
          breakdown: draft.breakdown,
          amount: draft.amountInRupees,
          // Flag a moved metal rate rather than silently charging a different
          // number, which is what the web does — it requests this breakdown
          // and then ignores it.
          subtotalChanged: (draft.breakdown.subtotal - localEstimate).abs() >= 1,
          localSubtotal: localEstimate,
        ),
      );
      if (confirmed != true || !mounted) {
        setState(() => _busy = false);
        return;
      }

      _openRazorpay(draft, address);
    } on ApiException catch (e) {
      // Out-of-stock, price mismatch and coupon failures all surface here. The
      // web collapses every one of them into "Could not initiate payment."
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  void _openRazorpay(RazorpayOrderDraft draft, Address address) {
    if (!Env.hasRazorpayKey) {
      setState(() {
        _error = 'Online payment is not configured in this build.';
        _busy = false;
      });
      return;
    }

    final user = ref.read(currentUserProvider);
    _razorpay?.open({
      'key': Env.razorpayKeyId,
      // Amount and order id come from the server, never from client math.
      'amount': draft.amountInPaise,
      'currency': draft.currency,
      'order_id': draft.id,
      'name': 'KV Silver Zone',
      'description': 'Order payment',
      'prefill': {
        'name': address.fullName,
        'email': user?.email ?? '',
        'contact': address.phone,
      },
      'theme': {'color': '#398FAC'},
    });
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final address = _selectedAddress;
    final items = ref.read(cartProvider);
    if (address == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final orderId = await ref.read(checkoutRepositoryProvider).verifyPayment(
            razorpayOrderId: response.orderId ?? _draft?.id ?? '',
            razorpayPaymentId: response.paymentId ?? '',
            razorpaySignature: response.signature ?? '',
            items: items,
            address: address,
            couponCode: _appliedCode,
          );
      if (!mounted) return;

      await ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      context.pushReplacement('/orders/$orderId');
    } on PaymentVerificationException catch (e) {
      // The payment succeeded but the order was not created. The customer has
      // been charged, so show the payment id they will need for support rather
      // than a bare "contact support" with nothing to quote. The cart is
      // deliberately NOT cleared.
      if (mounted) {
        setState(() => _busy = false);
        _showVerificationFailure(e);
      }
    }
  }

  void _showVerificationFailure(PaymentVerificationException e) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment taken, order not confirmed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message),
            const SizedBox(height: 12),
            const Text('Your payment may have gone through. Quote this reference '
                'to support — do not pay again:'),
            const SizedBox(height: 8),
            SelectableText(
              e.razorpayPaymentId,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      // The web wires no failure handler at all, so a failed payment shows the
      // customer nothing.
      _error = response.message?.isNotEmpty == true
          ? response.message!
          : 'Payment was not completed.';
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final addresses = ref.watch(addressListProvider);
    final deliveryConfig = ref.watch(deliveryConfigProvider).valueOrNull;

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    final estimatedDelivery = _selectedAddress == null || deliveryConfig == null
        ? null
        : deliveryConfig.chargeFor(
            city: _selectedAddress!.city, state: _selectedAddress!.state);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Text('Delivery address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          addresses.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text(
              e is ApiException ? e.message : 'Could not load your addresses.',
            ),
            data: (list) => _AddressPicker(
              addresses: list,
              selected: _selectedAddress,
              onSelected: (a) => setState(() => _selectedAddress = a),
              onAddNew: () => context.push('/profile/addresses/new'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Coupon', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_appliedCode != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: Text(_appliedCode!),
                subtitle: Text(_coupon?.message ?? ''),
                trailing: TextButton(onPressed: _removeCoupon, child: const Text('Remove')),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon code',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _applyCoupon,
                  child: const Text('Apply'),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text('Estimate', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _EstimateRow(label: 'Subtotal (before GST)', value: formatInr(subtotal)),
                  if ((_coupon?.discount ?? 0) > 0)
                    _EstimateRow(
                      label: 'Coupon discount',
                      value: '−${formatInr(_coupon!.discount)}',
                    ),
                  _EstimateRow(
                    label: 'Delivery',
                    value: estimatedDelivery == null
                        ? 'Choose an address'
                        : formatInr(estimatedDelivery),
                  ),
                  const Divider(height: 20),
                  Text(
                    'GST and the final total are calculated by the server on the '
                    'next step. You will see the exact amount before paying.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!Env.hasRazorpayKey)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Online payment is not configured in this build. Rebuild with '
                  '--dart-define=RAZORPAY_KEY_ID=… to enable checkout.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy || _selectedAddress == null ? null : _reviewAndPay,
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Review & pay'),
          ),
        ),
      ),
    );
  }
}

class _AddressPicker extends StatelessWidget {
  const _AddressPicker({
    required this.addresses,
    required this.selected,
    required this.onSelected,
    required this.onAddNew,
  });

  final List<Address> addresses;
  final Address? selected;
  final ValueChanged<Address> onSelected;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No saved addresses yet.'),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onAddNew, child: const Text('Add an address')),
            ],
          ),
        ),
      );
    }

    // Default to the address the server marked default.
    final effective = selected ??
        addresses.where((a) => a.isDefault).firstOrNull ??
        addresses.first;
    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSelected(effective));
    }

    return Column(
      children: [
        RadioGroup<String>(
          groupValue: effective.id,
          onChanged: (id) {
            final match = addresses.where((a) => a.id == id).firstOrNull;
            if (match != null) onSelected(match);
          },
          child: Column(
            children: [
              for (final a in addresses)
                Card(
                  child: RadioListTile<String>(
                    value: a.id,
                    title: Text(a.fullName),
                    subtitle: Text('${a.address}\n${a.city}, ${a.state} ${a.pincode}'),
                    isThreeLine: true,
                  ),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddNew,
            icon: const Icon(Icons.add),
            label: const Text('Add another address'),
          ),
        ),
      ],
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.breakdown,
    required this.amount,
    required this.subtotalChanged,
    required this.localSubtotal,
  });

  final CheckoutBreakdown breakdown;
  final double amount;
  final bool subtotalChanged;
  final double localSubtotal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Confirm your order', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('These are the final amounts, priced by the server.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (subtotalChanged) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Prices changed since you added these items '
                      '(${formatInr(localSubtotal)} → ${formatInr(breakdown.subtotal)}). '
                      "Today's metal rate applies.",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BreakdownTable(breakdown: breakdown),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Pay ${formatInr(amount)}'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}
