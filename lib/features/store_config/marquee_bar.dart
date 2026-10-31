import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/pricing/pricing.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/data/catalog_repository.dart';
import '../rates/metal_key.dart';
import 'store_config.dart';

/// One scrolling item: a live rate (with a trend arrow) or an announcement.
class MarqueeUpdate {
  const MarqueeUpdate.price(this.text, [this.change]) : isPrice = true;
  const MarqueeUpdate.notification(this.text)
      : isPrice = false,
        change = null;

  final bool isPrice;
  final String text;
  final double? change;
}


/// Shown only until an admin sets custom messages (kv-ui Marquee.tsx fallbackMessages).
const _fallbackMessages = [
  MarqueeUpdate.notification('🎉 Festive Sale: Up to 25% OFF on all jewelry!'),
  MarqueeUpdate.notification('💎 New Arrival: Exclusive Temple Jewelry Collection'),
  MarqueeUpdate.notification('🏆 Join our Monthly Savings Scheme - Get 1 month bonus!'),
];

// `toLocaleString('en-IN')`: lakh grouping, up to three decimals.
final _money = NumberFormat('#,##,##0.###', 'en_IN');
String _formatMoney(double n) => '₹${_money.format(n)}';

/// The web's marquee item list, as a pure function so it can be tested.
List<MarqueeUpdate> buildMarqueeUpdates({
  required List<MetalRate> today,
  required List<MetalRate> history,
  required List<String> customMessages,
}) {
  final custom = customMessages
      .where((t) => t.trim().isNotEmpty)
      .map(MarqueeUpdate.notification)
      .toList();
  final messages = custom.isNotEmpty ? custom : _fallbackMessages;

  final rateUpdates = <MarqueeUpdate>[];
  for (final metal in MetalKey.values) {
    final current = metal.top(today);
    if (current == null) continue;
    rateUpdates.add(MarqueeUpdate.price(
      '${metal.label}: ${_formatMoney(current.ratePerKg)}/kg  |  ${_formatMoney(current.ratePerGram)}/g',
      metal.change(today, history),
    ));
  }

  return rateUpdates.isNotEmpty
      ? [...rateUpdates, ...messages]
      : [
          const MarqueeUpdate.price('Silver: Live rate update soon'),
          const MarqueeUpdate.price('Gold 22K: Live rate update soon'),
          ...messages,
        ];
}

/// Off in widget tests: an endless scroll never lets `pumpAndSettle` finish.
final marqueeAnimatedProvider = Provider<bool>((ref) => true);

/// The strip above every screen, as on the web (where it sits above the navbar).
class MarqueeBar extends ConsumerWidget {
  const MarqueeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<MetalRate> v(AsyncValue<List<MetalRate>> a) => a.valueOrNull ?? const [];
    final updates = buildMarqueeUpdates(
      today: [...v(ref.watch(silverRatesProvider)), ...v(ref.watch(goldRatesProvider))],
      history: [
        ...v(ref.watch(rateHistoryProvider((Metal.silver, 2)))),
        ...v(ref.watch(rateHistoryProvider((Metal.gold, 2)))),
      ],
      customMessages: ref.watch(storeConfigProvider)?.marqueeMessages ?? const [],
    );

    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 20,
        child: _AutoScroll(
          // Reduce-motion users get a still strip (auto-moving content must be stoppable).
          animate: ref.watch(marqueeAnimatedProvider) && !MediaQuery.disableAnimationsOf(context),
          children: [
            for (final u in updates)
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _icon(u, scheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(u.text, style: TextStyle(fontSize: 14, color: scheme.onPrimary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _icon(MarqueeUpdate u, Color fg) {
    if (!u.isPrice) return const Icon(Icons.notifications_none, size: 16, color: Color(0xFFFACC15));
    final c = u.change;
    if (c == null || c == 0) return Icon(Icons.remove, size: 16, color: fg.withValues(alpha: 0.7));
    return c > 0
        ? const Icon(Icons.trending_up, size: 16, color: Color(0xFF4ADE80))
        : const Icon(Icons.trending_down, size: 16, color: Color(0xFFF87171));
  }
}

/// Endless left scroll at 40 px/s (react-fast-marquee `speed={40} autoFill`);
/// pauses while touched, like the web's `pauseOnHover`.
class _AutoScroll extends StatefulWidget {
  const _AutoScroll({required this.children, required this.animate});

  final List<Widget> children;
  final bool animate;

  @override
  State<_AutoScroll> createState() => _AutoScrollState();
}

class _AutoScrollState extends State<_AutoScroll> with SingleTickerProviderStateMixin {
  static const _speed = 40.0;
  final _controller = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (_paused || !_controller.hasClients) return;
      _controller.jumpTo(_controller.offset + _speed * dt);
    });
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(_AutoScroll old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return Listener(
      onPointerDown: (_) => _paused = true,
      onPointerUp: (_) => _paused = false,
      onPointerCancel: (_) => _paused = false,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        // Unbounded: items repeat forever, so the strip never runs dry.
        itemBuilder: (_, i) => Center(child: widget.children[i % n]),
      ),
    );
  }
}
