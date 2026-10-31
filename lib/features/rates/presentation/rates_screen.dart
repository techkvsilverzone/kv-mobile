import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/ui/kv_ui.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../metal_key.dart';

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

final _change = NumberFormat('#,##,##0.##', 'en_IN');
final _day = DateFormat('d MMM');
final _dayFull = DateFormat('EEE, d MMM y');

String _fmtDay(String d, DateFormat f) {
  final parsed = DateTime.tryParse(d);
  return parsed == null ? '—' : f.format(parsed);
}

/// `/silver-rate`: today's silver and gold 22K rates with the day's change, a 30-day
/// chart and list, and the making-charge / buyback notes.
class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  MetalKey _chartMetal = MetalKey.silver;
  bool _allDays = false;

  @override
  Widget build(BuildContext context) {
    final silverToday = ref.watch(silverRatesProvider);
    final goldToday = ref.watch(goldRatesProvider);
    final silverHist = ref.watch(rateHistoryProvider((Metal.silver, 30)));
    final goldHist = ref.watch(rateHistoryProvider((Metal.gold, 30)));

    final todayLoading = silverToday.isLoading || goldToday.isLoading;
    final historyLoading = silverHist.isLoading || goldHist.isLoading;
    final today = [...?silverToday.valueOrNull, ...?goldToday.valueOrNull];
    final history = [...?silverHist.valueOrNull, ...?goldHist.valueOrNull];
    final rows = groupRateHistory(history);
    final updated = MetalKey.silver.top(today)?.date ?? MetalKey.gold22k.top(today)?.date;

    Future<void> refresh() async {
      ref.invalidate(silverRatesProvider);
      ref.invalidate(goldRatesProvider);
      ref.invalidate(rateHistoryProvider);
      await ref.read(silverRatesProvider.future).catchError((_) => <MetalRate>[]);
    }

    final List<Widget> todayCards;
    if (todayLoading) {
      todayCards = [
        const KvShimmer(
          child: Row(children: [
            Expanded(child: KvSkeleton(height: 150, radius: Kv.radius)),
            SizedBox(width: 12),
            Expanded(child: KvSkeleton(height: 150, radius: Kv.radius)),
          ]),
        ),
      ];
    } else if (today.isEmpty) {
      todayCards = [
        KvCard(
          child: EmptyState(
            compact: true,
            icon: Icons.show_chart_rounded,
            title: 'Today’s rates aren’t out yet',
            message: 'Rates are published every morning by 10 AM.',
            actionLabel: 'Try again',
            onAction: refresh,
          ),
        ),
      ];
    } else {
      todayCards = [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _MetalCard(metal: MetalKey.silver, today: today, history: history)),
            const SizedBox(width: 12),
            Expanded(child: _MetalCard(metal: MetalKey.gold22k, today: today, history: history)),
          ]),
        ),
      ];
    }

    final points = [
      for (final r in rows.reversed)
        if ((_chartMetal == MetalKey.silver ? r.silver : r.gold) case final v? when v != 0) (r.day, v),
    ];
    final visibleRows = _allDays ? rows : rows.take(7).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Silver & gold rates')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, 12, Kv.pad, 32), children: [
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 15, color: Kv.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                updated == null ? 'Updated daily from IBJA market rates' : 'Updated ${_fmtDay(updated, _dayFull)} · IBJA rates',
                style: const TextStyle(fontSize: 12.5, color: Kv.muted),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...todayCards,
          const SizedBox(height: Kv.gap),

          // Chart
          KvCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Last 30 days', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                SegmentedButton<MetalKey>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    selectedBackgroundColor: Kv.ink,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: Kv.ink,
                    side: const BorderSide(color: Kv.line),
                    textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  segments: const [
                    ButtonSegment(value: MetalKey.silver, label: Text('Silver')),
                    ButtonSegment(value: MetalKey.gold22k, label: Text('Gold')),
                  ],
                  selected: {_chartMetal},
                  onSelectionChanged: (s) => setState(() => _chartMetal = s.first),
                ),
              ]),
              const SizedBox(height: 16),
              if (historyLoading)
                const KvShimmer(child: KvSkeleton(height: 160, radius: 12))
              else if (points.length < 2)
                const SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('The chart appears once there are a few days of rates.',
                        textAlign: TextAlign.center, style: TextStyle(color: Kv.muted)),
                  ),
                )
              else
                _Chart(points: points, color: _chartMetal == MetalKey.gold22k ? Kv.gold : Kv.blue),
            ]),
          ),
          const SizedBox(height: Kv.gap),

          // History list
          if (!historyLoading && rows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 10),
              child: Text('Daily rates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            KvCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(children: [
                    Expanded(child: Text('Date', style: _head)),
                    Expanded(child: Text('Silver /g', textAlign: TextAlign.right, style: _head)),
                    Expanded(child: Text('Gold 22K /g', textAlign: TextAlign.right, style: _head)),
                  ]),
                ),
                for (final r in visibleRows) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Expanded(child: Text(_fmtDay(r.day, _day), style: const TextStyle(fontWeight: FontWeight.w500))),
                      Expanded(child: Text(_cell(r.silver), textAlign: TextAlign.right)),
                      Expanded(child: Text(_cell(r.gold), textAlign: TextAlign.right)),
                    ]),
                  ),
                ],
                if (rows.length > 7) ...[
                  const Divider(),
                  TextButton(
                    onPressed: () => setState(() => _allDays = !_allDays),
                    child: Text(_allDays ? 'Show less' : 'Show all ${rows.length} days'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: Kv.gap),
          ],

          // Notes
          const Row(children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.handyman_outlined,
                title: 'Making charges',
                short: 'Rate + making + GST',
                body: 'Product prices include silver rate + making charges + GST (3% on silver value + 5% on '
                    'making charges). Making charges vary by product complexity and design.',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Buyback',
                short: 'Today’s rate minus 2%',
                body: 'We offer buyback on all KV Silver Zone products at the prevailing silver rate minus 2% '
                    'deduction. Bring your product with the original invoice for hassle-free buyback.',
              ),
            ),
          ]),
          const SizedBox(height: 12),
          KvCard(
            onTap: () => context.go('/savings-scheme'),
            child: const Row(children: [
              Icon(Icons.savings_outlined, color: Kv.gold),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Buy at today’s rate, every month', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Explore savings schemes', style: TextStyle(fontSize: 12.5, color: Kv.muted)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Kv.subtle),
            ]),
          ),
        ]),
      ),
    );
  }
}

