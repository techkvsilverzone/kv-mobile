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
import '../../../core/ui/kv_ui.dart';
import '../../cart/presentation/widgets/item_thumb.dart';
import '../data/checkout_repository.dart';
import '../data/models/checkout_breakdown.dart';
import 'widgets/breakdown_table.dart';
import 'widgets/price_details.dart';

/// kv-web's localStorage key for the last shipping address (Payment.tsx).
const savedAddressKey = 'kv-silver-address';

const _fields = [
  ('firstName', 'First name', 'John', validateName),
  ('lastName', 'Last name', 'Doe', validateLastName),
  ('address', 'Address', '123 Main Street', validateStreetAddress),
  ('city', 'City', 'Chennai', validateCity),
  ('state', 'State', 'Tamil Nadu', validateState),
  ('pincode', 'PIN code', '600001', validatePincode),
  ('phone', 'Phone', '+91 98765 43210', validatePhone),
];

/// kv-ui pages/Payment.tsx as one native page: delivery address (a saved one,
/// or the inline form when there are none), coupon, gift wrap, price estimate.
/// Unlike the web, the server's priced breakdown is shown for confirmation
/// before Razorpay opens, and that is the amount charged.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _ctrl = {for (final f in _fields) f.$1: TextEditingController()};
  Map<String, String> _errors = {};
  bool _saveAddress = true;
  bool _touched = false;
  bool _hasLocalAddress = false;

  /// Saved address the form was filled from; [_editing] shows the form instead.
  String? _selectedId;
  bool _editing = false;

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
    _selectedId = a.id;
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
      _editing = false;
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

  /// Applies [code]; returns the reason it was refused, or null on success.
  Future<String?> _applyCoupon(String code) async {
    code = code.trim();
    if (code.isEmpty) return 'Enter a coupon code.';
    try {
      final subtotal = ref.read(cartSubtotalProvider);
      final result = await ref
          .read(checkoutRepositoryProvider)
          .applyCoupon(code: code, orderAmount: subtotal);
      if (!mounted) return null;
      if (!result.valid) return result.message.isEmpty ? 'This coupon is not valid.' : result.message;
      setState(() {
        _coupon = result;
        _appliedCode = code.toUpperCase();
      });
      showKvToast(context, 'Coupon applied', message: result.message);
      return null;
    } on ApiException catch (e) {
      // The server rejects a bad code with a 400 and a specific reason
      // ("Coupon has expired") — shown here; the web drops it for a generic line.
      return e is NetworkException ? 'Unable to apply coupon.' : e.message;
    }
  }

  void _removeCoupon() {
    setState(() {
      _coupon = null;
      _appliedCode = null;
    });
  }

  /// Validates the form, prices the order server-side, then shows the
  /// authoritative breakdown for confirmation before the payment sheet opens.
  Future<void> _pay() async {
    final errors = <String, String>{
      for (final (key, _, _, validate) in _fields)
        if (validate(_v(key)) case final message?) key: message,
    };
    setState(() {
      _errors = errors;
      // A saved address can fail today's validation; open it for editing.
      if (errors.isNotEmpty) _editing = true;
    });
    if (errors.isNotEmpty) {
      showKvToast(context, 'Check your delivery address',
          message: 'Please correct the highlighted details.', error: true);
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
      final confirmed = await showKvSheet<bool>(
        context,
        title: 'Confirm your order',
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
        showKvToast(context, 'Payment failed', message: e.message, error: true);
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
      'theme': {'color': '#2F6CB0'},
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
      showKvToast(context, 'Payment successful', message: 'Your order has been placed.');
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
        title: const Text('Payment not confirmed'),
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

  /// Saved addresses as a picker; "Add new address" opens the address form.
  Future<void> _pickAddress(List<Address> saved) async {
    final picked = await showKvSheet<Object>(
      context,
      title: 'Deliver to',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 16 + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final a in saved) ...[
            _AddressOption(address: a, selected: a.id == _selectedId && !_editing, onTap: () => Navigator.pop(ctx, a)),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add new address'),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    if (picked is Address) return _selectSaved(picked);

    final before = saved.map((a) => a.id).toSet();
    await context.push('/profile/addresses/new');
    if (!mounted) return;
    final added = (ref.read(addressListProvider).valueOrNull ?? const <Address>[])
        .where((a) => !before.contains(a.id))
        .firstOrNull;
    if (added != null) _selectSaved(added);
  }

  Future<void> _openCoupon() =>
      showKvSheet<void>(context, title: 'Apply coupon', builder: (_) => _CouponSheet(apply: _applyCoupon));

  @override
  Widget build(BuildContext context) {
    ref.watch(cartRefreshProvider); // re-price lines so the estimate matches the charge
    final items = ref.watch(cartProvider);
    final savedAsync = ref.watch(addressListProvider);
    final saved = savedAsync.valueOrNull ?? const <Address>[];
    final deliveryConfig = ref.watch(deliveryConfigProvider).valueOrNull ?? DeliveryConfig.fallback;
    final gstPercent = ref.watch(cartGstPercentProvider);
    final wrap = ref.watch(giftWrapProvider);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Your cart is empty',
            actionLabel: 'Start shopping',
            onAction: () => context.go('/shop'),
          ),
        ),
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
    final estimate = summary.total + (wrap.enabled ? giftWrapFee : 0);
    final showForm = saved.isEmpty || _editing;
    final selected = saved.where((a) => a.id == _selectedId).firstOrNull;
    final count = items.fold<int>(0, (n, e) => n + e.quantity);

    Widget section(String title, Widget child, {String? action, VoidCallback? onAction}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(
              title: title, action: action, onAction: onAction, padding: const EdgeInsets.fromLTRB(4, 0, 0, 8)),
          child,
          const SizedBox(height: Kv.gap),
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, 8),
        children: [
          if (_error != null) ...[
            _Banner(icon: Icons.error_outline_rounded, message: _error!),
            const SizedBox(height: 16),
          ],
          if (!Env.hasRazorpayKey) ...[
            const _Banner(
              icon: Icons.build_circle_outlined,
              message: 'Online payment is not configured in this build. Rebuild with '
                  '--dart-define=RAZORPAY_KEY_ID=… to enable checkout.',
            ),
            const SizedBox(height: 16),
          ],
          section(
            'Delivery address',
            showForm
                ? KvCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (saved.isEmpty && _hasLocalAddress)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('Filled in from your last order',
                              style: TextStyle(fontSize: 12, color: Kv.muted)),
                        ),
                      for (final (key, label, hint, _) in _fields) ...[
                        TextField(
                          controller: _ctrl[key],
                          keyboardType: switch (key) {
                            'pincode' => TextInputType.number,
                            'phone' => TextInputType.phone,
                            _ => TextInputType.text,
                          },
                          textCapitalization:
                              key == 'pincode' || key == 'phone' ? TextCapitalization.none : TextCapitalization.words,
                          decoration: InputDecoration(labelText: label, hintText: hint, errorText: _errors[key]),
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
                        title: const Text('Save this address for next time', style: TextStyle(fontSize: 14)),
                      ),
                    ]),
                  )
                : savedAsync.isLoading && saved.isEmpty
                    ? const KvShimmer(child: KvSkeleton(height: 110, radius: Kv.radius))
                    : KvCard(
                        onTap: () => _pickAddress(saved),
                        child: _AddressSummary(
                          label: selected?.label,
                          isDefault: selected?.isDefault ?? false,
                          address: _formAddress,
                        ),
                      ),
            action: saved.isEmpty ? null : (showForm ? 'Use saved' : 'Change'),
            onAction: saved.isEmpty
                ? null
                : () => showForm ? _selectSaved(selected ?? saved.first) : _pickAddress(saved),
          ),
          section(
            'Items ($count)',
            KvCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      ItemThumb(image: item.imageData, size: 52, voucher: item.isGiftVoucher),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                              [
                                'Qty ${item.quantity}',
                                if (item.variantWeight != null) item.variantWeight!,
                                if (item.isGiftVoucher) 'Gift voucher',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12, color: Kv.muted)),
                        ]),
                      ),
                      Text(formatInr(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          section(
            'Offers & gifting',
            KvCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                if (_appliedCode != null)
                  ListTile(
                    leading: const Icon(Icons.local_offer_rounded, color: Kv.success),
                    title: Text('$_appliedCode applied', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: summary.discount > 0 ? Text('You save ${formatInr(summary.discount)}') : null,
                    trailing: TextButton(onPressed: _removeCoupon, child: const Text('Remove')),
                  )
                else
                  ListTile(
                    onTap: _busy ? null : _openCoupon,
                    leading: const Icon(Icons.local_offer_outlined, color: Kv.ink),
                    title: const Text('Apply coupon'),
                    trailing: const Icon(Icons.chevron_right, color: Kv.subtle),
                  ),
                const Divider(indent: 56),
                SwitchListTile(
                  value: wrap.enabled,
                  onChanged: (v) =>
                      ref.read(giftWrapProvider.notifier).state = GiftWrap(enabled: v, message: wrap.message),
                  secondary: const Icon(Icons.redeem_rounded, color: Kv.gold),
                  title: Text('Gift wrap · ${formatInr(giftWrapFee)}'),
                  subtitle: Text(
                    !wrap.enabled
                        ? 'Signature gift box with ribbon'
                        : wrap.message.trim().isEmpty
                            ? 'No gift message'
                            : '“${wrap.message.trim()}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          section(
            'Price details',
            KvCard(
              child: PriceDetails(
                lines: [
                  PriceLine.amount('Subtotal (before GST)', summary.subtotal),
                  if (summary.discount > 0) PriceLine.amount('Coupon discount', summary.discount, discount: true),
                  PriceLine.amount('GST (${percentLabel(gstPercent)}%)', summary.gst),
                  hasDestination
                      ? PriceLine.amount('Delivery', summary.deliveryCharge)
                      : const PriceLine('Delivery', 'Add an address', muted: true),
                  if (wrap.enabled) PriceLine.amount('Gift wrap', giftWrapFee),
                ],
                totalLabel: 'Total',
                total: estimate,
                footnote: 'Final amount is confirmed before payment, at today’s metal rate.',
              ),
            ),
          ),
          const KvCard(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, color: Kv.success, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Secure online payment · UPI, cards, net banking and wallets via Razorpay',
                    style: TextStyle(fontSize: 13, color: Kv.muted)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(
          onPressed: _busy ? null : _pay,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Pay ${formatInr(estimate)}'),
        ),
      ),
    );
  }
}

/// Code field + Apply; shows the server's refusal inline and closes on success.
class _CouponSheet extends StatefulWidget {
  const _CouponSheet({required this.apply});
  final Future<String?> Function(String code) apply;

  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await widget.apply(_ctrl.text);
    if (!mounted) return;
    if (message == null) return Navigator.pop(context);
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _apply(),
              decoration: InputDecoration(labelText: 'Coupon code', errorText: _error),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _busy ? null : _apply,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 52)),
            child: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
        ]),
      );
}

