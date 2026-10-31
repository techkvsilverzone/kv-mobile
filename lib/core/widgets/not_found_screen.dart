import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// kv-ui pages/NotFound.tsx — the router's error page.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('404',
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 16),
            Text('Oops! Page not found',
                style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text('Return to Home',
                  style: TextStyle(
                      color: scheme.primary, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}