const _head = TextStyle(fontSize: 12, color: Kv.muted, fontWeight: FontWeight.w600);
String _cell(double? v) => v == null || v == 0 ? '—' : formatInr(v);

class _MetalCard extends StatelessWidget {
  const _MetalCard({required this.metal, required this.today, required this.history});

  final MetalKey metal;
  final List<MetalRate> today;
  final List<MetalRate> history;

  @override
  Widget build(BuildContext context) {
    final gold = metal == MetalKey.gold22k;
    final rate = metal.top(today);
    final prev = metal.previous(history);
    final change = metal.change(today, history);
    final pct = prev == null || rate == null || prev.ratePerGram == 0 ? 0.0 : change / prev.ratePerGram * 100;
    final tone = change > 0 ? PillTone.success : (change < 0 ? PillTone.danger : PillTone.neutral);
    final changeLabel = change == 0
        ? 'No change'
        : '${change > 0 ? '▲' : '▼'} ₹${_change.format(change.abs())} (${pct.abs().toStringAsFixed(2)}%)';

    return KvCard(
      color: gold ? Kv.goldSoft : null,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: gold ? Kv.gold : Kv.subtle),
          ),
          const SizedBox(width: 6),
          Text(metal.label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: gold ? const Color(0xFF8A6A2A) : Kv.muted)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(rate == null ? '—' : formatInr(rate.ratePerGram),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 4, left: 2),
            child: Text('/g', style: TextStyle(color: Kv.muted, fontSize: 13)),
          ),
        ]),
        if (rate != null && rate.ratePerKg != 0)
          Text('${formatInr(rate.ratePerKg)} /kg', style: const TextStyle(fontSize: 12.5, color: Kv.muted)),
        const Spacer(),
        const SizedBox(height: 12),
        if (rate != null) StatusPill(changeLabel, tone: tone) else const Text('Not published', style: TextStyle(color: Kv.muted)),
      ]),
    );
  }
}

/// 30-day line with high / low and first / last dates.
class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.color});

  /// (YYYY-MM-DD, ₹/g), oldest first.
  final List<(String, double)> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final values = [for (final p in points) p.$2];
    final hi = values.reduce((a, b) => a > b ? a : b);
    final lo = values.reduce((a, b) => a < b ? a : b);
    const small = TextStyle(fontSize: 11.5, color: Kv.muted);
    return Semantics(
      label: 'Rate chart, ${points.length} days, high ${formatInr(hi)}, low ${formatInr(lo)}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('High ${formatInr(hi)}', style: small.copyWith(color: Kv.ink, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text('Low ${formatInr(lo)}', style: small.copyWith(color: Kv.ink, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 150, child: CustomPaint(painter: _LinePainter(values, color: color))),
        const SizedBox(height: 8),
        Row(children: [
          Text(_fmtDay(points.first.$1, _day), style: small),
          const Spacer(),
          Text(_fmtDay(points.last.$1, _day), style: small),
        ]),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, {required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final hi = values.reduce((a, b) => a > b ? a : b);
    final lo = values.reduce((a, b) => a < b ? a : b);
    // Flat series sit mid-height; otherwise leave 8% headroom top and bottom.
    final span = hi - lo == 0 ? 1.0 : (hi - lo) * 1.16;
    final base = hi - lo == 0 ? lo - 0.5 : lo - (hi - lo) * 0.08;
    Offset at(int i) => Offset(
          values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1),
          size.height - (values[i] - base) / span * size.height,
        );

    final grid = Paint()
      ..color = Kv.line
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = size.height * k / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final last = at(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = Kv.surface);
    canvas.drawCircle(last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.color != color;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.short, required this.body});
  final IconData icon;
  final String title, short, body;

  @override
  Widget build(BuildContext context) => KvCard(
        padding: const EdgeInsets.all(14),
        onTap: () => showKvSheet<void>(
          context,
          title: title,
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Text(body, style: const TextStyle(fontSize: 15, height: 1.5, color: Kv.muted)),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: Kv.ink),
            const Spacer(),
            const Icon(Icons.info_outline_rounded, size: 16, color: Kv.subtle),
          ]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(short, style: const TextStyle(fontSize: 12.5, color: Kv.muted)),
        ]),
      );
}
