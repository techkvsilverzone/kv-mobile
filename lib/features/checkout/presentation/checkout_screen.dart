import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/env.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/validation/validators.dart';
import '../../auth/application/address_controller.dart';
import '../../auth/data/models/address.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/application/cart_totals.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../savings/application/installment_payer.dart';
import '../data/checkout_repository.dart';
import '../data/models/checkout_breakdown.dart';
import 'widgets/breakdown_table.dart';

/// kv-web's localStorage key for the last shipping address (Payment.tsx).
const savedAddressKey = 'kv-silver-address';

const _fields = [
  ('firstName', 'First Name', 'John', validateName),
  ('lastName', 'Last Name', 'Doe', validateLastName),
  ('address', 'Address', '123 Main Street', validateStreetAddress),
  ('city', 'City', 'Chennai', validateCity),
  ('state', 'State', 'Tamil Nadu', validateState),
  ('pincode', 'PIN Code', '600001', validatePincode),
  ('phone', 'Phone', '+91 98765 43210', validatePhone),
];

/// kv-ui pages/Payment.tsx: shipping form (prefilled from the address book or
/// the last order), payment method, order summary with coupon and estimate.
/// Unlike the web, the server's priced breakdown is shown for confirmation
/// before Razorpay opens, and that is the amount charged.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _couponCtrl = TextEditingController();
  final _ctrl = {for (final f in _fields) f.$1: TextEditingController()};
  Map<String, String> _errors = {};
  bool _saveAddress = true;
  bool _touched = false;
  bool _hasLocalAddress = false;

  Razorpay? _razorpay;
  CouponResult? _coupon;
  String? _appliedCode;
  String? _error;
  bool _busy = false;

  /// Held between create-order and the Razorpay callback so verify can resend
  /// the exact same lines and address the server priced.
  RazorpayOrderDraft? _draft;
  Address? _paidAddress;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _loadLocalAddress();
    // Prefill from the default (or first) saved address unless the form was edited.
    ref.listenManual<AsyncValue<List<Address>>>(addressListProvider, (_, next) {
      final list = next.valueOrNull ?? const [];
      if (_touched || list.isEmpty) return;
      _fill(list.where((a) => a.isDefault).firstOrNull ?? list.first);
      // May fire during initState, where setState is not allowed.
      Future.microtask(() => mounted ? setState(() {}) : null);
    }, fireImmediately: true);
    Future.microtask(() => ref.read(addressListProvider.notifier).load());
  }

  GiftWrapChoice? _giftWrapChoice() {
    final wrap = ref.read(giftWrapProvider);
    return wrap.enabled ? GiftWrapChoice(wrap.message) : null;
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _couponCtrl.dispose();
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLocalAddress() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(savedAddressKey);
      if (raw == null || !mounted) return;
      final saved = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _hasLocalAddress = true;
      // A server address (or the user's typing) wins over the local copy.
      final hasServer = (ref.read(addressListProvider).valueOrNull ?? const []).isNotEmpty;
      if (!_touched && !hasServer) {
        for (final e in _ctrl.entries) {
          e.value.text = (saved[e.key] ?? '').toString();
        }
      }
      setState(() {});
    } catch (_) {
      // Ignore a corrupt or unavailable store, as the web does.
    }
  }

  void _fill(Address a) {
    final values = {
      'firstName': a.firstName,
      'lastName': a.lastName,
      'address': a.address,
      'city': a.city,
      'state': a.state,
      'pincode': a.pincode,
      'phone': a.phone,
    };
    for (final e in values.entries) {
      _ctrl[e.key]!.text = e.value;
    }
  }

  void _selectSaved(Address a) {
    _fill(a);
    setState(() {
      _touched = true;
      _errors = {};
    });
  }

  String _v(String key) => _ctrl[key]!.text;

  /// The form as the address the server prices and ships to.
  Address get _formAddress => Address(
        id: '',
        firstName: _v('firstName').trim(),
        lastName: _v('lastName').trim(),
        address: _v('address').trim(),
        city: _v('city').trim(),
        state: _v('state').trim(),
        pincode: _v('pincode').trim(),
        // The address endpoints only accept a bare 10-digit mobile.
        phone: normalizePhone(_v('phone')),
      );

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _busy = true);
    try {
      final subtotal = ref.read(cartSubtotalProvider);
      final result = await ref
          .read(checkoutRepositoryProvider)
          .applyCoupon(code: code, orderAmount: subtotal);
      if (!mounted) return;
      if (result.valid) {
        setState(() {
          _coupon = result;
          _appliedCode = code.toUpperCase();
        });
        showToast(context, 'Coupon Applied', result.message);
      } else {
        showToast(context, 'Invalid Coupon', result.message, error: true);
      }
    } on ApiException catch (e) {
      // The server rejects a bad code with a 400 and a specific reason
      // ("Coupon has expired") — shown here; the web drops it for a generic line.
      if (mounted) {
        showToast(context, 'Coupon Error',
            e is NetworkException ? 'Unable to apply coupon.' : e.message,
            error: true);
      }
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

  /// Validates the form, prices the order server-side, then shows the
  /// authoritative breakdown for confirmation before the payment sheet opens.
  Future<void> _pay() async {
    final errors = <String, String>{
      for (final (key, _, _, validate) in _fields)
        if (validate(_v(key)) case final message?) key: message,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      showToast(context, 'Missing Information', 'Please correct the highlighted shipping details.',
          error: true);
      return;
    }
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    final address = _formAddress;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final draft = await ref.read(checkoutRepositoryProvider).createRazorpayOrder(
            items: items,
            address: address,
            couponCode: _appliedCode,
            giftWrap: _giftWrapChoice(),
          );
      if (!mounted) return;
      _draft = draft;
      _paidAddress = address;

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

      _openRazorpay(draft, address, items.length);
    } on ApiException catch (e) {
      // Out-of-stock, price mismatch and coupon failures all surface here. The
      // web collapses every one of them into "Could not initiate payment."
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
        showToast(context, 'Payment Failed', e.message, error: true);
      }
    }
  }

  void _openRazorpay(RazorpayOrderDraft draft, Address address, int itemCount) {
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
      'description': 'Order payment - $itemCount item(s)',
      'prefill': {
        'name': address.fullName,
        'email': user?.email ?? '',
        'contact': address.phone,
      },
      'theme': {'color': '#398FAC'},
    });
  }

  /// Web `persistAddress`: remember the address locally, and add it to the
  /// account's address book unless an identical one is already there.
  /// Non-blocking — the order is already placed.
  Future<void> _persistAddress(Address address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_saveAddress) {
        await prefs.setString(savedAddressKey, jsonEncode({
          for (final e in _ctrl.entries) e.key: e.value.text,
        }));
      } else {
        await prefs.remove(savedAddressKey);
      }
    } catch (_) {}
    if (!_saveAddress) return;
    final saved = ref.read(addressListProvider).valueOrNull ?? const [];
    final duplicate = saved.any((a) =>
        a.address == address.address &&
        a.pincode == address.pincode &&
        normalizePhone(a.phone) == address.phone);
    if (duplicate) return;
    try {
      await ref.read(addressListProvider.notifier).add(address);
    } catch (_) {}
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final address = _paidAddress;
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
            giftWrap: _giftWrapChoice(),
          );
      if (!mounted) return;

      _persistAddress(address);
      showToast(context, 'Payment Successful!', 'Your order has been placed.');
      await ref.read(cartProvider.notifier).clear();
      ref.read(giftWrapProvider.notifier).state = const GiftWrap();
      if (!mounted) return;
      context.pushReplacement('/orders/$orderId'); // the web navigates to order tracking
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
        title: const Text('Verification Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment verification failed. Contact support.'),
            const SizedBox(height: 8),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final items = ref.watch(cartProvider);
    final saved = ref.watch(addressListProvider).valueOrNull ?? const [];
    final deliveryConfig = ref.watch(deliveryConfigProvider).valueOrNull ?? DeliveryConfig.fallback;
    final gstPercent = ref.watch(cartGstPercentProvider);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    // Delivery is zone-based on the destination; known once a city/state is entered.
    final hasDestination = _v('city').isNotEmpty || _v('state').isNotEmpty;
    final summary = computeOrderSummary(OrderSummaryInput(
      subtotal: ref.watch(cartSubtotalProvider),
      taxableSubtotal: ref.watch(cartTaxableSubtotalProvider),
      discount: _coupon?.discount ?? 0,
      gstPercent: gstPercent,
      deliveryCharge:
          hasDestination ? deliveryConfig.chargeFor(city: _v('city'), state: _v('state')) : 0,
    ));

    Widget heading(String t) => Text(t,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20));
    Widget row(String label, String value, {Color? color, bool mutedValue = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: color ?? muted))),
              Text(value, style: TextStyle(color: color ?? (mutedValue ? muted : null))),
            ],
          ),
        );
    const green = Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          // Shipping Address
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: heading('Shipping Address')),
                      if (saved.isEmpty && _hasLocalAddress)
                        Text('Prefilled from your last order',
                            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (saved.isNotEmpty) ...[
                    Text('SAVED ADDRESSES',
                        style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in saved)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _selectSaved(a),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(TextSpan(children: [
                                  TextSpan(
                                    text: (a.label?.isNotEmpty == true
                                        ? a.label!
                                        : (a.fullName.isNotEmpty ? a.fullName : 'Address')),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500, color: scheme.onSurface),
                                  ),
                                  if (a.isDefault)
                                    TextSpan(
                                        text: ' • Default',
                                        style: TextStyle(fontSize: 10, color: scheme.primary)),
                                ]), style: const TextStyle(fontSize: 12)),
                                Text('${a.city}, ${a.pincode}',
                                    style: TextStyle(fontSize: 12, color: muted)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (final (key, label, hint, _) in _fields) ...[
                    TextField(
                      controller: _ctrl[key],
                      keyboardType: switch (key) {
                        'pincode' => TextInputType.number,
                        'phone' => TextInputType.phone,
                        _ => TextInputType.text,
                      },
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: hint,
                        errorText: _errors[key],
                      ),
                      onChanged: (_) => setState(() {
                        _touched = true;
                        _errors.remove(key);
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CheckboxListTile(
                    value: _saveAddress,
                    onChanged: (v) => setState(() => _saveAddress = v == true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('Save this address for next time', style: TextStyle(color: muted)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Payment Method
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading('Payment Method'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline),
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.credit_card, size: 20, color: muted),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pay Online (Razorpay)'),
                              Text('Card, UPI, Net Banking, Wallets',
                                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Order Summary
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading('Order Summary'),
                  const SizedBox(height: 24),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: ProductImageView(
                                image: item.imageData == null
                                    ? null
                                    : ProductImage(data: item.imageData!, sortOrder: 0),
                                decodeWidth: 64,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('Qty: ${item.quantity}',
                                    style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                                Text(formatInr(item.lineTotal),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 16),
                  const SizedBox(height: 8),
                  if (_appliedCode != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer_outlined, size: 16, color: green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_appliedCode!,
                                style: const TextStyle(fontWeight: FontWeight.w500, color: green)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Remove coupon',
                            onPressed: _removeCoupon,
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _couponCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration:
                                const InputDecoration(hintText: 'Coupon code', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _busy ? null : _applyCoupon,
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  row('Subtotal (before GST)', formatInr(summary.subtotal)),
                  if (summary.discount > 0)
                    row('Coupon Discount', '-${formatInr(summary.discount)}', color: green),
                  row('GST (${_percent(gstPercent)}%)', formatInr(summary.gst)),
                  row('Delivery',
                      hasDestination
                          ? formatInr(summary.deliveryCharge)
                          : 'Calculated at checkout',
                      mutedValue: !hasDestination),
                  if (ref.watch(giftWrapProvider).enabled) row('Gift Wrapping', formatInr(giftWrapFee)),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: Text('Total', style: theme.textTheme.titleMedium)),
                      Text(formatInr(summary.total + (ref.watch(giftWrapProvider).enabled ? giftWrapFee : 0)),
                          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pay,
                    iconAlignment: IconAlignment.end,
                    icon: _busy ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
                    label: Text(_busy ? 'Processing...' : 'Pay ${formatInr(summary.total)}'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Text('Secure 256-bit SSL encryption',
                          style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!Env.hasRazorpayKey) ...[
            const SizedBox(height: 16),
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Online payment is not configured in this build. Rebuild with '
                  '--dart-define=RAZORPAY_KEY_ID=… to enable checkout.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `3` not `3.0`, as JS prints it.
String _percent(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();

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
