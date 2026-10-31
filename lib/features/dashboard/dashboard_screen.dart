import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_session.dart';
import '../../core/format/currency.dart';
import '../orders/data/models/order.dart';
import '../orders/data/order_repository.dart';
import '../savings/data/savings_models.dart';
import '../savings/data/savings_repository.dart';
import '../savings/presentation/savings_scheme_screen.dart' show StatusPill;

final _date = DateFormat('dd MMM y');
const _yellow = (Color(0xFFFEF9C3), Color(0xFFA16207));
const _blue = (Color(0xFFDBEAFE), Color(0xFF1D4ED8));
const _green = (Color(0xFFDCFCE7), Color(0xFF15803D));
const _red = (Color(0xFFFEE2E2), Color(0xFFB91C1C));

(Color, Color)? _orderColors(OrderStatus s) => switch (s) {
      OrderStatus.pending => _yellow,
      OrderStatus.shipped => _blue,
      OrderStatus.delivered => _green,
      OrderStatus.cancelled => _red,
      _ => null,
    };

(Color, Color)? _paymentColors(String s) => switch (s) {
      'paid' => _green,
      'pending' => _yellow,
      'failed' => _red,
      _ => null,
    };

/// Web fallback: an unknown maturity is start + duration months.
DateTime? schemeMaturity(SavingsEnrollment s) {
  final m = s.maturityDate == null ? null : DateTime.tryParse(s.maturityDate!);
  if (m != null) return m;
  final start = DateTime.tryParse(s.startDate);
  return start == null ? null : DateTime(start.year, start.month + s.duration, start.day);
}

/// `/dashboard` (kv-ui CustomerDashboard.tsx): My Orders and My Savings tabs.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('My Dashboard')),
        backgroundColor: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Dashboard',
                  style: theme.textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              Text('Welcome back, ${user?.name ?? ''}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 16), text: 'My Orders'),
              Tab(icon: Icon(Icons.credit_card, size: 16), text: 'My Savings'),
            ],
          ),
          const Expanded(child: TabBarView(children: [_OrdersTab(), _SavingsTab()])),
        ]),
      ),
    );
  }
}

Widget _empty(BuildContext context, IconData icon, String text, String link, String route) => ListView(
      padding: const EdgeInsets.symmetric(vertical: 64),
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Center(child: TextButton(onPressed: () => context.push(route), child: Text(link))),
      ],
    );

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (orders.isLoading) return const Center(child: CircularProgressIndicator());
    final list = orders.valueOrNull ?? const <Order>[];
    if (list.isEmpty) return _empty(context, Icons.inventory_2_outlined, 'No orders yet.', 'Start Shopping', '/shop');
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myOrdersProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final o = list[i];
          final payment = o.paymentStatus.isEmpty ? 'paid' : o.paymentStatus;
          final shortId = (o.id.length <= 8 ? o.id : o.id.substring(o.id.length - 8)).toUpperCase();
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 8, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Order #$shortId', style: TextStyle(fontSize: 12, color: muted)),
                    if (o.createdAt != null)
                      Text(_date.format(o.createdAt!.toLocal()), style: TextStyle(fontSize: 14, color: muted)),
                  ]),
                  Wrap(spacing: 8, children: [
                    StatusPill(o.status.wireName, colors: _orderColors(o.status)),
                    StatusPill('Payment: $payment', colors: _paymentColors(payment)),
                  ]),
                ]),
                const SizedBox(height: 12),
                for (final item in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text('${item.productName} × ${item.quantity}', style: const TextStyle(fontSize: 14))),
                      Text(formatInr(item.unitPrice * item.quantity), style: TextStyle(fontSize: 14, color: muted)),
                    ]),
                  ),
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Text(formatInr(o.grandTotal), style: const TextStyle(fontWeight: FontWeight.w600))),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/orders/${o.id}'),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Track Order'),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SavingsTab extends ConsumerWidget {
  const _SavingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(mySchemesProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (schemes.isLoading) return const Center(child: CircularProgressIndicator());
    final list = schemes.valueOrNull ?? const <SavingsEnrollment>[];
    if (list.isEmpty) {
      return _empty(context, Icons.credit_card, 'You have no active savings schemes.', 'Explore Schemes', '/savings-scheme');
    }
    Widget stat(String label, Widget value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          DefaultTextStyle.merge(style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), child: value),
        ]);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mySchemesProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final s = list[i];
          final flexible = ref.watch(isFlexibleTypeProvider(s.schemeType));
          final summary = summarizeScheme(s);
          final start = DateTime.tryParse(s.startDate);
          final maturity = schemeMaturity(s);
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(s.passbookNumber != null ? 'Passbook #${s.passbookNumber}' : 'Passbook pending first payment',
                          style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: 4),
                      StatusPill(s.status),
                    ]),
                  ),
                  if (s.passbookNumber != null)
                    OutlinedButton.icon(
                      onPressed: () => context.push('/savings-scheme/passbook/${Uri.encodeComponent(s.passbookNumber!)}'),
                      icon: const Icon(Icons.menu_book_outlined, size: 14),
                      label: const Text('Passbook'),
                    ),
                ]),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3,
                  mainAxisSpacing: 8,
                  children: [
                    stat('Monthly', Text(formatInr(s.monthlyAmount))),
                    flexible
                        ? stat('Duration', Text('${s.duration} months'))
                        : stat(
                            'Months paid',
                            Text.rich(TextSpan(children: [
                              TextSpan(text: '${summary.paidMonths} of ${summary.totalMonths}'),
                              if (summary.pendingMonths > 0)
                                TextSpan(
                                    text: ' · ${summary.pendingMonths} pending',
                                    style: TextStyle(fontWeight: FontWeight.w400, color: muted)),
                            ]))),
                    stat('Started', Text(start == null ? '' : _date.format(start))),
                    stat('Matures', Text(maturity == null ? '' : _date.format(maturity.toLocal()))),
                  ],
                ),
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Text('Total Paid', style: TextStyle(fontSize: 14, color: muted))),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: formatInr(s.totalPaid)),
                    if (summary.hasGrams)
                      TextSpan(
                          text: ' · ${summary.totalGrams.toStringAsFixed(3)} g ${s.isGold ? 'gold' : 'silver'}',
                          style: TextStyle(fontWeight: FontWeight.w400, color: muted)),
                  ]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
