import 'package:flutter/material.dart';

/// The web's centred page header: uppercase eyebrow, serif title in primary,
/// muted subtitle and a short rule (SilverRate, About, FAQ, Contact, ...).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, this.eyebrow, required this.title, this.subtitle});

  final String? eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Column(
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 2.4)),
            const SizedBox(height: 12),
          ],
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w400)),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ],
          const SizedBox(height: 20),
          Container(width: 96, height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

/// Card with a leading info icon, serif heading and muted body (web "Info Section").
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.body, this.icon = Icons.info_outline});

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(body,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
