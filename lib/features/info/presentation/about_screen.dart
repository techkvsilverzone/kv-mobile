import 'package:flutter/material.dart';
import '../../../core/ui/kv_ui.dart';
import 'widgets/store_card.dart';

/// Port of kv-ui `pages/About.tsx`, laid out app-style; copy is the web's. The web's
/// `stats` array is declared but never rendered there, so it is not ported.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _collection = [
    (Icons.light_outlined, 'Traditional Kutthuvilakku (Lamp)'),
    (Icons.temple_hindu_outlined, 'Kudam & Puja Items'),
    (Icons.dinner_dining_outlined, 'Plates, Tumblers & Dinner Sets'),
    (Icons.local_drink_outlined, 'Jug Sets & Bowls with Trays'),
    (Icons.card_giftcard_outlined, 'Silver Gift Articles'),
    (Icons.design_services_outlined, 'Customized Silver Products'),
    (Icons.account_balance_outlined, 'Intricate Kovil Work'),
    (Icons.shield_outlined, 'God Kavasam'),
    (Icons.monetization_on_outlined, 'Silver Coins'),
  ];

  static const _values = [
    (Icons.workspace_premium_outlined, 'Quality Assurance', 'Every piece is BIS hallmarked and certified for purity'),
    (Icons.people_outline, 'Customer First', 'Dedicated to providing exceptional service and support'),
    (Icons.history, 'Heritage Craftsmanship', 'Traditional techniques passed down through generations'),
    (Icons.track_changes, 'Fair Pricing', 'Transparent pricing with no hidden charges'),
  ];

  static const _body = TextStyle(fontSize: 15, height: 1.6, color: Kv.ink);

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Kv.gap);

    return Scaffold(
      appBar: AppBar(title: const Text('About us')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 260,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/about_banner.jpg', fit: BoxFit.cover, semanticLabel: 'Silver Craftsmanship'),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Kv.ink.withValues(alpha: 0), Kv.ink.withValues(alpha: 0.85)],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              const Positioned(
                left: Kv.pad,
                right: Kv.pad,
                bottom: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Celebrating the Timeless Elegance of Silver',
                      style: TextStyle(
                          fontFamily: Kv.serif, fontSize: 26, height: 1.2, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Kv.pad, 20, Kv.pad, 32),
          sliver: SliverList.list(children: [
            const Text(
              'At KV SILVER ZONE, we celebrate the timeless elegance and beauty of silver. Established with a passion '
              'for exquisite craftsmanship and exceptional quality, we are a premier destination for both wholesale '
              'and retail silver articles.',
              style: TextStyle(fontSize: 16, height: 1.6, color: Kv.ink),
            ),
            gap,
            const SectionHeader(title: 'A Legacy of Quality', padding: EdgeInsets.only(bottom: 8)),
            const Text(
              'Our journey began with a vision to offer discerning individuals pieces that not only reflect their '
              'unique style but also endure as cherished heirlooms. Each item in our collection is carefully curated '
              'to ensure it meets our exacting standards for craftsmanship, design, and durability.',
              style: _body,
            ),
            const SizedBox(height: 12),
            const Text(
              'Beyond our commitment to exquisite silver pieces, we prioritize customer satisfaction above all else. '
              'Our dedicated team is here to assist you every step of the way in finding the perfect piece.',
              style: _body,
            ),
            gap,
            const SectionHeader(title: 'Our Values', subtitle: 'The principles that guide everything we do', padding: EdgeInsets.only(bottom: 12)),
            for (var r = 0; r < _values.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 10),
              // Equal-height cards that grow with the text (no fixed aspect ratio).
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, (icon, title, description)) in _values.sublist(r, r + 2).indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: KvCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Kv.blueSoft, shape: BoxShape.circle),
                            child: Icon(icon, size: 19, color: Kv.blue),
                          ),
                          const SizedBox(height: 10),
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(description, style: const TextStyle(color: Kv.muted, fontSize: 12.5, height: 1.4)),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
            gap,
            const SectionHeader(title: 'Our Collection & Services', padding: EdgeInsets.only(bottom: 4)),
            KvCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (i, (icon, item)) in _collection.indexed) ...[
                  if (i > 0) const Divider(indent: 52),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(icon, size: 20, color: Kv.gold),
                      const SizedBox(width: 16),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 14.5))),
                    ]),
                  ),
                ],
              ]),
            ),
            gap,
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Kv.ink, borderRadius: Kv.cardRadius),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('OUR MISSION',
                    style: TextStyle(color: Kv.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                SizedBox(height: 10),
                Text(
                  '"To bring the timeless beauty of pure silver into every home, crafted with love, certified for '
                  'quality, and priced for accessibility. We believe everyone deserves to own a piece of silver that '
                  'they can cherish and pass down through generations."',
                  style: TextStyle(fontFamily: Kv.serif, fontStyle: FontStyle.italic, color: Colors.white, fontSize: 17, height: 1.5),
                ),
                SizedBox(height: 12),
                Text('— The KV Silver Zone Family', style: TextStyle(color: Kv.subtle, fontSize: 13)),
              ]),
            ),
            gap,
            const SectionHeader(title: 'Visit Us Today', padding: EdgeInsets.only(bottom: 8)),
            const Text(
              '"Thank you for visiting KV SILVER ZONE. We invite you to explore our collection and discover the '
              'perfect silver piece that speaks to you."',
              style: TextStyle(fontSize: 14, height: 1.55, color: Kv.muted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 14),
            const StoreCard(),
            const SizedBox(height: 12),
            const StoreActions(),
          ]),
        ),
      ]),
    );
  }
}
