import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/format/currency.dart';
import '../../core/ui/kv_ui.dart';
import '../orders/data/models/order.dart';
import '../orders/data/order_repository.dart';
import '../savings/application/installment_payer.dart' show formatGrams;
import '../savings/data/savings_models.dart';
import '../savings/data/savings_repository.dart';
import '../savings/presentation/widgets/scheme_widgets.dart';

final _date = DateFormat('d MMM y');

/// Web fallback: an unknown maturity is start + duration months.
DateTime? schemeMaturity(SavingsEnrollment s) {
  final m = s.maturityDate == null ? null : DateTime.tryParse(s.maturityDate!);
  if (m != null) return m;
  final start = DateTime.tryParse(s.startDate);
  return start == null ? null : DateTime(start.year, start.month + s.duration, start.day);
}

PillTone _orderTone(OrderStatus s) => switch (s) {
      OrderStatus.pending || OrderStatus.processing => PillTone.warning,
      OrderStatus.shipped => PillTone.info,
      OrderStatus.delivered => PillTone.success,
      OrderStatus.cancelled => PillTone.danger,
      _ => PillTone.neutral,
    };

/// `/dashboard` (kv-ui CustomerDashboard): a one-page overview of recent orders and savings,
/// each linking to its full screen. The Account tab is the main hub; this keeps old links working.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final schemes = ref.watch(mySchemesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myOrdersProvider);
          ref.invalidate(mySchemesProvider);
          await ref.read(myOrdersProvider.future).catchError((_) => <Order>[]);
        },
        child: ListView(padding: const EdgeInsets.only(top: 16, bottom: 32), children: [
          SectionHeader(title: 'Savings', action: 'See all', onAction: () => context.go('/savings-scheme')),
          schemes.when(
            loading: () => const ListSkeleton(rows: 1, height: 160),
            error: (_, __) => _retry(() => ref.invalidate(mySchemesProvider)),
            data: (list) => _SavingsSummary(list),
          ),
          const SizedBox(height: Kv.gap),
          SectionHeader(title: 'Recent orders', action: 'See all', onAction: () => context.push('/orders')),
          orders.when(
            loading: () => const ListSkeleton(rows: 2, height: 72),
            error: (_, __) => _retry(() => ref.invalidate(myOrdersProvider)),
            data: (list) => _OrdersSummary(list),
          ),
        ]),
      ),
    );
  }

  static Widget _retry(VoidCallback onRetry) => EmptyState(
        compact: true,
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

class _SavingsSummary extends StatelessWidget {
  const _SavingsSummary(this.list);
  final List<SavingsEnrollment> list;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: KvCard(
          child: EmptyState(
            compact: true,
            icon: Icons.savings_outlined,
            title: 'No savings schemes yet',
            message: 'Save monthly and redeem as silver or gold.',
            actionLabel: 'Explore schemes',
            onAction: () => context.go('/savings-scheme'),
          ),
        ),
      );
    }
    final total = list.fold(0.0, (s, e) => s + e.totalPaid);
    double grams(bool gold) =>
        list.where((s) => s.isGold == gold && (s.metal ?? '').isNotEmpty).fold(0.0, (t, s) => t + summarizeScheme(s).totalGrams);
    final silverG = grams(false), goldG = grams(true);
    final active = list.where((s) => s.isActive).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
      child: KvCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: StatCell('Total saved', formatInr(total))),
              if (silverG > 0) Expanded(child: StatCell('Silver', formatGrams(silverG))),
              if (goldG > 0) Expanded(child: StatCell('Gold', formatGrams(goldG))),
              Expanded(child: StatCell('Active', '$active of ${list.length}', end: true)),
            ]),
          ),
          for (final s in list) ...[
            const Divider(),
            _SchemeRow(s),
          ],
        ]),
      ),
    );
  }
}

class _SchemeRow extends ConsumerWidget {
  const _SchemeRow(this.s);
  final SavingsEnrollment s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flexible = ref.watch(isFlexibleTypeProvider(s.schemeType));
    final summary = summarizeScheme(s);
    final maturity = schemeMaturity(s);
    return InkWell(
      onTap: s.passbookNumber == null
          ? null
          : () => context.push('/savings-scheme/passbook/${Uri.encodeComponent(s.passbookNumber!)}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          MetalBadge(gold: s.isGold, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(s.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                StatusPill(s.status, tone: schemeStatusTone(s.status)),
              ]),
              const SizedBox(height: 2),
              Text(s.passbookNumber ?? 'Passbook after first payment',
                  style: const TextStyle(fontSize: 12.5, color: Kv.muted)),
              Text(
                [
                  flexible ? formatInr(s.totalPaid) : '${summary.paidMonths} of ${summary.totalMonths} months',
                  if (maturity != null) 'matures ${_date.format(maturity.toLocal())}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12.5, color: Kv.muted),
              ),
              if (!flexible) ...[
                const SizedBox(height: 8),
                KvProgressBar(value: summary.progressPercent / 100, color: s.isGold ? Kv.gold : Kv.blue),
              ],
            ]),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Kv.subtle),
        ]),
      ),
    );
  }
}

class _OrdersSummary extends StatelessWidget {
  const _OrdersSummary(this.list);
  final List<Order> list;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: KvCard(
          child: EmptyState(
            compact: true,
            icon: Icons.shopping_bag_outlined,
            title: 'No orders yet',
            actionLabel: 'Start shopping',
            onAction: () => context.go('/shop'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
      child: KvCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, o) in list.take(3).indexed) ...[
            if (i > 0) const Divider(indent: 16),
            ListTile(
              onTap: () => context.push('/orders/${o.id}'),
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              title: Text(
                o.items.isEmpty
                    ? 'Order'
                    : o.items.length == 1
                        ? o.items.first.productName
                        : '${o.items.first.productName} + ${o.items.length - 1} more',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text([
                if (o.createdAt != null) _date.format(o.createdAt!.toLocal()),
                formatInr(o.grandTotal),
              ].join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StatusPill(o.status.label, tone: _orderTone(o.status)),
                const Icon(Icons.chevron_right_rounded, color: Kv.subtle),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
