import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/savings_models.dart';

// kv-ui PassbookView.tsx formatters: en-IN grouping, money up to 2dp, grams exactly 3dp.
final _money = NumberFormat('#,##,##0.##', 'en_IN');
final _grams = NumberFormat('#,##,##0.000', 'en_IN');
String passbookMoney(num n) => _money.format(n);
String passbookGrams(num n) => _grams.format(n);

/// JS `String(number)`: no trailing ".0" on whole numbers.
String jsNumber(num n) => n == n.truncate() ? n.toInt().toString() : n.toString();

int _ms(String iso) => DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;

/// `toLocaleDateString('en-IN', ...)` with en-IN's "Sept" (the default intl locale says "Sep").
String enInDate(String? iso, String pattern) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return 'Invalid Date';
  return DateFormat(pattern).format(d.toLocal()).replaceFirst('Sep ', 'Sept ');
}

String _date(String iso) => enInDate(iso, 'dd MMM yy');

/// Payments oldest first; ties keep server order (JS sort is stable, Dart's is not).
List<SavingsPayment> _byPaidAt(List<SavingsPayment> payments) {
  final indexed = payments.indexed.toList()
    ..sort((a, b) {
      final c = _ms(a.$2.paidAt).compareTo(_ms(b.$2.paidAt));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final (_, p) in indexed) p];
}

const _ink = Color(0xFF111827); // gray-900
const _gray50 = Color(0xFFF9FAFB);
const _gray300 = Color(0xFFD1D5DB);
const _gray400 = Color(0xFF9CA3AF);
const _gray500 = Color(0xFF6B7280);
const _gray600 = Color(0xFF4B5563);
const _gray800 = Color(0xFF1F2937);

/// Shop letterhead shared by the passbook and the payment receipt.
class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key, this.title = 'Ledger Statement'});

  final String title;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 12, color: _gray600);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _gray800, width: 2))),
      child: Column(children: [
        const Text('KV Silver Zone',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        const Text('14, Rajaram St, Gnanamoorthy Nagar Extn, Town Planning Colony, Ambattur, Chennai 600053',
            textAlign: TextAlign.center, style: small),
        const Text('Mobile: (+91) 88256 49680', textAlign: TextAlign.center, style: small),
        const SizedBox(height: 8),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
      ]),
    );
  }
}

/// The printable passbook, matching the shop's paper ledger: every collection converted to
/// grams at that day's rate with a running cumulative weight. DIWALI schemes (a fixed hamper,
/// not grams) use the card's Month/Date/Amount layout. Always black on white, like the web's.
class PassbookView extends StatelessWidget {
  const PassbookView({super.key, required this.scheme, this.userName, this.userPhone, this.userAddress});

