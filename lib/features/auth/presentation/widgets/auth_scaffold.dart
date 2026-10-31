import 'package:flutter/material.dart';

/// Shared chrome for the unauthenticated screens (login, signup, forgot
/// password): centered, width-capped so the forms stay readable on tablets,
/// and scrollable so the keyboard never overflows the layout.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The web's round "KV" mark.
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text('KV',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
