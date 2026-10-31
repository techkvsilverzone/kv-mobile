import 'package:flutter/material.dart';
import '../../../core/widgets/page_header.dart';

/// Port of kv-ui `pages/About.tsx`; copy is verbatim. The web's `stats` array
/// is declared but never rendered there, so it is not ported.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _collection = [
    'Traditional Kutthuvilakku (Lamp)',
    'Kudam & Puja Items',
    'Plates, Tumblers & Dinner Sets',
    'Jug Sets & Bowls with Trays',
    'Silver Gift Articles',
    'Customized Silver Products',
    'Intricate Kovil Work',
    'God Kavasam',
    'Silver Coins',
  ];

  static const _values = [
    (Icons.workspace_premium_outlined, 'Quality Assurance',
        'Every piece is BIS hallmarked and certified for purity'),
    (Icons.people_outline, 'Customer First', 'Dedicated to providing exceptional service and support'),
    (Icons.history, 'Heritage Craftsmanship', 'Traditional techniques passed down through generations'),
    (Icons.track_changes, 'Fair Pricing', 'Transparent pricing with no hidden charges'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.6);
    final quote = theme.textTheme.bodyLarge?.copyWith(fontSize: 20, color: cs.onSurfaceVariant);
    final primaryHeading = theme.textTheme.headlineMedium?.copyWith(color: cs.primary);
    final heading = theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text('Celebrating the Timeless Elegance of Silver',
                    textAlign: TextAlign.center,
                    // The web hardcodes `text-white` on this heading.
                    style: theme.textTheme.headlineLarge
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Text(
                  'At KV SILVER ZONE, we celebrate the timeless elegance and beauty of silver. '
                  'Established with a passion for exquisite craftsmanship and exceptional quality, '
                  'we are a premier destination for both wholesale and retail silver articles.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w300,
                      height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text('A Legacy of Quality', style: primaryHeading),
          const SizedBox(height: 24),
          Text(
            'Our journey began with a vision to offer discerning individuals pieces that not only '
            'reflect their unique style but also endure as cherished heirlooms. Each item in our '
            'collection is carefully curated to ensure it meets our exacting standards for '
            'craftsmanship, design, and durability.',
            style: body,
          ),
          const SizedBox(height: 24),
          Text(
            'Beyond our commitment to exquisite silver pieces, we prioritize customer satisfaction '
            'above all else. Our dedicated team is here to assist you every step of the way in '
            'finding the perfect piece.',
            style: body,
          ),
          // The web puts the banner below the story text on narrow screens (order-2).
          const SizedBox(height: 48),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/about_banner.jpg',
                height: 400, width: double.infinity, fit: BoxFit.cover, semanticLabel: 'Silver Craftsmanship'),
          ),
          const SizedBox(height: 48),
          Text('Our Collection & Services', textAlign: TextAlign.center, style: primaryHeading),
          const SizedBox(height: 32),
          for (final item in _collection)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(item,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
              ),
            ),
          const SizedBox(height: 48),
          Text('Visit Us Today',
              textAlign: TextAlign.center,
              style: primaryHeading?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          Text(
            '"Thank you for visiting KV SILVER ZONE. We invite you to explore our collection and '
            'discover the perfect silver piece that speaks to you."',
            textAlign: TextAlign.center,
            style: quote?.copyWith(fontWeight: FontWeight.w300, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 64),
          Text('Our Values', textAlign: TextAlign.center, style: heading),
          const SizedBox(height: 8),
          Text('The principles that guide everything we do',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 32),
          for (final (icon, title, description) in _values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InfoCard(icon: icon, title: title, body: description),
            ),
          const SizedBox(height: 48),
          Text('Our Mission', textAlign: TextAlign.center, style: heading),
          const SizedBox(height: 24),
          Text(
            '"To bring the timeless beauty of pure silver into every home, crafted with love, '
            'certified for quality, and priced for accessibility. We believe everyone deserves to '
            'own a piece of silver that they can cherish and pass down through generations."',
            textAlign: TextAlign.center,
            style: quote,
          ),
          const SizedBox(height: 24),
          Text('— The KV Silver Zone Family',
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
        ],
      ),
    );
  }
}
