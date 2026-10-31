import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../application/installment_payer.dart';
import '../../data/savings_models.dart';

final _shortDate = DateFormat('d MMM y');

/// Local date for an ISO string, or null.
String? schemeDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? null : _shortDate.format(d.toLocal());
}

PillTone schemeStatusTone(String status) => switch (status) {
      'Active' => PillTone.success,
      'Completed' => PillTone.info,
      'Dropped' => PillTone.danger,
      _ => PillTone.neutral,
    };

/// Round metal badge: gold tint for gold plans, silver-grey otherwise.
class MetalBadge extends StatelessWidget {
  const MetalBadge({super.key, required this.gold, this.size = 44, this.icon = Icons.toll_rounded});
  final bool gold;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gold ? Kv.goldSoft : Theme.of(context).colorScheme.surfaceContainerHigh,
          border: Border.all(color: gold ? Kv.gold.withValues(alpha: 0.35) : Kv.line),
        ),
        child: Icon(icon, size: size * 0.5, color: gold ? Kv.gold : Kv.muted),
      );
}

/// Thin rounded progress bar.
class KvProgressBar extends StatelessWidget {
  const KvProgressBar({super.key, required this.value, this.color = Kv.blue, this.track, this.semanticsLabel});
  final double value;
  final Color color;
  final Color? track;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        excludeSemantics: semanticsLabel != null,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(999),
          color: color,
          backgroundColor: track ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
}

/// Label over value, used in stat rows.
class StatCell extends StatelessWidget {
  const StatCell(this.label, this.value, {super.key, this.end = false, this.light = false});
  final String label, value;
  final bool end;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: light ? const Color(0xFFAFB6C2) : Kv.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: light ? Colors.white : Kv.ink)),
        ],
      );
}

/// Bottom sheet asking how much to pay into a FLEXIBLE scheme (>= the scheme minimum).
Future<double?> showFlexAmountSheet(BuildContext context, SavingsEnrollment s) =>
    showKvSheet<double>(context, title: 'How much to pay?', builder: (_) => _FlexAmountSheet(scheme: s));

class _FlexAmountSheet extends StatefulWidget {
  const _FlexAmountSheet({required this.scheme});
  final SavingsEnrollment scheme;

  @override
  State<_FlexAmountSheet> createState() => _FlexAmountSheetState();
}

class _FlexAmountSheetState extends State<_FlexAmountSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.scheme.monthlyAmount;
    final amount = double.tryParse(_ctrl.text.trim());
    final valid = amount != null && amount >= min;
    final quick = {min, min * 2, min * 4, min * 10}.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Any amount from ${formatInr(min)}. It is converted to grams at today’s rate.',
            style: const TextStyle(color: Kv.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            errorText: _ctrl.text.isNotEmpty && !valid ? 'Minimum is ${formatInr(min)}' : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final q in quick)
            ActionChip(
              label: Text(formatInr(q)),
              onPressed: () => setState(() => _ctrl.text = q.toStringAsFixed(0)),
            ),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, amount) : null,
          child: Text(valid ? 'Pay ${formatInr(amount)}' : 'Pay'),
        ),
      ]),
    );
  }
}

/// Bottom sheet for the enrolment confirmation code. Resolves to the trimmed code.
Future<String?> showEnrollOtpSheet(BuildContext context, {required String channel}) =>
    showKvSheet<String>(context, title: 'Confirm your enrolment', builder: (_) => OtpSheet(channel: channel));

class OtpSheet extends StatefulWidget {
  const OtpSheet({super.key, required this.channel});
  final String channel;

  @override
  State<OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<OtpSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(widget.channel == 'email' ? Icons.mail_outline_rounded : Icons.chat_outlined, color: Kv.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.channel == 'email' ? 'We’ve emailed you a confirmation code.' : 'We’ve sent a code to your WhatsApp.',
              style: const TextStyle(color: Kv.muted),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 8),
          decoration: const InputDecoration(hintText: '••••••', labelText: 'Confirmation code'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => code.isEmpty ? null : Navigator.pop(context, code),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: code.isEmpty ? null : () => Navigator.pop(context, code),
          child: const Text('Confirm & enroll'),
        ),
      ]),
    );
  }
}

