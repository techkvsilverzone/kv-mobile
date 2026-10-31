import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/widgets/page_header.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../metal_key.dart';

const _green = Color(0xFF16A34A); // text-green-600

/// One row of the 30-day table: a calendar day with each metal's per-gram rate.
class RateHistoryRow {
  const RateHistoryRow(this.day, this.silver, this.gold);
  final String day; // YYYY-MM-DD
  final double? silver;
  final double? gold;
}

/// Groups history by day, newest first, at most 30 rows (kv-ui SilverRate.tsx).
List<RateHistoryRow> groupRateHistory(List<MetalRate> history) {
  final byDay = <String, Map<MetalKey, double>>{};
  for (final r in history) {
    if (r.date.length < 10) continue;
    final metal = MetalKey.values.where((m) => m.matches(r)).firstOrNull;
    if (metal == null) continue;
    (byDay[r.date.substring(0, 10)] ??= {})[metal] = r.ratePerGram;
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days.take(30))
      RateHistoryRow(d, byDay[d]![MetalKey.silver], byDay[d]![MetalKey.gold22k]),
  ];
}

/// `/silver-rate`: today's silver and gold 22K rates, the change since the
/// previous day, a 30-day history table, and the pricing / buyback notes.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silverToday = ref.watch(silverRatesProvider);
    final goldToday = ref.watch(goldRatesProvider);
    final silverHist = ref.watch(rateHistoryProvider((Metal.silver, 30)));
    final goldHist = ref.watch(rateHistoryProvider((Metal.gold, 30)));

    final todayLoading = silverToday.isLoading || goldToday.isLoading;
    final historyLoading = silverHist.isLoading || goldHist.isLoading;
    final today = [...?silverToday.valueOrNull, ...?goldToday.valueOrNull];
    final history = [...?silverHist.valueOrNull, ...?goldHist.valueOrNull];

    return Scaffold(
      appBar: AppBar(title: const Text('Silver Rate')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(silverRatesProvider);
          ref.invalidate(goldRatesProvider);
          ref.invalidate(rateHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (!todayLoading) _Ticker(today: today, history: history),
            const PageHeader(
              eyebrow: 'Updated Daily',
              title: "Today's Metal Rates",
              subtitle: 'Live Silver and Gold 22K prices at KV Silver Zone. Our rates are updated '
                  'daily based on market rates from the India Bullion and Jewellers Association (IBJA).',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (todayLoading)
                    const Padding(
                        padding: EdgeInsets.all(48), child: CircularProgressIndicator())
                  else ...[
                    for (final (metal, description) in const [
                      (MetalKey.silver, 'Daily live silver market price'),
                      (MetalKey.gold22k, 'Daily live 22K gold market price'),
                    ]) ...[
                      _RateCard(
                          metal: metal, description: description, today: today, history: history),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),
                    _HistoryCard(loading: historyLoading, rows: groupRateHistory(history)),
                  ],
                  const SizedBox(height: 32),
                  const InfoCard(
                    title: 'Making Charges',
                    body: 'Product prices include silver rate + making charges + GST (3% on silver '
                        'value + 5% on making charges). Making charges vary by product complexity '
                        'and design.',
                  ),
                  const SizedBox(height: 16),
                  const InfoCard(
                    title: 'Buyback Policy',
                    body: 'We offer buyback on all KV Silver Zone products at the prevailing silver '
                        'rate minus 2% deduction. Bring your product with the original invoice for '
                        'hassle-free buyback.',
                  ),
                  const SizedBox(height: 32),
                  Text('Want to invest smartly? Start one of our Monthly Savings Schemes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                          onPressed: () => context.push('/shop'), child: const Text('Shop Now')),
                      const SizedBox(width: 16),
                      OutlinedButton(
                          onPressed: () => context.push('/savings-scheme'),
                          child: const Text('Savings Scheme')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _trendColor(BuildContext context, double change) => change > 0
    ? _green
    : change < 0
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

Widget _trendIcon(BuildContext context, double change) => Icon(
      change > 0
          ? Icons.trending_up
          : change < 0
              ? Icons.trending_down
              : Icons.remove,
      size: 16,
      color: _trendColor(context, change),
    );

String _signed(double change) => '${change >= 0 ? '+' : ''}${formatInr(change)}';

/// The muted ticker the web shows above the header, only when a rate exists.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.today, required this.history});

  final List<MetalRate> today;
  final List<MetalRate> history;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final m in MetalKey.values)
        if (m.top(today) != null) (m, m.top(today)!, m.change(today, history)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        border: Border.symmetric(horizontal: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 32,
        runSpacing: 4,
        children: [
          for (final (metal, rate, change) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _trendIcon(context, change),
              const SizedBox(width: 6),
              Text('${metal.label}: ', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${formatInr(rate.ratePerGram)}/g '),
              Text('(${_signed(change)})', style: TextStyle(color: _trendColor(context, change))),
            ]),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard(
      {required this.metal, required this.description, required this.today, required this.history});

  final MetalKey metal;
  final String description;
  final List<MetalRate> today;
  final List<MetalRate> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final rate = metal.top(today);
    final prev = metal.previous(history);
    final change = metal.change(today, history);
    final pct = prev == null || rate == null ? 0.0 : change / prev.ratePerGram * 100;

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(metal.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontSize: 10, color: muted)),
            const SizedBox(height: 16),
            Text(rate == null ? '—' : formatInr(rate.ratePerGram),
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Text('per gram', style: TextStyle(fontSize: 12, color: muted)),
            if (rate != null) ...[
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _trendIcon(context, change),
                const SizedBox(width: 8),
                Text('${_signed(change)} (${pct.toStringAsFixed(2)}%)',
                    style: TextStyle(color: _trendColor(context, change))),
              ]),
              if (rate.ratePerKg != 0) ...[
                const SizedBox(height: 12),
                Text('${formatInr(rate.ratePerKg)} / kg', style: TextStyle(color: muted)),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.loading, required this.rows});

  final bool loading;
  final List<RateHistoryRow> rows;

  static final _date = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String cell(double? v) => v == null || v == 0 ? '—' : formatInr(v);
    String day(String d) {
      final parsed = DateTime.tryParse(d);
      return parsed == null ? '—' : _date.format(parsed);
    }

    Widget row(List<String> cells, {bool header = false}) => Container(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline))),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: Text(cells[i],
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: header ? muted : null)),
              ),
          ]),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30-Day Price History',
                style:
                    theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text('Rate history will appear here once prices are updated.',
                        textAlign: TextAlign.center, style: TextStyle(color: muted))),
              )
            else ...[
              row(['Date', 'Silver (₹/g)', 'Gold 22K (₹/g)'], header: true),
              for (final r in rows) row([day(r.day), cell(r.silver), cell(r.gold)]),
            ],
          ],
        ),
      ),
    );
  }
}
