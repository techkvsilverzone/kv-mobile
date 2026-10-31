import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../data/savings_models.dart';
import '../widgets/scheme_widgets.dart';
import 'passbook_view.dart';
import 'print_boundary.dart';

// kv-ui SchemeDetailsView.tsx formatters.
final _money = NumberFormat('#,##,##0.##', 'en_IN');
String _inr(num n) => '₹${_money.format(n)}';
String _grams(num n) => '${n.toStringAsFixed(3)} g';
String _date(String? iso) => iso == null || iso.isEmpty ? '—' : enInDate(iso, 'dd MMM y');
String _monthLabel(Installment i) => i.monthNumber == null ? 'Bonus month' : 'Month ${i.monthNumber}';

const _light = Color(0xFFAFB6C2);

/// App-style passbook: a summary header (paid, grams, progress, maturity) and the installment
/// list with a printable receipt per payment. The black-on-white ledger stays in PassbookView.
class SchemeDetailsView extends StatefulWidget {
  const SchemeDetailsView({super.key, required this.scheme, this.userName, this.userPhone, this.flexible = false});

  final SavingsEnrollment scheme;
  final String? userName;
  final String? userPhone;

  /// FLEXIBLE (KV Smart) plans have no month count: payments are listed by date with a running total.
  final bool flexible;

  @override
  State<SchemeDetailsView> createState() => _SchemeDetailsViewState();
}

class _SchemeDetailsViewState extends State<SchemeDetailsView> {
  final _receiptKey = GlobalKey();
  Installment? _receiptFor;