  final SavingsEnrollment scheme;
  final String? userName;
  final String? userPhone;
  final String? userAddress;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'Inter', color: _ink, fontSize: 14),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ShopHeader(),
          _customerDetails(),
          ...(scheme.schemeType == 'DIWALI' ? _diwali() : _ledger()),
          const SizedBox(height: 16),
          const Text('This is a computer-generated passbook. No signature required. · KV Silver Zone',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _gray400)),
        ]),
      ),
    );
  }

  Widget _customerDetails() {
    Widget cell(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _gray500)),
            const SizedBox(width: 8),
            Expanded(child: Text(': $value', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    TableRow row(Widget a, Widget b) =>
        TableRow(children: [Padding(padding: const EdgeInsets.only(right: 32), child: a), b]);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: _gray300)),
      child: Table(children: [
        row(cell('Name', userName ?? '—'),
            cell('Ticket No', scheme.passbookNumber ?? 'Pending (issued after first payment)')),
        row(cell('Address', userAddress ?? '—'), cell('CD', _date(scheme.startDate))),
        row(cell('Mobile No', userPhone ?? '—'), cell('Monthly Amount', passbookMoney(scheme.monthlyAmount))),
      ]),
    );
  }

  /// One bordered table row; [cells] are (text, flex, align). Borders collapse like the web's.
  static Widget _row(List<(String, int, TextAlign)> cells,
      {bool header = false, bool footer = false, int? boldFrom, bool first = false}) {
    const side = BorderSide(color: _gray300);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, (text, flex, align)) in cells.indexed)
          Expanded(
            flex: flex,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: header || footer ? 6 : 4),
              decoration: BoxDecoration(
                color: header || footer ? _gray50 : null,
                border: Border(
                    top: first ? side : BorderSide.none,
                    left: i == 0 ? side : BorderSide.none,
                    right: side,
                    bottom: side),
              ),
              child: Text(text,
                  textAlign: align,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: header || footer
                          ? FontWeight.w600
                          : (boldFrom != null && i >= boldFrom ? FontWeight.w500 : null))),
            ),
          ),
      ]),
    );
  }

  // The web's colSpan row: one cell spanning the whole table.
  static Widget _emptyRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: _gray300),
                right: BorderSide(color: _gray300),
                bottom: BorderSide(color: _gray300))),
        child: const Text('No collections recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _gray500, fontStyle: FontStyle.italic)),
      );

  Widget _totalPaid(String value) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _gray50, borderRadius: BorderRadius.circular(4)),
        child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8, children: [
          const Text('Total Paid to Date', style: TextStyle(color: _gray600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _box(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(border: Border.all(color: _gray300), borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  static Widget _li(String text) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(text));

  List<Widget> _ledger() {
    const r = TextAlign.right, c = TextAlign.center;
    var cumulative = 0.0;
    final rows = [
      for (final (i, p) in _byPaidAt(scheme.payments).indexed)
        (
          no: i + 1,
          p: p,
          total: p.materialWeight + p.devidentMaterialWeight,
          cumulative: cumulative += p.materialWeight + p.devidentMaterialWeight,
        ),
    ];
    final finalCumulative = rows.isEmpty ? 0.0 : rows.last.cumulative;
    double sum(double Function(SavingsPayment) f) => rows.fold(0.0, (s, x) => s + f(x.p));

    const flex = [4, 9, 8, 8, 9, 8, 9, 10, 8, 9];
    final mb = scheme.maturityBenefits;
    final hasMaturityBenefits =
        mb != null && ((mb.goldCoinValue ?? 0) != 0 || (mb.silverGrams ?? 0) != 0 || mb.gifts.isNotEmpty);
    final cancellation = scheme.cancellation;

    return [
      _row([
        for (final (i, h) in const [
          'No',
          'Collection Date',
          'Collection',
          'Material Rate',
          'Material Weight (Grm)',
          'Devident',
          'Devident Material Rate',
          'Devident Material Weight (Grm)',
          'Total',
          'Cumulative',
        ].indexed)
          (h, flex[i], c),
      ], header: true, first: true),
      if (rows.isEmpty) _emptyRow(),
      for (final x in rows)
        _row([
          ('${x.no}', flex[0], c),
          (_date(x.p.paidAt), flex[1], c),
          (passbookMoney(x.p.amount), flex[2], r),
          (passbookMoney(x.p.materialRate), flex[3], r),
          (passbookGrams(x.p.materialWeight), flex[4], r),
          (passbookMoney(x.p.devidentAmount), flex[5], r),
          (passbookMoney(x.p.devidentMaterialRate), flex[6], r),
          (passbookGrams(x.p.devidentMaterialWeight), flex[7], r),
          (passbookGrams(x.total), flex[8], r),
          (passbookGrams(x.cumulative), flex[9], r),
        ], boldFrom: 8),
      if (rows.isNotEmpty)
        _row([
          ('Total', flex[0] + flex[1], c),
          (passbookMoney(sum((p) => p.amount)), flex[2], r),
          (passbookMoney(sum((p) => p.materialRate)), flex[3], r),
          (passbookGrams(sum((p) => p.materialWeight)), flex[4], r),
          (passbookMoney(sum((p) => p.devidentAmount)), flex[5], r),
          (passbookMoney(sum((p) => p.devidentMaterialRate)), flex[6], r),
          (passbookGrams(sum((p) => p.devidentMaterialWeight)), flex[7], r),
          (passbookGrams(rows.fold(0.0, (s, x) => s + x.total)), flex[8], r),
          (passbookGrams(finalCumulative), flex[9], r),
        ], footer: true),
      _totalPaid('₹${passbookMoney(scheme.totalPaid)} · ${passbookGrams(finalCumulative)} g '
          '${scheme.isGold ? 'gold' : 'silver'}'),
      if (hasMaturityBenefits)
        _box('Maturity Benefits', [
          if ((mb.goldCoinValue ?? 0) != 0) _li('₹${passbookMoney(mb.goldCoinValue!)} — Gold Coin'),
          if ((mb.silverGrams ?? 0) != 0)
            _li('${passbookGrams(mb.silverGrams!)} Grams — Silver Coin/Article'),
          for (final g in mb.gifts) _li(g),
        ]),
      if (cancellation != null)
        _box('Scheme Cancelled — ${_date(cancellation.cancelledAt)}', [
          Table(children: [
            for (final (label, value, strong) in [
              ('Amount Paid', cancellation.amountPaidAtCancellation, false),
              ('Forfeited (${jsNumber(cancellation.penaltyPercent)}%)', cancellation.penaltyAmount, false),
              if (cancellation.giftsValueDeducted > 0)
                ('Gifts Already Received', cancellation.giftsValueDeducted, false),
              ('Net Redeemable (goods only)', cancellation.netRedeemable, true),
            ])
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(label,
                      style: TextStyle(color: _gray600, fontWeight: strong ? FontWeight.w600 : null)),
                ),
                Text('₹${passbookMoney(value)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: strong ? FontWeight.w600 : null)),
              ]),
          ]),
        ]),
    ];
  }

  List<Widget> _diwali() {
    const flex = [1, 1, 1, 1];
    final rows = _byPaidAt(scheme.payments);
    final mb = scheme.maturityBenefits;
    final computed = (mb?.computedAt ?? '').isNotEmpty;
    final showHamper = mb != null && (mb.gifts.isNotEmpty || (mb.silverGrams ?? 0) != 0 || computed);
    return [
      _row([
        for (final h in const ['Month', 'Date', 'Amount', 'Method']) (h, 1, TextAlign.center)
      ], header: true, first: true),
      if (rows.isEmpty) _emptyRow(),
      for (final (i, p) in rows.indexed)
        _row([
          ('${i + 1}', flex[0], TextAlign.center),
          (_date(p.paidAt), flex[1], TextAlign.center),
          (passbookMoney(p.amount), flex[2], TextAlign.right),
          (p.method == 'CASH' ? 'Cash' : 'Online', flex[3], TextAlign.center),
        ]),
      _totalPaid('₹${passbookMoney(scheme.totalPaid)}'),
      if (showHamper)
        _box('Diwali Redemption Hamper', [
          if (computed && (mb.goldGrams ?? 0) != 0)
            _li('${passbookGrams(mb.goldGrams!)} Grams — Gold'
                '${(mb.goldRatePerGram ?? 0) != 0 ? ' (₹${passbookMoney(mb.goldRatePerGram!)}/g)' : ''}, worth '
                '₹${passbookMoney(mb.goldCoinValue ?? 0)}'),
          if ((mb.silverGrams ?? 0) != 0)
            _li('${passbookGrams(mb.silverGrams!)} Grams — Silver Coin'
                '${computed && (mb.silverValue ?? 0) != 0 ? ' — worth ₹${passbookMoney(mb.silverValue!)}' : ''}'),
          if (computed && (mb.giftsValue ?? 0) != 0)
            _li('Gift Hamper — worth ₹${passbookMoney(mb.giftsValue!)}'),
          for (final g in mb.gifts) _li(g),
          if (!computed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Gold value will be computed at redemption, once all installments are complete.',
                  style: TextStyle(fontSize: 12, color: _gray500, fontStyle: FontStyle.italic)),
            ),
        ]),
    ];
  }
}
