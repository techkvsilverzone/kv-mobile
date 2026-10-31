import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/format/currency.dart';
import '../../data/models/order.dart';

/// Company details printed on the tax invoice (`GET /invoice-config`).
class InvoiceConfig {
  const InvoiceConfig({
    this.companyName = 'KV Silver Zone',
    this.gstin = '',
    this.companyAddress = '',
  });

  final String companyName;
  final String gstin;
  final String companyAddress;

  /// The web's `parseConfig`, which also accepts a `{status, data}` envelope.
  factory InvoiceConfig.fromJson(dynamic raw) {
    final m = raw is Map && raw['data'] is Map ? raw['data'] as Map : (raw is Map ? raw : const {});
    final name = m['companyName']?.toString() ?? '';
    return InvoiceConfig(
      companyName: name.isEmpty ? 'KV Silver Zone' : name,
      gstin: m['gstin']?.toString() ?? '',
      companyAddress: m['companyAddress']?.toString() ?? '',
    );
  }
}

/// Falls back to the default on failure, as the web query does.
final invoiceConfigProvider = FutureProvider<InvoiceConfig>((ref) async {
  try {
    return InvoiceConfig.fromJson(await ref.watch(apiClientProvider).get('/invoice-config'));
  } catch (_) {
    return const InvoiceConfig();
  }
});

/// Totals exactly as kv-ui InvoiceView.tsx derives them.
class InvoiceTotals {
  InvoiceTotals(Order order)
      : subtotal = order.items.fold(0.0, (s, i) => s + i.unitPrice * i.quantity),
        discount = order.couponDiscount,
        tax = order.taxAmount,
        total = order.grandTotal;

  final double subtotal, discount, tax, total;

  double get gstPercent {
    final taxable = subtotal - discount;
    return taxable > 0 ? (tax / taxable * 1000).round() / 10 : 3;
  }
}

/// Server invoice number, else the order id's last 10 characters.
String invoiceNumberOf(Order o) => o.invoiceNumber ??
    (o.id.length <= 10 ? o.id : o.id.substring(o.id.length - 10)).toUpperCase();

String invoicePaymentLabel(String method) => switch (method.toLowerCase()) {
      'cash' => 'Cash',
      'upi' => 'UPI',
      'card' => 'Card',
      'razorpay' => 'Online (Razorpay)',
      'cod' => 'Cash on delivery',
      _ => method,
    };

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// The printable tax invoice. Always black on white, like the web's, whatever
/// the app theme — it is a document, not a screen.
class InvoiceView extends StatelessWidget {
  const InvoiceView(
      {super.key, required this.order, required this.config, this.customerName, this.customerEmail});

  final Order order;
  final InvoiceConfig config;
  final String? customerName;
  final String? customerEmail;

  static const _ink = Color(0xFF111827); // gray-900
  static const _grey500 = Color(0xFF6B7280);
  static const _grey600 = Color(0xFF4B5563);

  @override
  Widget build(BuildContext context) {
    final t = InvoiceTotals(order);
    final a = order.address;
    final date = order.createdAt == null ? '' : DateFormat('dd MMM y').format(order.createdAt!.toLocal());
    const small = TextStyle(fontSize: 11, color: _grey500);
    const label = TextStyle(fontSize: 11, color: _grey500, letterSpacing: 0.6);
    const body = TextStyle(fontSize: 13, color: _grey600);

    Widget totalRow(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: bold
                        ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)
                        : body)),
            Text(v,
                style: TextStyle(
                    fontSize: bold ? 15 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: _ink)),
          ]),
        );

    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'Inter', color: _ink, fontSize: 13),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(config.companyName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const Text('Tax Invoice', style: small),
                  if (config.companyAddress.isNotEmpty) Text(config.companyAddress, style: small),
                  if (config.gstin.isNotEmpty) Text('GSTIN: ${config.gstin}', style: small),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Invoice #${invoiceNumberOf(order)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Date: $date', style: const TextStyle(color: _grey500)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          // Bill to / Ship to (or Sold at)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BILL TO', style: label),
                const SizedBox(height: 4),
                Text(customerName ?? a?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (customerEmail != null) Text(customerEmail!, style: body),
                if ((a?.phone ?? '').isNotEmpty) Text(a!.phone, style: body),
                if (order.isInStore && (a?.line1 ?? '').isNotEmpty) Text(a!.line1, style: body),
              ]),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.isInStore ? 'SOLD AT' : 'SHIP TO', style: label),
                const SizedBox(height: 4),
                if (order.isInStore)
                  Text(
                      '${(order.saleLocation ?? '').isEmpty ? 'In-store' : order.saleLocation}'
                      '${order.soldByName == null ? '' : '\nBilled by ${order.soldByName}'}',
                      style: body.copyWith(color: const Color(0xFF374151), height: 1.5))
                else if (a != null)
                  Text('${a.line1},\n${a.city}, ${a.state} – ${a.pincode}',
                      style: body.copyWith(color: const Color(0xFF374151), height: 1.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          // Line items
          Table(
            columnWidths: const {
              0: FixedColumnWidth(24),
              1: FlexColumnWidth(3),
              2: FixedColumnWidth(36),
              3: FlexColumnWidth(1.4),
              4: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                children: [
                  for (final (h, align) in const [
                    ('#', TextAlign.left),
                    ('ITEM', TextAlign.left),
                    ('QTY', TextAlign.center),
                    ('UNIT PRICE', TextAlign.right),
                    ('TOTAL', TextAlign.right),
                  ])
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(h, textAlign: align, style: const TextStyle(fontSize: 10, color: _grey500))),
                ],
              ),
              for (final (i, item) in order.items.indexed)
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                  children: [
                    for (final (v, align, w, color) in [
                      ('${i + 1}', TextAlign.left, FontWeight.w400, const Color(0xFF9CA3AF)),
                      (item.productName, TextAlign.left, FontWeight.w400, _ink),
                      ('${item.quantity}', TextAlign.center, FontWeight.w400, _ink),
                      (formatInr(item.unitPrice), TextAlign.right, FontWeight.w400, _ink),
                      (formatInr(item.unitPrice * item.quantity), TextAlign.right, FontWeight.w500, _ink),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(v,
                            textAlign: align,
                            style: TextStyle(fontSize: 12, fontWeight: w, color: color)),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Totals
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 224,
              child: Column(children: [
                totalRow('Subtotal', formatInr(t.subtotal)),
                if (t.discount > 0)
                  totalRow('Discount${order.couponCode == null ? '' : ' (${order.couponCode})'}',
                      '−${formatInr(t.discount)}'),
                totalRow('GST (${_pct(t.gstPercent)}%)', formatInr(t.tax)),
                // So the rows add up to the total.
                if (order.deliveryFee > 0) totalRow('Delivery', formatInr(order.deliveryFee)),
                if (order.giftWrapFee > 0) totalRow('Gift wrapping', formatInr(order.giftWrapFee)),
                const Divider(color: Color(0xFFD1D5DB), height: 16),
                totalRow('Total', formatInr(t.total), bold: true),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Payment Method: ', style: TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: invoicePaymentLabel(order.paymentMethod)),
          ]), style: body),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 8),
          const Text(
            'Thank you for shopping with KV Silver Zone. This is a computer-generated invoice. No signature required.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ]),
      ),
    );
  }
}
