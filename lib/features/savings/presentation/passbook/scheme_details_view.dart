import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/savings_models.dart';
import 'passbook_view.dart';
import 'print_boundary.dart';

// kv-ui SchemeDetailsView.tsx formatters.
final _money = NumberFormat('#,##,##0.##', 'en_IN');
String _inr(num n) => '₹${_money.format(n)}';
String _grams(num n) => '${n.toStringAsFixed(3)} g';
String _date(String? iso) => iso == null || iso.isEmpty ? '—' : enInDate(iso, 'dd MMM y');
String _monthLabel(Installment i) => i.monthNumber == null ? 'Bonus month' : 'Month ${i.monthNumber}';

/// Customer-facing month-by-month view of a FIXED savings scheme: progress, summary tiles and
/// a card per installment with a printable receipt. The full ledger stays in PassbookView.
class SchemeDetailsView extends StatefulWidget {
  const SchemeDetailsView(
      {super.key, required this.scheme, this.userName, this.userPhone, this.onPay, this.paying = false});

  final SavingsEnrollment scheme;
  final String? userName;
  final String? userPhone;

  /// Null hides the Pay button (e.g. staff viewing someone else's passbook).
  final VoidCallback? onPay;
  final bool paying;

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
    final s = summarizeScheme(scheme);
    final metalName = scheme.isGold ? 'Gold' : 'Silver';
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    final name = (widget.userName ?? '').isEmpty ? null : widget.userName;
    final phone = (widget.userPhone ?? '').isEmpty ? null : widget.userPhone;
    final wide = MediaQuery.sizeOf(context).width >= 640;

    Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: muted),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ]),
        );

    final tiles = [
      _Tile(icon: Icons.account_balance_wallet_outlined, label: 'Total paid', value: _inr(s.totalPaid)),
      if (s.hasGrams)
        _Tile(
            icon: Icons.scale_outlined,
            label: 'Total ${metalName.toLowerCase()}',
            value: _grams(s.totalGrams)),
      _Tile(
          icon: Icons.calendar_month_outlined,
          label: 'Paid months',
          value: '${s.paidMonths} of ${s.totalMonths}'),
      _Tile(icon: Icons.hourglass_empty, label: 'Pending months', value: '${s.pendingMonths}'),
    ];

    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.05),
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(scheme.planName ?? scheme.schemeType,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    scheme.passbookNumber != null
                        ? 'Passbook #${scheme.passbookNumber}'
                        : 'Passbook issued after first payment',
                    style: muted),
                if (name != null || phone != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
                      if (name != null)
                        TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (name != null && phone != null)
                        TextSpan(text: ' · ', style: TextStyle(color: cs.onSurfaceVariant)),
                      if (phone != null)
                        TextSpan(text: 'Mobile +91 $phone', style: TextStyle(color: cs.onSurfaceVariant)),
                    ])),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(999)),
              child: Text(scheme.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _ProgressRing(percent: s.progressPercent, label: '${s.paidMonths} of ${s.totalMonths} paid'),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                field('Joined', _date(scheme.startDate)),
                field('Matures', _date(scheme.maturityDate)),
                field('Monthly amount', _inr(scheme.monthlyAmount)),
              ]),
            ),
          ]),
          if (widget.onPay != null && s.nextMonth != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton(
                onPressed: widget.paying ? null : widget.onPay,
                child: widget.paying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Pay Month ${s.nextMonth} of ${s.totalMonths} (${_inr(scheme.monthlyAmount)})'),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      // Summary: 2 columns, 4 from the sm breakpoint.
      LayoutBuilder(builder: (context, c) {
        final cols = wide ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
            spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
      }),
      if (scheme.cancellation != null) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.05),
            border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
            TextSpan(text: 'Cancelled on ${_date(scheme.cancellation!.cancelledAt)} — net redeemable '),
            TextSpan(
                text: _inr(scheme.cancellation!.netRedeemable),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: ' (goods only).'),
          ])),
        ),
      ],
      const SizedBox(height: 20),
      // Month-wise history
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Payment history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      if (s.installments.isEmpty)
        _DashedBox(
          color: cs.outline,
          child: Text('No payments yet.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        )
      else
        for (final (idx, inst) in s.installments.reversed.indexed)
          Padding(
            padding: EdgeInsets.only(top: idx == 0 ? 0 : 12),
            child: _InstallmentCard(
              key: ValueKey('installment-${inst.payment.id ?? idx}'),
              inst: inst,
              hasGrams: s.hasGrams,
              onReceipt: () => _printReceipt(inst),
            ),
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
      ColoredBox(color: cs.surface, child: content),
    ]);
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.percent, required this.label});
  final int percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: '$percent% complete, $label',
      excludeSemantics: true,
      child: SizedBox(
        width: 112,
        height: 112,
        child: CustomPaint(
          painter: _RingPainter(percent / 100, track: cs.surfaceContainerHighest, progress: cs.primary),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$percent%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, {required this.track, required this.progress});
  final double fraction;
  final Color track, progress;

  @override
  void paint(Canvas canvas, Size size) {
    // The web's SVG: r=42 with a 9-wide stroke in a 100x100 viewBox, starting at 12 o'clock.
    final k = size.width / 100;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 42 * k);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * k;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * fraction,
          false,
          paint
            ..color = progress
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.progress != progress;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surface, border: Border.all(color: cs.outline), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({super.key, required this.inst, required this.hasGrams, required this.onReceipt});
  final Installment inst;
  final bool hasGrams;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = inst.payment;
    final isBonus = inst.monthNumber == null;
    final muted = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(label, style: muted, textAlign: TextAlign.center),
            Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ]),
        );

    final (modeIcon, modeText) = isBonus
        ? (Icons.toll_outlined, 'Credited by KV Silver Zone')
        : p.method == 'CASH'
            ? (Icons.storefront_outlined, 'Paid in store')
            : (Icons.smartphone, 'Paid online');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surface, border: Border.all(color: cs.outline), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: isBonus
                ? Icon(Icons.card_giftcard, size: 16, color: cs.onPrimary)
                : Text('${inst.monthNumber}'.padLeft(2, '0'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_monthLabel(inst), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(_date(p.paidAt), style: muted),
            ]),
          ),
          if (p.id != null)
            IconButton(
              tooltip: 'Download receipt for ${_monthLabel(inst)}',
              icon: const Icon(Icons.download, size: 16),
              onPressed: onReceipt,
            ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasGrams) stat('Rate /g', _inr(isBonus ? p.devidentMaterialRate : p.materialRate)),
          if (hasGrams) const SizedBox(width: 8),
          stat(isBonus ? 'Bonus' : 'Amount', _inr(isBonus ? p.devidentAmount : p.amount)),
          if (hasGrams) const SizedBox(width: 8),
          if (hasGrams) stat('Weight', _grams(inst.grams)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline))),
          child: Row(children: [
            Icon(modeIcon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(child: Text(modeText, style: muted)),
            if (p.id != null) Text('Receipt No. ${p.id}', style: muted),
          ]),
        ),
      ]),
    );
  }
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

/// Tailwind `border border-dashed rounded-lg p-6`.
class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _DashPainter(color), child: Padding(padding: const EdgeInsets.all(24), child: child));
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