  void _printReceipt(Installment inst) {
    setState(() => _receiptFor = inst);
    // Print once the receipt has been laid out and painted (the web's useEffect).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await printBoundary(context, _receiptKey, 'KV-Silver-Zone-Receipt-${inst.payment.id ?? ''}');
      if (mounted) setState(() => _receiptFor = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final flexible = widget.flexible;
    final s = summarizeScheme(scheme);
    final metalName = scheme.isGold ? 'Gold' : 'Silver';
    final name = (widget.userName ?? '').isEmpty ? null : widget.userName;
    final phone = (widget.userPhone ?? '').isEmpty ? null : widget.userPhone;

    // Running grams, oldest first, for the flexible plan's ledger-style rows.
    final cumulative = <Installment, double>{};
    var run = 0.0;
    for (final i in s.installments) {
      cumulative[i] = run += i.grams;
    }

    final header = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Kv.ink, borderRadius: Kv.cardRadius),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(scheme.planName ?? scheme.schemeType,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(scheme.passbookNumber != null ? 'Passbook ${scheme.passbookNumber}' : 'Passbook issued after first payment',
                  style: const TextStyle(color: _light, fontSize: 12.5)),
              if (name != null || phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text([if (name != null) name, if (phone != null) '+91 $phone'].join(' · '),
                      style: const TextStyle(color: _light, fontSize: 12.5)),
                ),
            ]),
          ),
          StatusPill(scheme.status, tone: schemeStatusTone(scheme.status)),
        ]),
        const SizedBox(height: 18),
        const Text('Total paid', style: TextStyle(color: _light, fontSize: 12.5, fontWeight: FontWeight.w500)),
        Text(_inr(s.totalPaid),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        if (s.hasGrams)
          Text('${_grams(s.totalGrams)} ${metalName.toLowerCase()}',
              style: const TextStyle(color: Color(0xFFE3C98F), fontSize: 15, fontWeight: FontWeight.w600)),
        if (!flexible) ...[
          const SizedBox(height: 16),
          Row(children: [
            Text('${s.paidMonths} of ${s.totalMonths} months paid',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (s.pendingMonths > 0)
              Text('${s.pendingMonths} to go', style: const TextStyle(color: _light, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          KvProgressBar(
            value: s.progressPercent / 100,
            color: scheme.isGold ? Kv.gold : const Color(0xFF6FA4E0),
            track: const Color(0xFF3A3536),
            semanticsLabel: '${s.progressPercent}% complete, ${s.paidMonths} of ${s.totalMonths} paid',
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: StatCell('Joined', _date(scheme.startDate), light: true)),
          Expanded(child: StatCell(flexible ? 'Min payment' : 'Monthly', _inr(scheme.monthlyAmount), light: true)),
          Expanded(child: StatCell('Matures', _date(scheme.maturityDate), light: true, end: true)),
        ]),
      ]),
    );

    final rows = <Widget>[
      if (!flexible && scheme.isActive && s.nextMonth != null)
        _Row(
          leading: _Badge(text: '${s.nextMonth}'.padLeft(2, '0'), upcoming: true),
          title: 'Month ${s.nextMonth}',
          lines: const [['Not paid yet']],
          trailing: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_inr(scheme.monthlyAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: Kv.muted)),
              const SizedBox(height: 4),
              const StatusPill('Due', tone: PillTone.warning),
            ]),
          ),
        ),
      for (final (idx, inst) in s.installments.reversed.indexed)
        _installmentRow(inst, idx, s.hasGrams, cumulative[inst]),
    ];

    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      if (scheme.cancellation != null) ...[
        const SizedBox(height: 12),
        KvCard(
          color: Kv.dangerSoft,
          child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14, color: Color(0xFF8F1D1D)), children: [
            TextSpan(text: 'Cancelled on ${_date(scheme.cancellation!.cancelledAt)}. Net redeemable '),
            TextSpan(
                text: _inr(scheme.cancellation!.netRedeemable), style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' (goods only).'),
          ])),
        ),
      ],
      const SizedBox(height: Kv.gap),
      SectionHeader(
        title: 'Payment history',
        subtitle: s.installments.isEmpty
            ? null
            : '${s.installments.length} ${s.installments.length == 1 ? 'payment' : 'payments'} · newest first',
        padding: const EdgeInsets.only(left: 2, bottom: 10),
      ),
      if (s.installments.isEmpty)
        const KvCard(
          child: EmptyState(
            compact: true,
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            message: 'Your first payment issues your passbook.',
          ),
        )
      else
        KvCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in rows.indexed) ...[if (i > 0) const Divider(indent: 64), r],
          ]),
        ),
    ]);

    // The receipt is painted underneath the (opaque) content so it can be rasterised unseen.
    return Stack(children: [
      if (_receiptFor != null)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeSemantics(
            child: RepaintBoundary(
                key: _receiptKey,
                child: _Receipt(
                    inst: _receiptFor!,
                    scheme: scheme,
                    summary: s,
                    userName: widget.userName,
                    userPhone: widget.userPhone)),
          ),
        ),
      ColoredBox(color: Kv.bg, child: content),
    ]);
  }

  Widget _installmentRow(Installment inst, int idx, bool hasGrams, double? runningGrams) {
    final p = inst.payment;
    final isBonus = inst.monthNumber == null;
    final mode = isBonus
        ? 'Credited by KV Silver Zone'
        : p.method == 'CASH'
            ? 'Paid in store'
            : 'Paid online';
    final rate = isBonus ? p.devidentMaterialRate : p.materialRate;
    return _Row(
      key: ValueKey('installment-${p.id ?? idx}'),
      leading: isBonus
          ? const _Badge(icon: Icons.card_giftcard_rounded, gold: true)
          : widget.flexible
              ? const _Badge(icon: Icons.south_west_rounded)
              : _Badge(text: '${inst.monthNumber}'.padLeft(2, '0')),
      title: widget.flexible && !isBonus ? _date(p.paidAt) : _monthLabel(inst),
      lines: [
        [if (!widget.flexible || isBonus) _date(p.paidAt), mode],
        [
          if (hasGrams) '${_inr(rate)}/g',
          if (hasGrams) _grams(inst.grams),
          if (hasGrams && widget.flexible && runningGrams != null) 'total ${_grams(runningGrams)}',
        ],
        [if (p.id != null) 'Receipt ${p.id}'],
      ],
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_inr(isBonus ? p.devidentAmount : p.amount),
            style: TextStyle(fontWeight: FontWeight.w700, color: isBonus ? Kv.success : Kv.ink)),
        if (p.id != null)
          IconButton(
            tooltip: 'Download receipt for ${_monthLabel(inst)}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.file_download_outlined, size: 20, color: Kv.muted),
            onPressed: () => _printReceipt(inst),
          ),
      ]),
    );
  }
}