class _AddressSummary extends StatelessWidget {
  const _AddressSummary({required this.address, this.label, this.isDefault = false});

  final Address address;
  final String? label;
  final bool isDefault;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.location_on_outlined, color: Kv.blue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(address.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (label?.isNotEmpty == true) StatusPill(label!),
              if (isDefault) const StatusPill('Default', tone: PillTone.info),
            ]),
            const SizedBox(height: 4),
            Text('${address.address}\n${address.city}, ${address.state} ${address.pincode}',
                style: const TextStyle(color: Kv.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 4),
            Text(address.phone, style: const TextStyle(color: Kv.muted, fontSize: 13)),
          ]),
        ),
      ]);
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({required this.address, required this.selected, required this.onTap});

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Kv.blueSoft : Kv.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Kv.cardRadius,
          side: BorderSide(color: selected ? Kv.blue : Kv.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _AddressSummary(address: address, label: address.label, isDefault: address.isDefault),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? Kv.blue : Kv.subtle),
            ]),
          ),
        ),
      );
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
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Final amounts, priced at today’s metal rate.', style: TextStyle(color: Kv.muted, fontSize: 13)),
          const SizedBox(height: 16),
          if (subtotalChanged) ...[
            KvCard(
              color: Kv.warningSoft,
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.trending_up_rounded, color: Kv.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prices changed since you added these items '
                    '(${formatInr(localSubtotal)} → ${formatInr(breakdown.subtotal)}). '
                    "Today's metal rate applies.",
                    style: const TextStyle(color: Color(0xFF7C3A06), fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          KvCard(child: BreakdownTable(breakdown: breakdown)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: Text('Pay ${formatInr(amount)}'),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => KvCard(
        color: Kv.dangerSoft,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: Kv.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13))),
        ]),
      );
}
