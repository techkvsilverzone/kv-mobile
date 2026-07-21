import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/pricing/pricing.dart';
import '../../../catalog/application/catalog_providers.dart';

/// Today's silver and gold per-gram rates.
///
/// Hides entirely when neither metal has a rate for the day — which is the
/// current state of the database, so this renders nothing rather than an empty
/// shell. Matches the web widget's "hide when both rows are empty" behaviour,
/// minus the trend arrows (the app has no rate-history need yet).
class RateStrip extends ConsumerWidget {
  const RateStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silver = ref.watch(silverRatesProvider).valueOrNull ?? const [];
    final gold = ref.watch(goldRatesProvider).valueOrNull ?? const [];

    final rows = <_RateRow>[
      if (_rate(silver) != null) _RateRow(label: 'Silver', rate: _rate(silver)!),
      if (_rate(gold) != null) _RateRow(label: 'Gold 22K', rate: _rate(gold)!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text("Today's rate", style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          for (final row in rows) ...[
            Text('${row.label} ',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            Text(formatRatePerGram(row.rate),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (row != rows.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  /// The highest-purity rate reads best as "today's rate"; fall back to the
  /// first row otherwise.
  double? _rate(List<MetalRate> rates) {
    if (rates.isEmpty) return null;
    return rates.first.ratePerGram;
  }
}

class _RateRow {
  const _RateRow({required this.label, required this.rate});
  final String label;
  final double rate;
}
