import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/format/currency.dart';
import '../../../core/ui/kv_ui.dart';
import '../application/installment_payer.dart';
import '../data/savings_models.dart';
import '../data/savings_repository.dart';
import 'plan_detail_screen.dart';
import 'savings_info_screen.dart';
import 'widgets/scheme_widgets.dart';

// account_tabs.dart (another area) still imports the old pill from here.

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

void openPassbook(BuildContext context, String number) {
  if (number.trim().isEmpty) return;
  context.push('/savings-scheme/passbook/${Uri.encodeComponent(number.trim())}');
}

/// Savings tab root (`/savings-scheme`, kv-ui SavingsScheme.tsx): my schemes, plans, benefits.
class SavingsSchemeScreen extends ConsumerStatefulWidget {
  const SavingsSchemeScreen({super.key});

  @override
  ConsumerState<SavingsSchemeScreen> createState() => _SavingsSchemeScreenState();
}

class _SavingsSchemeScreenState extends ConsumerState<SavingsSchemeScreen> {
  late final InstallmentPayer _payer;

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
    super.dispose();
  }

  Future<void> _pay(SavingsEnrollment s, bool flexible) async {
    if (!flexible) return _payer.pay(s, isFlexible: false);
    final amount = await showFlexAmountSheet(context, s);
    if (amount != null && mounted) await _payer.pay(s, isFlexible: true, customAmount: amount);
  }

  void _findPassbook() => showKvSheet<void>(context, title: 'Find a passbook', builder: (_) => const _PassbookSearch());

  void _openPlan(SchemePlan p) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: p)));

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(currentUserProvider) != null;
    final plansAsync = ref.watch(schemePlansProvider);
    final schemesAsync = authed ? ref.watch(mySchemesProvider) : null;
    final schemes = schemesAsync?.valueOrNull ?? const <SavingsEnrollment>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings'),
        titleSpacing: Kv.pad,
        actions: [
          if (authed)
            IconButton(
              tooltip: 'Find a passbook',
              onPressed: _findPassbook,
              icon: const Icon(Icons.manage_search_rounded),
            ),
          IconButton(
            tooltip: 'How savings schemes work',
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const SavingsInfoScreen())),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schemePlansProvider);
          if (authed) ref.invalidate(mySchemesProvider);
          await ref.read(schemePlansProvider.future).catchError((_) => <SchemePlan>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            if (schemesAsync != null && schemesAsync.isLoading && schemes.isEmpty) ...[
              const SectionHeader(title: 'My schemes'),
              const ListSkeleton(rows: 1, height: 200),
              const SizedBox(height: Kv.gap - 12),
            ] else if (schemes.isNotEmpty) ...[
              SectionHeader(
                title: 'My schemes',
                subtitle: '${schemes.length} ${schemes.length == 1 ? 'scheme' : 'schemes'} · tap to open the passbook',
              ),
              for (final s in schemes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 12),
                  child: _schemeCard(s),
                ),
              const SizedBox(height: Kv.gap - 12),
            ] else ...[
              const _Intro(),
              const SizedBox(height: Kv.gap),
            ],
            SectionHeader(
              title: schemes.isEmpty ? 'Choose a plan' : 'Start another plan',
              subtitle: 'Pay monthly, redeem as silver or gold',
            ),
            plansAsync.when(
              loading: () => const ListSkeleton(rows: 3, height: 108),
              error: (_, __) => EmptyState(
                compact: true,
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load plans",
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(schemePlansProvider),
              ),
              data: (plans) => plans.isEmpty
                  ? const EmptyState(
                      compact: true,
                      icon: Icons.savings_outlined,
                      title: 'No plans open right now',
                      message: 'New savings plans open soon. Check back later.',
                    )
                  : Column(children: [
                      for (final p in plans)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 12),
                          child: PlanCard(plan: p, onTap: () => _openPlan(p)),
                        ),
                    ]),
            ),
            const SizedBox(height: Kv.gap - 12),
            const SectionHeader(title: 'Why save with us'),
            const _Benefits(),
            const SizedBox(height: Kv.gap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
              child: MenuGroup(children: [
                MenuRow(
                  icon: Icons.menu_book_outlined,
                  title: 'How savings schemes work',
                  subtitle: 'Steps, missed payments, early exit and FAQs',
                  onTap: () => Navigator.of(context, rootNavigator: true)
                      .push(MaterialPageRoute(builder: (_) => const SavingsInfoScreen())),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _schemeCard(SavingsEnrollment s) {
    final flexible = ref.watch(isFlexibleTypeProvider(s.schemeType));
    return SchemeCard(
      scheme: s,
      flexible: flexible,
      canPay: canPayScheme(s, isFlexible: flexible),
      paying: _payer.payingSchemeId == s.id,
      onPay: () => _pay(s, flexible),
      onOpen: s.passbookNumber == null ? null : () => openPassbook(context, s.passbookNumber!),
    );
  }
}

/// One plan in the catalogue; opens its detail page.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});
  final SchemePlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final gold = p.metal == 'GOLD';
    final from = p.monthlyAmounts.isEmpty ? 0.0 : p.monthlyAmounts.reduce((a, b) => a < b ? a : b);
    final metal = p.metal == null ? 'Festival hamper' : (gold ? 'Gold' : 'Silver');
    final (String, PillTone, IconData)? highlight = p.bonusMonths > 0
        ? ('+${p.bonusMonths} month free', PillTone.gold, Icons.card_giftcard_rounded)
        : p.hamper != null
            ? ('Diwali hamper', PillTone.gold, Icons.redeem_rounded)
            : p.isFlexible
                ? ('Pay any time', PillTone.info, Icons.bolt_rounded)
                : null;
    return KvCard(
      onTap: onTap,
      child: Row(children: [
        MetalBadge(gold: gold, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$metal · ${p.durationMonths} months', style: const TextStyle(fontSize: 13, color: Kv.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'From '),
                TextSpan(
                    text: formatInr(p.isFlexible ? (p.minPaymentAmount ?? 0) : from),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Kv.ink)),
                TextSpan(text: p.isFlexible ? ' a payment' : '/mo'),
              ]), style: const TextStyle(fontSize: 13.5, color: Kv.muted)),
              if (highlight != null) StatusPill(highlight.$1, tone: highlight.$2, icon: highlight.$3),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Kv.subtle),
      ]),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Kv.ink, borderRadius: Kv.cardRadius),
          child: const Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MONTHLY SAVINGS',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Kv.gold, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Save a little each month,\nown more silver',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
                SizedBox(height: 8),
                Text('Every payment is locked in at that day’s rate. Finish the plan and get a bonus month.',
                    style: TextStyle(color: Color(0xFFC9CED6), fontSize: 13, height: 1.4)),
              ]),
            ),
            SizedBox(width: 12),
            Icon(Icons.savings_outlined, size: 56, color: Kv.gold),
          ]),
        ),
      );
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.lock_clock_outlined, 'Rate locked', 'Each payment becomes grams at that day’s rate'),
    (Icons.card_giftcard_rounded, 'Bonus month', 'Silver and gold plans add a month free'),
    (Icons.diamond_outlined, 'No making charges', 'On coins, bars and pooja articles'),
    (Icons.storefront_outlined, 'Pay your way', 'Online, or in cash at the shop'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final (icon, title, body) = _items[i];
            return SizedBox(
              width: 150,
              child: KvCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: Kv.goldSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 19, color: Kv.gold),
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Kv.muted, height: 1.35)),
                ]),
              ),
            );
          },
        ),
      );
}

class _PassbookSearch extends StatefulWidget {
  const _PassbookSearch();

  @override
  State<_PassbookSearch> createState() => _PassbookSearchState();
}

class _PassbookSearchState extends State<_PassbookSearch> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() {
    final n = _ctrl.text.trim();
    if (n.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/savings-scheme/passbook/${Uri.encodeComponent(n)}');
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Enter the number printed on your passbook.', style: TextStyle(color: Kv.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
                labelText: 'Passbook number', hintText: 'SLV-2526-0000112', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _go(),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _ctrl.text.trim().isEmpty ? null : _go, child: const Text('Open passbook')),
        ]),
      );
}
