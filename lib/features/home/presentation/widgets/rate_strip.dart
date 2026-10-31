import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/pricing/pricing.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/data/catalog_repository.dart';
import '../../../rates/metal_key.dart';

/// kv-ui FloatingRateWidget: today's Silver / Gold 22K per-gram rate with a
/// day-over-day trend arrow, linking to the rate page. Hidden when neither
/// metal has a rate today.
class RateStrip extends ConsumerWidget {
  const RateStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<MetalRate> v(AsyncValue<List<MetalRate>> a) => a.valueOrNull ?? const [];
    final today = [...v(ref.watch(silverRatesProvider)), ...v(ref.watch(goldRatesProvider))];
    final history = [
      ...v(ref.watch(rateHistoryProvider((Metal.silver, 2)))),
      ...v(ref.watch(rateHistoryProvider((Metal.gold, 2)))),
    ];
    final rows = [
      for (final metal in MetalKey.values)
        if (metal.top(today) case final current?) (metal, current, metal.change(today, history)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/silver-rate'),
        child: Column(
          children: [
            Container(
              color: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text("TODAY'S RATE",
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimary, letterSpacing: 1.2)),
                  const Spacer(),
                  Icon(Icons.north_east, size: 14, color: scheme.onPrimary.withValues(alpha: 0.7)),
                ],
              ),
            ),
            for (final (metal, current, change) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: metal == MetalKey.silver
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(metal.label, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(formatRatePerGram(current.ratePerGram),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    if (change > 0)
                      const Icon(Icons.trending_up, size: 14, color: Color(0xFF16A34A))
                    else if (change < 0)
                      Icon(Icons.trending_down, size: 14, color: scheme.error)
                    else
                      Icon(Icons.remove, size: 14, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
