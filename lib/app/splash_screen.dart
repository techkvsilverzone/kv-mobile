import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_session.dart';
import '../core/ui/kv_ui.dart';

/// True once the splash animation has played; the router holds `/splash` until then.
final splashDoneProvider = StateProvider<bool>((ref) => false);

/// Whether the splash animates (off in widget tests, which can't wait on it).
final splashAnimatedProvider = Provider<bool>((ref) => true);

/// Animated brand splash, shown while the stored session is checked.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));

  // Logo settles in, a silver shine sweeps it, then the name and tagline rise.
  late final _logoIn = CurvedAnimation(parent: _c, curve: const Interval(0, 0.40));
  late final _shine = CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.80, curve: Curves.easeInOut));
  late final _name = CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic));
  late final _tag = CurvedAnimation(parent: _c, curve: const Interval(0.60, 1, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authSessionProvider.notifier).restoreSession());
    if (ref.read(splashAnimatedProvider)) {
      _c.forward().whenComplete(_done);
    } else {
      _c.value = 1;
      Future.microtask(_done);
    }
  }

  void _done() {
    if (mounted) ref.read(splashDoneProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authSessionProvider).restoreError;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        // A faint silver glow behind the mark.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: [Kv.blueSoft.withValues(alpha: 0.55), Colors.white],
              ),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              Opacity(
                opacity: 1,
                child: Transform.scale(
                  // A gentle settle from the native splash's resting mark.
                  scale: 1 + 0.04 * Curves.easeInOut.transform((_logoIn.value * 2 - 1).abs() < 1 ? 1 - (_logoIn.value * 2 - 1).abs() : 0),
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment(-2.2 + 4.4 * _shine.value, -0.6),
                      end: Alignment(-1.6 + 4.4 * _shine.value, 0.6),
                      colors: [Colors.transparent, Colors.white.withValues(alpha: 0.75), Colors.transparent],
                    ).createShader(r),
                    child: Image.asset('assets/brand/logo_mark.png', height: 112, semanticLabel: 'KV Silver Zone'),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Opacity(
                opacity: _name.value,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - _name.value)),
                  child: const Text('KV SILVER ZONE',
                      style: TextStyle(
                          fontFamily: Kv.serif, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 4, color: Kv.ink)),
                ),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: _tag.value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _tag.value)),
                  child: const Text('Pure silver · Priced live, every day',
                      style: TextStyle(fontSize: 13, color: Kv.muted, letterSpacing: 0.3)),
                ),
              ),
            ]),
          ),
        ),
        if (error != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
            child: KvCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, color: Kv.muted),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Kv.ink)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.read(authSessionProvider.notifier).restoreSession(),
                  child: const Text('Try again'),
                ),
                TextButton(
                  // Abandon the unverifiable token rather than be stranded here.
                  onPressed: () => ref.read(authSessionProvider.notifier).clearSession(),
                  child: const Text('Continue as guest'),
                ),
              ]),
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 48 + MediaQuery.paddingOf(context).bottom,
            child: FadeTransition(
              opacity: _tag,
              child: const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
      ]),
    );
  }
}
