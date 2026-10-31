import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/format/currency.dart';
import '../../../core/ui/kv_ui.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_grid.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../notifications/notifications.dart';
import '../../rates/metal_key.dart';
import '../../store_config/store_config.dart';

/// Category photos bundled with the app, matched to API category names by keyword.
const _categoryImages = {
  'anklet': 'assets/images/product-anklets.jpg',
  'bangle': 'assets/images/product-bangles.jpg',
  'bracelet': 'assets/images/product-bangles.jpg',
  'coin': 'assets/images/product-coins.jpg',
  'bar': 'assets/images/product-coins.jpg',
  'earring': 'assets/images/product-earrings.jpg',
  'jewel': 'assets/images/product-necklace.jpg',
  'necklace': 'assets/images/product-necklace.jpg',
  'chain': 'assets/images/product-necklace.jpg',
  'puja': 'assets/images/product-puja.jpg',
  'pooja': 'assets/images/product-puja.jpg',
  'article': 'assets/images/product-puja.jpg',
  'ring': 'assets/images/product-rings.jpg',
};

String? categoryImage(String name) {
  final n = name.toLowerCase();
  for (final e in _categoryImages.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}

String greetingFor(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';

const _banners = [
  (
    'assets/images/home_banner1.jpg',
    'Silver for every ritual',
    'Pooja articles, lamps & idols',
    '/shop?category=Puja%20Items'
  ),
  (
    'assets/images/home_banner2.jpg',
    'Crafted to be treasured',
    'BIS hallmarked · priced live daily',
    '/shop'
  ),
  (
    'assets/images/home_banner3.jpg',
    'Gifts that shine',
    'Coins, bars and gift sets',
    '/shop?category=Coins'
  ),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final featured = ref.watch(featuredProductsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final messages =
        (ref.watch(storeConfigProvider)?.marqueeMessages ?? const [])
            .where((m) => m.trim().isNotEmpty)
            .toList();
    final firstName = user?.name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(silverRatesProvider);
          ref.invalidate(goldRatesProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(rateHistoryProvider);
          await ref
              .read(featuredProductsProvider.future)
              .catchError((_) => <Product>[]);
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Kv.surface,
            titleSpacing: Kv.pad,
            title: Row(children: [
              Image.asset('assets/brand/logo_mark.png', height: 30),
              const SizedBox(width: 10),
              const Text('KV Silver Zone',
                  style: TextStyle(
                      fontFamily: Kv.serif,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Kv.ink)),
            ]),
            actions: [
              IconButton(
                tooltip: 'Wishlist',
                onPressed: () => context.push('/wishlist'),
                icon: const Icon(Icons.favorite_border_rounded),
              ),
              if (user != null)
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.notifications_none_rounded)),
                ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Kv.pad, 12, Kv.pad, 0),
                    child: Text(
                      firstName == null
                          ? 'Discover pure silver'
                          : '${greetingFor(DateTime.now())}, $firstName',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 26),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _SearchField(),
                  const SizedBox(height: 16),
                  const _RateCard(),
                  if (messages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Announcement(messages: messages),
                  ],
                  const SizedBox(height: Kv.gap),
                  const _BannerCarousel(),
                  const SizedBox(height: Kv.gap),
                  SectionHeader(
                      title: 'Shop by category',
                      action: 'See all',
                      onAction: () => context.go('/shop')),
                  const _CategoryRow(),
                  const SizedBox(height: Kv.gap),
                  SectionHeader(
                    title: 'Featured',
                    subtitle: 'Hand-picked pieces, priced at today’s rate',
                    action: 'See all',
                    onAction: () => context.go('/shop'),
                  ),
                  featured.when(
                    loading: () => const SizedBox(
                        height: 292, child: ProductGridSkeleton(count: 2)),
                    error: (_, __) => EmptyState(
                      compact: true,
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load products",
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(featuredProductsProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? const SizedBox.shrink()
                        : ProductCarousel(products: list.take(10).toList()),
                  ),
                  const SizedBox(height: Kv.gap),
                  const _SavingsPromo(),
                  const SizedBox(height: Kv.gap),
                  const _QuickLinks(),
                  const SizedBox(height: Kv.gap),
                  if ((featured.valueOrNull ?? const []).length > 2) ...[
                    SectionHeader(
                        title: 'New arrivals',
                        action: 'See all',
                        onAction: () => context.go('/shop')),
                    ProductGrid(
                        products: featured.value!.reversed.take(6).toList()),
                    const SizedBox(height: Kv.gap),
                  ],
                  const _TrustStrip(),
                  const SizedBox(height: 32),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: Material(
          color: Kv.surface,
          shape: RoundedRectangleBorder(
              borderRadius: Kv.smallRadius,
              side: const BorderSide(color: Kv.line)),
          child: InkWell(
            borderRadius: Kv.smallRadius,
            onTap: () => context.go('/shop?focus=search'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(Icons.search_rounded, color: Kv.muted),
                SizedBox(width: 10),
                Text('Search anklets, coins, pooja items…',
                    style: TextStyle(color: Kv.subtle, fontSize: 15)),
              ]),
            ),
          ),
        ),
      );
}

/// Today's silver and gold rate with the day's change; opens the rate page.
class _RateCard extends ConsumerWidget {
  const _RateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = [
      ...?ref.watch(silverRatesProvider).valueOrNull,
      ...?ref.watch(goldRatesProvider).valueOrNull,
    ];
    final history = [
      ...?ref.watch(rateHistoryProvider((Metal.silver, 2))).valueOrNull,
      ...?ref.watch(rateHistoryProvider((Metal.gold, 2))).valueOrNull,
    ];

    Widget metal(MetalKey m) {
      final rate = m.top(today);
      final change = m.change(today, history);
      return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFFAFB6C2),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rate == null ? '—' : formatInr(rate.ratePerGram),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const Padding(
              padding: EdgeInsets.only(bottom: 3, left: 2),
              child: Text('/g',
                  style: TextStyle(color: Color(0xFFAFB6C2), fontSize: 13)),
            ),
          ]),
          if (rate != null && change != 0)
            Text('${change > 0 ? '▲' : '▼'} ${formatInr(change.abs())} today',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: change > 0
                        ? const Color(0xFF6EE7A0)
                        : const Color(0xFFFCA5A5)))
          else
            Text(rate == null ? 'Updates by 10 AM' : 'No change today',
                style: const TextStyle(fontSize: 12, color: Color(0xFFAFB6C2))),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
      child: Material(
        color: Kv.ink,
        borderRadius: Kv.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/silver-rate'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: today.isEmpty
                ? const Row(children: [
                    Icon(Icons.show_chart_rounded, color: Color(0xFFAFB6C2)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's silver & gold rates",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            SizedBox(height: 2),
                            Text(
                                'Published daily by 10 AM · tap for rate history',
                                style: TextStyle(
                                    color: Color(0xFFAFB6C2), fontSize: 12.5)),
                          ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFAFB6C2)),
                  ])
                : Row(children: [
                    metal(MetalKey.silver),
                    Container(
                        width: 1, height: 48, color: const Color(0xFF3A3536)),
                    const SizedBox(width: 16),
                    metal(MetalKey.gold22k),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFAFB6C2)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _Announcement extends StatelessWidget {
  const _Announcement({required this.messages});
  final List<String> messages;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration:
              BoxDecoration(color: Kv.blueSoft, borderRadius: Kv.smallRadius),
          child: Row(children: [
            const Icon(Icons.campaign_outlined, color: Kv.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(messages.join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Kv.blueDark,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ),
          ]),
        ),
      );
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_ctrl.hasClients || !mounted || MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      _ctrl.animateToPage((_page + 1) % _banners.length,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(children: [
      SizedBox(
        height: (width * 0.92 - 8) * 0.56,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: _banners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final (image, title, subtitle, link) = _banners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: Kv.cardRadius,
                child: Material(
                  child: InkWell(
                    onTap: () => context.go(link),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(image, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xD9101014), Color(0x00101014)],
                            stops: [0, 0.75],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: width * 0.5,
                              child: Text(title,
                                  style: const TextStyle(
                                      fontFamily: Kv.serif,
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15)),
                            ),
                            const SizedBox(height: 6),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Color(0xFFD9DCE2), fontSize: 13)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999)),
                              child: const Text('Shop now',
                                  style: TextStyle(
                                      color: Kv.ink,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
                color: i == _page ? Kv.ink : const Color(0xFFD5D9E0),
                borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return SizedBox(
      height: 104,
      child: cats.when(
        loading: () => KvShimmer(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => const Column(children: [
              KvSkeleton(width: 68, height: 68, radius: 34),
              SizedBox(height: 8),
              KvSkeleton(width: 56, height: 10),
            ]),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (all) {
          // A category with no products yet would open an empty shop page: leave it out
          // until the admin adds products (it shows while its count is still loading).
          final list = [
            for (final c in all)
              if (ref
                      .watch(productsInCategoryProvider(c.name))
                      .valueOrNull
                      ?.isEmpty !=
                  true)
                c,
          ];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final name = list[i].name;
              final image = categoryImage(name);
              // No studio photo for this category: show one of its own products instead.
              final productImage = image != null
                  ? null
                  : ref
                      .watch(productsInCategoryProvider(name))
                      .valueOrNull
                      ?.where((p) => p.primaryImage != null)
                      .firstOrNull
                      ?.primaryImage;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go(
                    Uri(path: '/shop', queryParameters: {'category': name})
                        .toString()),
                child: SizedBox(
                  width: 72,
                  child: Column(children: [
                    Container(
                      width: 68,
                      height: 68,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Kv.blueSoft,
                        border: Border.all(color: Kv.line),
                      ),
                      child: image != null
                          ? Image.asset(image, fit: BoxFit.cover)
                          : productImage != null
                              ? ProductImageView(
                                  image: productImage, decodeWidth: 140)
                              : const Icon(Icons.diamond_outlined,
                                  color: Kv.blue, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavingsPromo extends StatelessWidget {
  const _SavingsPromo();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        child: KvCard(
          padding: EdgeInsets.zero,
          onTap: () => context.go('/savings-scheme'),
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusPill('Monthly savings',
                          tone: PillTone.gold, icon: Icons.savings_outlined),
                      const SizedBox(height: 10),
                      const Text('Save a little every month, own more silver',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3)),
                      const SizedBox(height: 6),
                      const Text(
                          'Each instalment is locked in at that day’s rate, plus a bonus month.',
                          style: TextStyle(
                              fontSize: 13, color: Kv.muted, height: 1.4)),
                      const SizedBox(height: 12),
                      Row(children: const [
                        Text('Explore schemes',
                            style: TextStyle(
                                color: Kv.blue, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: Kv.blue),
                      ]),
                    ]),
              ),
            ),
            SizedBox(
              width: 112,
              height: 172,
              child: Image.asset('assets/images/savings-scheme.jpg',
                  fit: BoxFit.cover),
            ),
          ]),
        ),
      );
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String path) => Expanded(
          child: KvCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            onTap: () => context.push(path),
            child: Column(children: [
              Icon(icon, color: Kv.blue),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
      child: Row(children: [
        tile(Icons.local_offer_outlined, 'Offers', '/offers'),
        const SizedBox(width: 10),
        tile(Icons.card_giftcard_outlined, 'Gift vouchers', '/gift-vouchers'),
        const SizedBox(width: 10),
        tile(Icons.show_chart_rounded, 'Rate history', '/silver-rate'),
      ]),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String sub) => Expanded(
          child: Column(children: [
            Icon(icon, color: Kv.ink, size: 22),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Kv.muted)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Kv.pad),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFEEF0F3), borderRadius: Kv.cardRadius),
      child: Row(children: [
        item(Icons.verified_outlined, 'BIS hallmarked', 'Purity assured'),
        item(Icons.local_shipping_outlined, 'Insured shipping', 'Across India'),
        item(Icons.currency_exchange_rounded, 'Easy buyback', 'At live rates'),
      ]),
    );
  }
}
