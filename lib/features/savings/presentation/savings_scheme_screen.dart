import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/format/currency.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/installment_payer.dart';
import '../data/savings_models.dart';
import '../data/savings_repository.dart';

/// The web's `formatPrice` here also guards non-finite numbers.
String _price(double v) => v.isFinite ? formatInr(v) : '—';
final _shortDate = DateFormat('dd MMM y');

/// Status pill colours (Tailwind *-100 background / *-700 text on the web).
(Color, Color)? schemeStatusColors(String status) => switch (status) {
      'Active' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'Completed' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'Dropped' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _ => null, // Cancelled and unknown: muted
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.colors});
  final String status;
  final (Color, Color)? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = colors ?? schemeStatusColors(status) ?? (scheme.surfaceContainerHigh, scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

/// The calculator's projection for a FIXED plan (null for FLEXIBLE / no amount).
/// Hamper (Diwali) plans count as a one-month bonus for display, as on the web.
({double totalPaid, double bonusAmount, double totalValue})? projectSavings(SchemePlan? plan, double? amount) {
  if (plan == null || plan.isFlexible || amount == null || amount == 0) return null;
  final totalPaid = amount * plan.durationMonths;
  final bonus = amount * (plan.hamper != null ? 1 : plan.bonusMonths);
  return (totalPaid: totalPaid, bonusAmount: bonus, totalValue: totalPaid + bonus);
}

/// Whether "Pay" is offered on a scheme card. FLEXIBLE: any time before maturity.
/// FIXED: until every month has a real (non-bonus) payment.
bool canPayScheme(SavingsEnrollment s, {required bool isFlexible, DateTime? now}) {
  if (!s.isActive) return false;
  if (isFlexible) {
    final m = s.maturityDate == null ? null : DateTime.tryParse(s.maturityDate!);
    return m == null || !(now ?? DateTime.now()).isAfter(m);
  }
  return s.payments.where((p) => p.amount > 0).length < s.duration;
}

/// `/savings-scheme` (kv-ui SavingsScheme.tsx).
class SavingsSchemeScreen extends ConsumerStatefulWidget {
  const SavingsSchemeScreen({super.key});

  @override
  ConsumerState<SavingsSchemeScreen> createState() => _SavingsSchemeScreenState();
}

class _SavingsSchemeScreenState extends ConsumerState<SavingsSchemeScreen> {
  final _plansKey = GlobalKey();
  final _calculatorKey = GlobalKey();
  final _passbookCtrl = TextEditingController();
  final _flexAmounts = <String, TextEditingController>{};
  late final InstallmentPayer _payer;

  String? _selectedType;
  double? _selectedAmount;
  bool _enrolling = false;
  bool _requestingOtp = false;

  @override
  void initState() {
    super.initState();
    _payer = InstallmentPayer(
      ref: ref,
      context: () => context,
      onChanged: () => mounted ? setState(() {}) : null,
      onPaid: (_) => ref.invalidate(mySchemesProvider),
    );
  }

  @override
  void dispose() {
    _payer.dispose();
    _passbookCtrl.dispose();
    for (final c in _flexAmounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400));
  }

  void _openPassbook(String number) {
    if (number.trim().isEmpty) return;
    context.push('/savings-scheme/passbook/${Uri.encodeComponent(number.trim())}');
  }

  void _selectPlan(SchemePlan plan) {
    setState(() {
      _selectedType = plan.type;
      _selectedAmount = plan.monthlyAmounts.firstOrNull;
    });
    _scrollTo(_calculatorKey);
  }

  Future<void> _enroll(SchemePlan? plan) async {
    if (!ref.read(authSessionProvider).isAuthenticated) {
      showToast(context, 'Login required', 'Please login to enroll in a savings scheme.', error: true);
      context.push('/login');
      return;
    }
    if (plan == null || (!plan.isFlexible && _selectedAmount == null)) {
      showToast(context, 'Choose a plan', 'Select a scheme and monthly amount first.', error: true);
      return;
    }
    setState(() => _requestingOtp = true);
    String channel;
    try {
      channel = await ref.read(savingsRepositoryProvider).requestEnrollOtp();
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not send confirmation code',
            e is ApiException ? e.message : 'Please try again.', error: true);
      }
      return;
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
    if (!mounted) return;
    final otp = await showDialog<String>(context: context, builder: (_) => _OtpDialog(channel: channel));
    if (otp == null || !mounted) return;

    setState(() => _enrolling = true);
    try {
      final today = DateTime.now();
      await ref.read(savingsRepositoryProvider).enroll(
            schemeType: plan.type,
            // FLEXIBLE plans have no chosen amount; the server stores the plan minimum.
            monthlyAmount: plan.isFlexible ? (plan.minPaymentAmount ?? 0) : _selectedAmount!,
            startDate: DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, today.day)),
            otp: otp,
          );
      if (!mounted) return;
      showToast(context, 'Enrollment Initiated',
          'Your ${plan.name} scheme is now active. Your passbook will be issued after your first payment.');
      ref.invalidate(mySchemesProvider);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Enrollment failed',
            e is ApiException ? e.message : 'Unable to enroll right now.', error: true);
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final authed = ref.watch(authSessionProvider).isAuthenticated;
    final plansAsync = ref.watch(schemePlansProvider);
    final plans = plansAsync.valueOrNull ?? const <SchemePlan>[];

    // Default to the first plan once the catalogue loads.
    if (_selectedType == null && plans.isNotEmpty) {
      _selectedType = plans.first.type;
      _selectedAmount = plans.first.monthlyAmounts.firstOrNull;
    }
    final plan = plans.where((p) => p.type == _selectedType).firstOrNull;

    final silver = ref.watch(silverRatesProvider).valueOrNull ?? const [];
    final gold = ref.watch(goldRatesProvider).valueOrNull ?? const [];
    final todayRate = plan?.metal == 'GOLD'
        ? gold.firstOrNull?.ratePerGram
        : plan?.metal == 'SILVER'
            ? silver.firstOrNull?.ratePerGram
            : null;
    final estimatedGrams =
        _selectedAmount != null && todayRate != null && todayRate != 0 ? _selectedAmount! / todayRate : null;
    final projection = projectSavings(plan, _selectedAmount);

    TextStyle? h2([Color? c]) =>
        theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: c ?? scheme.onSurface);

    Widget section({required List<Widget> children, bool tinted = false, Key? key}) => Container(
          key: key,
          color: tinted ? scheme.surfaceContainerHigh.withValues(alpha: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    Widget centredHeading(String title, [String? sub]) => Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(children: [
            Text(title, textAlign: TextAlign.center, style: h2()),
            if (sub != null) ...[
              const SizedBox(height: 8),
              Text(sub, textAlign: TextAlign.center, style: TextStyle(color: muted)),
            ],
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Scheme')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schemePlansProvider);
          ref.invalidate(mySchemesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Hero
            Container(
              color: scheme.primary,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: scheme.tertiary, borderRadius: BorderRadius.circular(999)),
                  child: Text('💰 Monthly Savings Schemes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onTertiary)),
                ),
                const SizedBox(height: 24),
                Text('Secure Your Gold & Silver\nFuture Today',
                    style: theme.textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimary)),
                const SizedBox(height: 24),
                Text(
                  'Choose from our Gold Purchase Plan, Silver Purchase Plan, or Diwali savings schemes and build your '
                  'collection systematically — pay monthly, redeem for jewellery or a festival hamper.',
                  style: TextStyle(fontSize: 18, color: scheme.onPrimary.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  onPressed: () => _scrollTo(_plansKey),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Explore Schemes'),
                ),
              ]),
            ),

            // My schemes
            if (authed) section(children: [_mySchemes(theme, muted)]),

            // Plan picker
            section(key: _plansKey, tinted: true, children: [
              centredHeading('Our Schemes', 'Pick the scheme that suits you — each redeems differently'),
              if (plansAsync.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (plans.isEmpty)
                Text('No schemes are open for enrollment right now — check back soon.',
                    textAlign: TextAlign.center, style: TextStyle(color: muted))
              else
                for (final p in plans) ...[_planCard(p, p.type == _selectedType), const SizedBox(height: 16)],
            ]),

            // Calculator
            section(key: _calculatorKey, children: [
              centredHeading(plan?.name ?? 'Savings Calculator',
                  plan?.description ?? 'Plan your savings and see how much you can accumulate'),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (plan?.isFlexible ?? false) ...[
                      const Text('Payment Amount', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Any amount, minimum ${_price(plan?.minPaymentAmount ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('No fixed amount — pay as much as you like, as often as you like, once enrolled.',
                          style: TextStyle(fontSize: 12, color: muted)),
                    ] else ...[
                      const Text('Monthly Amount', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<double>(
                        key: ValueKey(plan?.type),
                        initialValue: _selectedAmount,
                        hint: const Text('Select an amount'),
                        items: [
                          for (final a in plan?.monthlyAmounts ?? const <double>[])
                            DropdownMenuItem(value: a, child: Text('${_price(a)} / month')),
                        ],
                        onChanged: plan == null ? null : (v) => setState(() => _selectedAmount = v),
                      ),
                      const SizedBox(height: 8),
                      Text('Fixed denominations set by the shop — pick the one that suits you.',
                          style: TextStyle(fontSize: 12, color: muted)),
                    ],
                    const SizedBox(height: 24),
                    const Text('Scheme Duration', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('${plan?.durationMonths ?? '—'} months', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    _summaryPanel(theme, plan, estimatedGrams, projection),
                    const SizedBox(height: 32),
                    Center(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: scheme.tertiary,
                            foregroundColor: scheme.onTertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                        onPressed: _enrolling ||
                                _requestingOtp ||
                                plan == null ||
                                (!plan.isFlexible && _selectedAmount == null)
                            ? null
                            : () => _enroll(plan),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(_enrolling
                            ? 'Enrolling...'
                            : _requestingOtp
                                ? 'Sending code...'
                                : 'Enroll Now'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '* ${plan?.metal != null ? "${plan!.metal == 'GOLD' ? 'Gold' : 'Silver'} will be calculated based on the prevailing rate at the time of each payment." : 'The gold portion of your Diwali hamper is a fixed ₹ value, converted to grams at the rate on the day of redemption — so it stays fair regardless of how gold moves.'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text("We'll text a confirmation code to your phone before your enrollment goes through.",
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
                  ]),
                ),
              ),
            ]),

            // Benefits
            section(tinted: true, children: [
              centredHeading('Why Choose Our Schemes?', 'Maximize your savings with exclusive benefits'),
              for (final (icon, title, body) in const [
                (Icons.card_giftcard, 'Choose Your Scheme',
                    'Gold Purchase Plan, Silver Purchase Plan, or the Diwali hamper scheme — each with its own rules and rewards.'),
                (Icons.shield_outlined, 'Price Locked-In',
                    "Every installment is converted to grams at that day's rate, protecting you from future price rises."),
                (Icons.calendar_today_outlined, 'Fixed Monthly Amounts',
                    "Pick a plan's published monthly amount and pay by the 10th of each month."),
                (Icons.check, 'Zero Making Charges',
                    'No making charges when you redeem your scheme for coins, bars, or pooja articles.'),
              ]) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      CircleAvatar(
                          radius: 32,
                          backgroundColor: scheme.tertiary.withValues(alpha: 0.1),
                          child: Icon(icon, size: 32, color: scheme.primary)),
                      const SizedBox(height: 16),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: muted)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ]),

            // How it works
            section(children: [
              centredHeading('How It Works'),
              for (final (step, title, body) in const [
                ('01', 'Choose', 'Pick the Gold Purchase Plan, Silver Purchase Plan, or the Diwali scheme and a monthly amount'),
                ('02', 'Save', 'Pay your installments monthly via Razorpay, or in cash at the shop'),
                ('03', 'Earn', 'The Gold and Silver Purchase Plans get a bonus month; the Diwali scheme gets a festival hamper'),
                ('04', 'Redeem', 'Exchange your accumulated value for jewellery, coins, or the hamper — goods only, never cash'),
              ]) ...[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.tertiary,
                  child: Text(step,
                      style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.onTertiary)),
                ),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: muted)),
                const SizedBox(height: 32),
              ],
            ]),

            // FAQ
            section(tinted: true, children: [
              centredHeading('Frequently Asked Questions'),
              for (final (q, a) in const [
                ('What monthly amounts can I choose?',
                    "Each scheme publishes a fixed set of monthly amounts — pick the one that suits you when enrolling. Amounts can't be changed mid-scheme."),
                ('What happens if I miss a payment?',
                    'You can pay the next month, but your maturity date moves out by however many months you fell behind. Only one installment is accepted per calendar month.'),
                ('What if I need to stop the scheme early?',
                    "You can exit any time before completing the scheme, but 10% of what you've paid is forfeited (plus the value of any gifts already received), and the remainder is redeemable as goods only — never as a cash refund."),
                ('How is the bonus calculated?',
                    "The Gold Purchase Plan and Silver Purchase Plan credit one bonus month's value (in grams, at that day's rate) automatically once you complete all 11 real installments. The Diwali scheme has no bonus month — instead you receive the fixed festival hamper."),
                ('Can I pay in cash instead of online?',
                    'Yes — visit the shop and our staff can record a cash collection on your passbook directly.'),
              ]) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(a, style: TextStyle(color: muted)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _mySchemes(ThemeData theme, Color muted) {
    final schemes = ref.watch(mySchemesProvider);
    final list = schemes.valueOrNull ?? const <SavingsEnrollment>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('My Schemes', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _passbookCtrl,
            decoration: const InputDecoration(hintText: 'Track by passbook number', isDense: true),
            style: const TextStyle(fontSize: 14),
            textInputAction: TextInputAction.search,
            onSubmitted: _openPassbook,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _openPassbook(_passbookCtrl.text),
          icon: const Icon(Icons.search, size: 14),
          label: const Text('Track'),
        ),
      ]),
      const SizedBox(height: 24),
      if (schemes.isLoading)
        const Center(child: CircularProgressIndicator())
      else if (list.isEmpty)
        Text('You have no schemes yet. Pick one above!', style: TextStyle(fontSize: 14, color: muted))
      else ...[
        for (final s in list) ...[_schemeCard(theme, s), const SizedBox(height: 16)],
        Text(
            'You can enroll in additional schemes at any time. Each enrollment is independently tracked with its own passbook number.',
            style: TextStyle(fontSize: 12, color: muted)),
      ],
    ]);
  }

  Widget _schemeCard(ThemeData theme, SavingsEnrollment s) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final flexible = ref.watch(isFlexibleTypeProvider(s.schemeType));
    final summary = summarizeScheme(s);
    final realPayments = s.payments.where((p) => p.amount > 0).length;
    final canPay = canPayScheme(s, isFlexible: flexible);
    final redemption =
        s.schemeType == 'DIWALI' && s.maturityBenefits?.computedAt != null ? s.maturityBenefits : null;
    final awaitingRedemption = s.schemeType == 'DIWALI' && s.status == 'Completed' && redemption == null;
    final paying = _payer.payingSchemeId == s.id;
    final flexCtrl = _flexAmounts.putIfAbsent(s.id, TextEditingController.new);

    Widget line(String l, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: 14, color: muted))),
            DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), child: v),
          ]),
        );
    const spinner = SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.planName ?? s.schemeType, style: TextStyle(fontSize: 12, color: muted)),
                Text(s.passbookNumber != null ? 'Passbook #${s.passbookNumber}' : 'Passbook pending first payment',
                    style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: flexible ? 'Min ${_price(s.monthlyAmount)}' : _price(s.monthlyAmount)),
                    TextSpan(
                        text: flexible ? ' · pay anytime' : '/mo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: muted)),
                  ]),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            StatusPill(s.status),
          ]),
          const SizedBox(height: 12),
          if (flexible)
            line('Duration', Text('${s.duration} months'))
          else
            line(
              'Months paid',
              Text.rich(TextSpan(children: [
                TextSpan(text: '${summary.paidMonths} of ${summary.totalMonths}'),
                if (summary.pendingMonths > 0)
                  TextSpan(
                      text: ' · ${summary.pendingMonths} pending',
                      style: TextStyle(fontWeight: FontWeight.w400, color: muted)),
              ])),
            ),
          line('Total Paid', Text(_price(s.totalPaid))),
          if (summary.hasGrams)
            line('${s.isGold ? 'Gold' : 'Silver'} accumulated', Text(formatGrams(summary.totalGrams))),
          if (s.maturityDate != null && DateTime.tryParse(s.maturityDate!) != null)
            line('Matures', Text(_shortDate.format(DateTime.parse(s.maturityDate!).toLocal()))),
          const SizedBox(height: 16),
          if (canPay && flexible)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: flexCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'Min ${s.monthlyAmount.toStringAsFixed(0)}', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: paying ||
                        flexCtrl.text.isEmpty ||
                        (double.tryParse(flexCtrl.text) ?? 0) < s.monthlyAmount
                    ? null
                    : () => _payer.pay(s, isFlexible: true, customAmount: double.parse(flexCtrl.text)),
                child: paying ? spinner : const Text('Pay'),
              ),
            ]),
          if (canPay && !flexible)
            FilledButton(
              onPressed: paying ? null : () => _payer.pay(s, isFlexible: false),
              child: paying
                  ? spinner
                  : Text('Pay Month ${summary.nextMonth ?? realPayments + 1} of ${s.duration} (${_price(s.monthlyAmount)})'),
            ),
          if (redemption != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Diwali Redemption Ready', style: TextStyle(fontWeight: FontWeight.w500)),
                  if ((redemption.goldGrams ?? 0) != 0)
                    Text('${_num(redemption.goldGrams!)}g gold (${_price(redemption.goldCoinValue ?? 0)})'),
                  if ((redemption.silverGrams ?? 0) != 0)
                    Text('${_num(redemption.silverGrams!)}g silver (${_price(redemption.silverValue ?? 0)})'),
                  if ((redemption.giftsValue ?? 0) != 0) Text('Gift hamper (${_price(redemption.giftsValue!)})'),
                ]),
              ),
            ),
          ],
          if (awaitingRedemption) ...[
            const SizedBox(height: 8),
            Text("All installments collected — your redemption payout will appear here once it's processed.",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 8),
          if (s.passbookNumber != null)
            OutlinedButton.icon(
              onPressed: () => _openPassbook(s.passbookNumber!),
              icon: const Icon(Icons.menu_book_outlined, size: 14),
              label: Text(flexible ? 'View Passbook' : 'View Payment History'),
            )
          else
            Text('Your passbook is issued once your first payment is recorded.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
        ]),
      ),
    );
  }

  Widget _planCard(SchemePlan p, bool selected) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    Widget row(String l, String v, {bool primary = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: 14, color: primary ? scheme.primary : muted))),
            Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primary ? scheme.primary : null)),
          ]),
        );
    final from = p.monthlyAmounts.isEmpty ? 0.0 : p.monthlyAmounts.reduce((a, b) => a < b ? a : b);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? scheme.primary : scheme.outline, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => _selectPlan(p),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.monetization_on_outlined, size: 20, color: scheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(p.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),
            if (p.description != null) Text(p.description!, style: TextStyle(fontSize: 14, color: muted)),
            const SizedBox(height: 12),
            row('Duration', '${p.durationMonths} months'),
            row(p.isFlexible ? 'Minimum' : 'From',
                p.isFlexible ? '${_price(p.minPaymentAmount ?? 0)}, any time' : '${_price(from)}/mo'),
            if (p.bonusMonths > 0)
              row('Bonus', '+${p.bonusMonths} month value', primary: true)
            else if (p.hamper != null)
              row('Reward', 'Diwali hamper', primary: true),
            const SizedBox(height: 12),
            selected
                ? FilledButton(onPressed: () => _selectPlan(p), child: const Text('Selected'))
                : OutlinedButton(onPressed: () => _selectPlan(p), child: const Text('Select')),
          ]),
        ),
      ),
    );
  }

  Widget _summaryPanel(ThemeData theme, SchemePlan? plan, double? grams,
      ({double totalPaid, double bonusAmount, double totalValue})? proj) {
    final scheme = theme.colorScheme;
    final fg = scheme.onPrimary;
    Widget row(String l, String v, {double size = 16, bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: TextStyle(
                        fontSize: size,
                        color: color ?? fg.withValues(alpha: bold ? 1 : 0.8),
                        fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
            Text(v,
                style: TextStyle(
                    fontSize: size, color: color ?? fg, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Your Savings Summary',
            style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        if (plan?.isFlexible ?? false) ...[
          row('Minimum Payment', _price(plan?.minPaymentAmount ?? 0)),
          row('Duration', '${plan?.durationMonths ?? '—'} months'),
          Text(
              "Pay any amount, as often as you like, within ${plan?.durationMonths ?? 11} months of enrolling — every payment converts to silver grams at that day's rate. Redeemable for silver articles or bars only.",
              style: TextStyle(fontSize: 14, color: fg.withValues(alpha: 0.9))),
        ] else ...[
          row('Monthly Payment', _selectedAmount != null ? _price(_selectedAmount!) : '—'),
          if (plan?.metal != null)
            row("≈ Grams at Today's Rate",
                grams != null ? '${formatGrams(grams)} ${plan!.metal == 'GOLD' ? 'Gold' : 'Silver'}' : 'Rate unavailable',
                size: 14),
          row('Duration', '${plan?.durationMonths ?? '—'} months'),
          if (proj != null) row('Total Paid', _price(proj.totalPaid)),
          // The web colours this text-primary on a primary background.
          if (proj != null && proj.bonusAmount > 0)
            row('Bonus Month Value', '+ ${_price(proj.bonusAmount)}', color: scheme.primary),
          if (plan?.hamper != null)
            DefaultTextStyle.merge(
              style: TextStyle(fontSize: 14, color: fg.withValues(alpha: 0.9)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your redemption hamper includes:', style: TextStyle(color: fg.withValues(alpha: 0.8))),
                Text('• Gold${plan!.hamper!.goldCoinPurity != null ? ' (${plan.hamper!.goldCoinPurity})' : ''} worth the remaining value — however many grams that buys at redemption'),
                if ((plan.hamper!.silverCoinGrams ?? 0) != 0) Text('• ${_num(plan.hamper!.silverCoinGrams!)}g Silver Coin'),
                for (final g in plan.hamper!.gifts) Text('• $g'),
              ]),
            ),
          Divider(color: fg.withValues(alpha: 0.2), height: 24),
          row('Total Value', proj != null ? _price(proj.totalValue) : '—', size: 18, bold: true),
        ],
      ]),
    );
  }
}

/// JS number-to-string: no trailing ".0".
String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _OtpDialog extends StatefulWidget {
  const _OtpDialog({required this.channel});
  final String channel;

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Your Enrollment'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          widget.channel == 'email'
              ? "We've emailed you a confirmation code — enter it below to complete your enrollment."
              : "We've sent a confirmation code to your WhatsApp — enter it below to complete your enrollment.",
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Confirmation Code'),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _ctrl.text.trim().isEmpty ? null : () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('Confirm & Enroll'),
          ),
        ),
      ],
    );
  }
}
