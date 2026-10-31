import '../../core/pricing/pricing.dart';

/// The web's `getMetalKey` (Marquee.tsx, SilverRate.tsx): which metal a rate row
/// is, by its purity label. '916' bare is what the API returns for gold.
enum MetalKey {
  silver('Silver', {'silver', '999', '999 fine silver', 'silver 999'}),
  gold22k('Gold 22K', {'gold22k', 'gold 22k', '22k', 'gold-22k', '916 gold', '916'});

  const MetalKey(this.label, this._aliases);
  final String label;
  final Set<String> _aliases;

  bool matches(MetalRate r) => _aliases.contains(r.purity.trim().toLowerCase());

  /// First of today's rows for this metal (`getTopRate`).
  MetalRate? top(List<MetalRate> today) => today.where(matches).firstOrNull;

  /// The second-newest history row (`getPreviousRate`): yesterday's rate.
  MetalRate? previous(List<MetalRate> history) {
    final sorted = history.where(matches).toList()..sort((a, b) => b.date.compareTo(a.date));
    return sorted.length > 1 ? sorted[1] : null;
  }

  /// Day-over-day change per gram; 0 without both rows.
  double change(List<MetalRate> today, List<MetalRate> history) {
    final c = top(today), p = previous(history);
    return c == null || p == null ? 0 : c.ratePerGram - p.ratePerGram;
  }
}
