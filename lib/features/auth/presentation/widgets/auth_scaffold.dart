import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/kv_ui.dart';

/// Shared chrome for the sign-in screens: white page, close/back control, brand mark,
/// a left-aligned serif title, then the form. Scrolls under the keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Back arrow (a step inside the flow) instead of the close ✕ (leave sign-in).
  final bool showBack;

  /// Pinned below the form (e.g. "New here? Create an account").
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canPop = context.canPop();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: showBack || canPop
            ? IconButton(
                tooltip: showBack ? 'Back' : 'Close',
                icon: Icon(showBack ? Icons.arrow_back_rounded : Icons.close_rounded),
                onPressed: () => canPop ? context.pop() : context.go('/home'),
              )
            : null,
        actions: [
          if (!showBack && !canPop)
            TextButton(onPressed: () => context.go('/home'), child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset('assets/brand/logo_mark.png', height: 48, semanticLabel: 'KV Silver Zone'),
                    ),
                    const SizedBox(height: 24),
                    Text(title, style: text.headlineMedium?.copyWith(fontSize: 30, height: 1.15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!, style: text.bodyLarge?.copyWith(color: Kv.muted)),
                    ],
                    const SizedBox(height: 28),
                    child,
                  ]),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 12), child: footer),
        ]),
      ),
    );
  }
}

/// Two-option pill switch used on the sign-in screen.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: Kv.smallRadius),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                          color: i == index ? Kv.ink : Kv.muted,
                          fontSize: 14)),
                ),
              ),
            ),
        ]),
      );
}