/// Sticky pay bar for a passbook the signed-in customer owns.
class PassbookPayBar extends StatelessWidget {
  const PassbookPayBar({super.key, required this.scheme, required this.flexible, required this.paying, required this.onPay});
  final SavingsEnrollment scheme;
  final bool flexible, paying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final s = summarizeScheme(scheme);
    return BottomActionBar(
      leading: flexible
          ? BarTotal(label: 'Add to your savings', amount: scheme.monthlyAmount, note: 'minimum, any time')
          : BarTotal(
              label: 'Month ${s.nextMonth ?? s.paidMonths + 1} of ${s.totalMonths} due', amount: scheme.monthlyAmount),
      action: FilledButton(
        onPressed: paying ? null : onPay,
        style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
        child: paying
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Pay now'),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.text, this.icon, this.gold = false, this.upcoming = false});
  final String? text;
  final IconData? icon;
  final bool gold, upcoming;

  @override
  Widget build(BuildContext context) {
    final fg = gold ? Kv.gold : (upcoming ? Kv.muted : Kv.blueDark);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gold ? Kv.goldSoft : (upcoming ? Kv.surface : Kv.blueSoft),
        border: upcoming ? Border.all(color: Kv.line, width: 1.5) : null,
      ),
      child: text != null
          ? Text(text!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))
          : Icon(icon, size: 17, color: fg),
    );
  }
}

/// One timeline row: badge, title, dot-separated detail lines, trailing amount.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.leading, required this.title, required this.lines, required this.trailing});
  final Widget leading;
  final String title;
  final List<List<String>> lines;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              for (final line in lines)
                if (line.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(children: [
                      for (final (i, part) in line.indexed) ...[
                        if (i > 0) const Text(' · ', style: TextStyle(fontSize: 12.5, color: Kv.subtle)),
                        Text(part, style: const TextStyle(fontSize: 12.5, color: Kv.muted)),
                      ],
                    ]),
                  ),
            ]),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      );
}

/// The printable receipt for one installment; black on white like the passbook.
class _Receipt extends StatelessWidget {
  const _Receipt(
      {required this.inst, required this.scheme, required this.summary, this.userName, this.userPhone});
  final Installment inst;
  final SavingsEnrollment scheme;
  final SchemeSummary summary;
  final String? userName, userPhone;

  @override
  Widget build(BuildContext context) {
    final p = inst.payment;
    final bonus = inst.monthNumber == null;
    final metalName = scheme.isGold ? 'Gold' : 'Silver';
    final rows = [
      ('Receipt No', p.id ?? '—'),
      ('Passbook No', scheme.passbookNumber ?? '—'),
      ('Customer', userName ?? '—'),
      ('Mobile', userPhone ?? '—'),
      ('Plan', scheme.planName ?? scheme.schemeType),
      ('Installment', bonus ? 'Bonus month' : 'Month ${inst.monthNumber} of ${summary.totalMonths}'),
      ('Date', _date(p.paidAt)),
      (bonus ? 'Bonus amount' : 'Amount', _inr(bonus ? p.devidentAmount : p.amount)),
      if (summary.hasGrams) ...[
        ('$metalName rate /g', _inr(bonus ? p.devidentMaterialRate : p.materialRate)),
        ('$metalName credited', _grams(inst.grams)),
      ],
      ('Payment mode', bonus ? 'Bonus credit' : (p.method == 'CASH' ? 'Cash (in store)' : 'Online')),
      if ((p.razorpayPaymentId ?? '').isNotEmpty) ('Transaction ID', p.razorpayPaymentId!),
    ];
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF111827), fontSize: 14),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ShopHeader(title: 'Payment Receipt'),
          Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            children: [
              for (final (k, v) in rows)
                TableRow(
                  decoration:
                      const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                      child: Text(k, style: const TextStyle(color: Color(0xFF4B5563))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('This is a computer-generated receipt. No signature required. · KV Silver Zone',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }
}

