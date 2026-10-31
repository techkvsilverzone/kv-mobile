import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/format/currency.dart';
import '../../orders/data/models/order.dart';
import '../../orders/data/order_repository.dart';
import '../../returns/request_return_dialog.dart';
import '../../returns/returns.dart';
import '../../savings/data/savings_repository.dart';
import '../../savings/presentation/savings_scheme_screen.dart' show StatusPill;

const _green = (Color(0xFFDCFCE7), Color(0xFF15803D));
const _red = (Color(0xFFFEE2E2), Color(0xFFB91C1C));
const _yellow = (Color(0xFFFEF9C3), Color(0xFFA16207));
const _blue = (Color(0xFFDBEAFE), Color(0xFF1D4ED8));
final _date = DateFormat('d/M/y');
String _last6(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

/// One tab's card: serif heading over its content (web Profile tabs).
class _TabCard extends StatelessWidget {
  const _TabCard({required this.title, required this.child, this.onRefresh});
  final String title;
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            child,
          ]),
        ),
      ),
    ]);
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

Widget _loading() => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
Widget _emptyText(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
    );
BoxDecoration _box(BuildContext c) => BoxDecoration(
    border: Border.all(color: Theme.of(c).colorScheme.outline), borderRadius: BorderRadius.circular(8));

class AccountOrdersTab extends ConsumerWidget {
  const AccountOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final list = orders.valueOrNull ?? const <Order>[];
    return _TabCard(
      title: 'Order History',
      onRefresh: () async => ref.invalidate(myOrdersProvider),
      child: orders.isLoading
          ? _loading()
          : list.isEmpty
              ? _emptyText(context, 'No orders yet. Start shopping!')
              : Column(children: [
                  for (final o in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: _box(context),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('#${o.shortId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                  '${o.createdAt == null ? '' : _date.format(o.createdAt!.toLocal())} • ${o.items.length} item(s)',
                                  style: TextStyle(fontSize: 14, color: muted)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(formatInr(o.grandTotal),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                            const SizedBox(height: 4),
                            StatusPill(o.status.wireName,
                                colors: o.status == OrderStatus.delivered
                                    ? _green
                                    : o.status == OrderStatus.cancelled
                                        ? _red
                                        : _yellow),
                          ]),
                        ]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (o.status == OrderStatus.delivered)
                            OutlinedButton(
                              onPressed: () => showRequestReturnDialog(context, o),
                              child: const Text('Request Return'),
                            ),
                          IconButton(
                            tooltip: 'View order',
                            onPressed: () => context.push('/orders/${o.id}'),
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                          ),
                        ]),
                      ]),
                    ),
                ]),
    );
  }
}

class AccountWishlistTab extends StatelessWidget {
  const AccountWishlistTab({super.key});

  @override
  Widget build(BuildContext context) => _TabCard(
        title: 'My Wishlist',
        child: Column(children: [
          const SizedBox(height: 16),
          Text('Manage your saved products in the dedicated wishlist page.',
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.push('/wishlist'), child: const Text('Open Wishlist')),
          const SizedBox(height: 16),
        ]),
      );
}

class AccountSavingsTab extends ConsumerWidget {
  const AccountSavingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final schemes = ref.watch(mySchemesProvider);
    final list = schemes.valueOrNull ?? const [];
    Widget stat(String l, String v, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: TextStyle(fontSize: 12, color: muted)),
          Text(v, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ]);
    return _TabCard(
      title: 'Savings Scheme',
      onRefresh: () async => ref.invalidate(mySchemesProvider),
      child: schemes.isLoading
          ? _loading()
          : list.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text('Not Enrolled Yet',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Join a Monthly Savings Scheme — Gold Purchase Plan, Silver Purchase Plan, or Diwali!',
                        textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => context.push('/savings-scheme'), child: const Text('Enroll Now')),
                  ]),
                )
              : Column(children: [
                  for (final s in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: _box(context),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 8, children: [
                          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(s.planName ?? s.schemeType,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            StatusPill(s.status),
                          ]),
                          Text(
                              'Started ${DateTime.tryParse(s.startDate) == null ? '' : _date.format(DateTime.parse(s.startDate))}',
                              style: TextStyle(fontSize: 14, color: muted)),
                        ]),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 3.2,
                          children: [
                            stat('Monthly', formatInr(s.monthlyAmount)),
                            stat('Duration', '${s.duration} months'),
                            stat('Paid', formatInr(s.totalPaid)),
                            stat('Bonus', formatInr(s.bonusAmount), color: const Color(0xFF16A34A)),
                          ],
                        ),
                      ]),
                    ),
                ]),
    );
  }
}

class AccountReturnsTab extends ConsumerWidget {
  const AccountReturnsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final returns = ref.watch(myReturnsProvider);
    final list = returns.valueOrNull ?? const <ReturnRequest>[];
    return _TabCard(
      title: 'Return Requests',
      onRefresh: () async => ref.invalidate(myReturnsProvider),
      child: returns.isLoading
          ? _loading()
          : list.isEmpty
              ? _emptyText(context, 'No return requests. Hope you loved everything!')
              : Column(children: [
                  for (final r in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: _box(context),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Return #${_last6(r.id)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Order #${_last6(r.orderId)} • ${r.reason}', style: TextStyle(fontSize: 14, color: muted)),
                              if (r.createdAt != null)
                                Text(_date.format(r.createdAt!.toLocal()), style: TextStyle(fontSize: 12, color: muted)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(formatInr(r.refundAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            StatusPill(r.status,
                                colors: switch (r.status) {
                                  'Approved' => _green,
                                  'Rejected' => _red,
                                  'Completed' => _blue,
                                  _ => _yellow,
                                }),
                          ]),
                        ]),
                        const Divider(height: 24),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          StatusPill(r.isKvFault ? 'KV Fault Claim' : 'Exchange / Store Credit',
                              colors: r.isKvFault
                                  ? (theme.colorScheme.primary.withValues(alpha: 0.1), theme.colorScheme.primary)
                                  : (theme.colorScheme.surfaceContainerHigh, muted)),
                          if (r.videoStatus == 'awaiting')
                            StatusPill('🎥 Video pending — send to WhatsApp with code ${r.videoReferenceCode ?? ''}',
                                colors: _yellow),
                          if (r.videoStatus == 'received') const StatusPill('✓ Video received', colors: _green),
                        ]),
                      ]),
                    ),
                ]),
    );
  }
}