/// "My schemes" card: plan, passbook, status, progress, grams, maturity and the Pay action.
class SchemeCard extends StatelessWidget {
  const SchemeCard({
    super.key,
    required this.scheme,
    required this.flexible,
    required this.canPay,
    required this.paying,
    required this.onPay,
    required this.onOpen,
  });

  final SavingsEnrollment scheme;
  final bool flexible, canPay, paying;
  final VoidCallback onPay;

  /// Null until a passbook number is issued.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = scheme;
    final summary = summarizeScheme(s);
    final metal = s.isGold ? 'Gold' : 'Silver';
    final matures = schemeDate(s.maturityDate);
    final redemption = s.schemeType == 'DIWALI' && s.maturityBenefits?.computedAt != null ? s.maturityBenefits : null;
    final awaitingRedemption = s.schemeType == 'DIWALI' && s.status == 'Completed' && redemption == null;
    const spinner = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

    return KvCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          MetalBadge(gold: s.isGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(s.passbookNumber ?? 'Passbook after first payment',
                  style: const TextStyle(fontSize: 12.5, color: Kv.muted)),
            ]),
          ),
          StatusPill(s.status, tone: schemeStatusTone(s.status)),
        ]),
        const SizedBox(height: 16),
        if (!flexible) ...[
          Row(children: [
            Text('${summary.paidMonths} of ${summary.totalMonths} months',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const Spacer(),
            Text('${summary.progressPercent}%', style: const TextStyle(color: Kv.muted, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          KvProgressBar(value: summary.progressPercent / 100, color: s.isGold ? Kv.gold : Kv.blue),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: StatCell('Total paid', formatInr(s.totalPaid))),
          if (summary.hasGrams) Expanded(child: StatCell(metal, formatGrams(summary.totalGrams))),
          Expanded(child: StatCell('Matures', matures ?? '—', end: true)),
        ]),
        if (redemption != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Kv.goldSoft, borderRadius: Kv.smallRadius),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diwali redemption ready', style: TextStyle(fontWeight: FontWeight.w600)),
              if ((redemption.goldGrams ?? 0) != 0)
                Text('${_num(redemption.goldGrams!)}g gold (${formatInr(redemption.goldCoinValue ?? 0)})'),
              if ((redemption.silverGrams ?? 0) != 0)
                Text('${_num(redemption.silverGrams!)}g silver (${formatInr(redemption.silverValue ?? 0)})'),
              if ((redemption.giftsValue ?? 0) != 0) Text('Gift hamper (${formatInr(redemption.giftsValue!)})'),
            ]),
          ),
        ],
        if (awaitingRedemption) ...[
          const SizedBox(height: 12),
          const Text('All installments collected. Your redemption payout appears here once it’s processed.',
              style: TextStyle(fontSize: 12.5, color: Kv.muted)),
        ],
        if (canPay) ...[
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(flexible ? 'Flexible plan' : 'Next due',
                    style: const TextStyle(fontSize: 12, color: Kv.muted, fontWeight: FontWeight.w500)),
                Text(
                    flexible
                        ? 'Any amount from ${formatInr(s.monthlyAmount)}'
                        : 'Month ${summary.nextMonth ?? summary.paidMonths + 1} of ${s.duration}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            FilledButton(
              onPressed: paying ? null : onPay,
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: paying ? spinner : Text(flexible ? 'Pay now' : 'Pay ${formatInr(s.monthlyAmount)}'),
            ),
          ]),
        ] else if (s.passbookNumber == null) ...[
          const SizedBox(height: 12),
          const Text('Your passbook is issued once your first payment is recorded.',
              style: TextStyle(fontSize: 12.5, color: Kv.muted)),
        ],
      ]),
    );
  }
}

/// JS number-to-string: no trailing ".0".
String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
