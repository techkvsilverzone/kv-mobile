import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/format/currency.dart';
import '../../../core/ui/kv_ui.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/installment_payer.dart';
import '../data/savings_models.dart';
import '../data/savings_repository.dart';
import 'savings_info_screen.dart';
import 'savings_scheme_screen.dart' show projectSavings;
import 'widgets/scheme_widgets.dart';

/// One plan: amount chips, live projection, hamper, key rules, and Enroll (OTP-confirmed).
class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.plan});
  final SchemePlan plan;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  late double? _amount = widget.plan.monthlyAmounts.firstOrNull;
  bool _requestingOtp = false;
  bool _enrolling = false;

  Future<void> _enroll() async {
    final plan = widget.plan;
    if (ref.read(currentUserProvider) == null) {
      showKvToast(context, 'Sign in to enroll', message: 'Your schemes are linked to your account.');
      context.push('/login?from=/savings-scheme');
      return;
    }
    if (!plan.isFlexible && _amount == null) {
      showKvToast(context, 'Choose an amount', message: 'Pick a monthly amount first.', error: true);
      return;
    }
    setState(() => _requestingOtp = true);
    String channel;
    try {
      channel = await ref.read(savingsRepositoryProvider).requestEnrollOtp();
    } catch (e) {
      if (mounted) {
        showKvToast(context, 'Could not send confirmation code',
            message: e is ApiException ? e.message : 'Please try again.', error: true);
      }
      return;
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
    if (!mounted) return;
    final otp = await showEnrollOtpSheet(context, channel: channel);
    if (otp == null || !mounted) return;

    setState(() => _enrolling = true);
    try {
      final today = DateTime.now();
      await ref.read(savingsRepositoryProvider).enroll(
            schemeType: plan.type,
            // FLEXIBLE plans have no chosen amount; the server stores the plan minimum.
            monthlyAmount: plan.isFlexible ? (plan.minPaymentAmount ?? 0) : _amount!,
            startDate: DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, today.day)),
            otp: otp,
          );
      if (!mounted) return;
      showKvToast(context, 'You’re enrolled',
          message: 'Your ${plan.name} is active. Your passbook is issued after your first payment.');
      ref.invalidate(mySchemesProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showKvToast(context, 'Enrollment failed',
            message: e is ApiException ? e.message : 'Unable to enroll right now.', error: true);
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final gold = plan.metal == 'GOLD';
    final metalName = gold ? 'Gold' : 'Silver';
    final authed = ref.watch(currentUserProvider) != null;
    final rates = plan.metal == null
        ? null
        : ref.watch(gold ? goldRatesProvider : silverRatesProvider).valueOrNull;
    final todayRate = rates?.firstOrNull?.ratePerGram;
    final basis = plan.isFlexible ? plan.minPaymentAmount : _amount;
    final grams = basis != null && todayRate != null && todayRate != 0 ? basis / todayRate : null;
    final proj = projectSavings(plan, _amount);
    final busy = _enrolling || _requestingOtp;

    Widget row(String label, String value, {Color? color, bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(color: strong ? Kv.ink : Kv.muted, fontWeight: strong ? FontWeight.w600 : null))),
            Text(value,
                style: TextStyle(
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                    fontSize: strong ? 18 : 15,
                    color: color ?? Kv.ink)),
          ]),
        );

    final rules = [
      if (plan.metal != null)
        (Icons.lock_clock_outlined, 'Each payment becomes $metalName grams at that day’s rate.')
      else
        (Icons.lock_clock_outlined,
            'The gold in your hamper is a fixed ₹ value, converted to grams on redemption day.'),
      if (plan.isFlexible)
        (Icons.event_available_outlined, 'Pay as often as you like within ${plan.durationMonths} months.')
      else ...[
        (Icons.event_available_outlined, 'One payment per calendar month, by the 10th.'),
        (Icons.update_rounded, 'A missed month moves your maturity date out by a month.'),
      ],
      (Icons.logout_rounded, 'Exit early and 10% of what you paid is forfeited; the rest is redeemable as goods.'),
      (Icons.shopping_bag_outlined, 'Redeem for jewellery, coins or articles, never cash.'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 24), children: [
        // Header
        KvCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              MetalBadge(gold: gold, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(plan.metal == null ? 'Festival hamper plan' : '$metalName savings plan',
                      style: const TextStyle(color: Kv.muted, fontSize: 13)),
                ]),
              ),
            ]),
            if ((plan.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(plan.description!, style: const TextStyle(color: Kv.muted, height: 1.45)),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusPill('${plan.durationMonths} months', icon: Icons.calendar_month_outlined),
              if (plan.bonusMonths > 0)
                StatusPill('+${plan.bonusMonths} month free', tone: PillTone.gold, icon: Icons.card_giftcard_rounded),
              if (plan.hamper != null) const StatusPill('Diwali hamper', tone: PillTone.gold, icon: Icons.redeem_rounded),
              if (plan.isFlexible) const StatusPill('Flexible amount', tone: PillTone.info, icon: Icons.bolt_rounded),
            ]),
          ]),
        ),
        const SizedBox(height: Kv.gap),

        // Amount
        if (plan.isFlexible) ...[
          const _Title('How you pay'),
          KvCard(
            color: Kv.blueSoft,
            child: Row(children: [
              const Icon(Icons.bolt_rounded, color: Kv.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Any amount from ${formatInr(plan.minPaymentAmount ?? 0)}, as often as you like. '
                    'No fixed monthly amount.',
                    style: const TextStyle(color: Kv.blueDark, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ] else ...[
          const _Title('Monthly amount'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in plan.monthlyAmounts)
              ChoiceChip(
                label: Text(formatInr(a)),
                selected: _amount == a,
                showCheckmark: false,
                labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _amount == a ? Kv.blueDark : Kv.ink),
                side: BorderSide(color: _amount == a ? Kv.blue : Kv.line, width: _amount == a ? 1.5 : 1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onSelected: (_) => setState(() => _amount = a),
              ),
          ]),
        ],
        const SizedBox(height: Kv.gap),

        // Live summary
        const _Title('Your savings'),
        KvCard(
          child: Column(children: [
            if (plan.isFlexible) ...[
              row('Minimum payment', formatInr(plan.minPaymentAmount ?? 0)),
              row('Duration', '${plan.durationMonths} months'),
            ] else ...[
              row('You pay', _amount == null ? '—' : '${formatInr(_amount!)} × ${plan.durationMonths}'),
              if (proj != null) row('Total paid', formatInr(proj.totalPaid)),
              if (proj != null && proj.bonusAmount > 0)
                row(plan.hamper != null ? 'Hamper value' : 'Bonus month', '+ ${formatInr(proj.bonusAmount)}',
                    color: Kv.success),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
              row('Total value', proj == null ? '—' : formatInr(proj.totalValue), strong: true),
            ],
            if (plan.metal != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: gold ? Kv.goldSoft : Kv.bg, borderRadius: Kv.smallRadius),
                child: Text(
                  grams == null
                      ? 'Today’s $metalName rate is not available yet'
                      : '${formatInr(basis!)} buys ≈ ${formatGrams(grams)} $metalName at today’s ${formatInr(todayRate!)}/g',
                  style: TextStyle(fontSize: 13, color: gold ? const Color(0xFF6B5221) : Kv.muted, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ]),
        ),

        // Hamper
        if (plan.hamper != null) ...[
          const SizedBox(height: Kv.gap),
          const _Title('Your redemption hamper'),
          KvCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Bullet(Icons.toll_rounded,
                  'Gold${plan.hamper!.goldCoinPurity != null ? ' (${plan.hamper!.goldCoinPurity})' : ''} worth the remaining value'),
              if ((plan.hamper!.silverCoinGrams ?? 0) != 0)
                _Bullet(Icons.toll_outlined, '${_num(plan.hamper!.silverCoinGrams!)}g silver coin'),
              for (final g in plan.hamper!.gifts) _Bullet(Icons.redeem_rounded, g),
            ]),
          ),
        ],

        // Rules
        const SizedBox(height: Kv.gap),
        const _Title('Good to know'),
        KvCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (icon, text) in rules) _Bullet(icon, text),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavingsInfoScreen())),
                child: const Text('How savings schemes work'),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: BottomActionBar(
        leading: plan.isFlexible
            ? BarTotal(label: 'Pay from', amount: plan.minPaymentAmount ?? 0, note: 'any time, any amount')
            : BarTotal(
                label: 'Monthly',
                amount: _amount ?? 0,
                note: proj == null ? null : 'Total value ${formatInr(proj.totalValue)}'),
        action: FilledButton(
          onPressed: busy || (!plan.isFlexible && _amount == null) ? null : _enroll,
          style: FilledButton.styleFrom(minimumSize: const Size(150, 52)),
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(authed ? 'Enroll' : 'Sign in to enroll'),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Kv.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ]),
      );
}

/// JS number-to-string: no trailing ".0".
String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
