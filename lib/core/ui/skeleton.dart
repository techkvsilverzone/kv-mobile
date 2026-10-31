import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Shimmering placeholder block. Wrap several in [KvShimmer] for one sweep.
class KvSkeleton extends StatelessWidget {
  const KvSkeleton({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE9ECF0), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Sweeps a soft highlight across its children (skeleton loading).
class KvShimmer extends StatefulWidget {
  const KvShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<KvShimmer> createState() => _KvShimmerState();
}

class _KvShimmerState extends State<KvShimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still placeholders for reduce-motion users (and in widget tests that settle).
    if (MediaQuery.disableAnimationsOf(context) || TickerMode.valuesOf(context).enabled == false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: const [Color(0xFFE9ECF0), Color(0xFFF6F7F9), Color(0xFFE9ECF0)],
          ).createShader(rect),
          child: child,
        ),
        child: widget.child,
      );
}

/// Grid of product-card placeholders.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => KvShimmer(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: 0.64),
          itemCount: count,
          itemBuilder: (_, __) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 1, child: KvSkeleton(radius: Kv.radius)),
            SizedBox(height: 10),
            KvSkeleton(width: 120),
            SizedBox(height: 8),
            KvSkeleton(width: 70, height: 16),
          ]),
        ),
      );
}

/// Stacked list-row placeholders.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 4, this.height = 84});
  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) => KvShimmer(
        child: Column(children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 12),
              child: KvSkeleton(height: height, radius: Kv.radius),
            ),
        ]),
      );
}
