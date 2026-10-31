import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/links.dart';

/// Muted light body copy used throughout the web's legal pages.
TextStyle? legalBodyStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w300,
    height: 1.6,
  );
}

/// The web's `<strong className="text-foreground font-medium">`.
TextStyle legalStrongStyle(BuildContext context) =>
    TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500);

/// A numbered policy section (web `Section`): serif primary heading, then
/// paragraphs spaced 12px apart.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}

/// One policy paragraph, optionally bulleted and with a bold lead-in.
class LegalText extends StatelessWidget {
  const LegalText(this.text, {super.key, this.lead, this.bullet = false});

  final String text;
  final String? lead;
  final bool bullet;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        if (bullet) const TextSpan(text: '• '),
        if (lead != null) TextSpan(text: '$lead ', style: legalStrongStyle(context)),
        TextSpan(text: text),
      ]),
      style: legalBodyStyle(context),
    );
  }
}

/// Tinted, bordered intro box (web `bg-primary/5 border border-primary/15`).
class LegalIntro extends StatelessWidget {
  const LegalIntro({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 48),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.05),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// Soft grey contact box (web `bg-secondary/50 rounded-lg`).
class LegalContactBox extends StatelessWidget {
  const LegalContactBox({super.key, required this.children, this.padding = 16});

  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// A line like "Email: kvszchennai@gmail.com" where each value is a web
/// mailto:/tel: link, tappable as on the web.
class LegalLinkLine extends StatelessWidget {
  const LegalLinkLine({super.key, this.label = '', required this.links, this.separator = ' · '});

  final String label;
  final List<String> links;
  final String separator;

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(color: Theme.of(context).colorScheme.primary);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: label),
        for (final (i, l) in links.indexed) ...[
          if (i > 0) TextSpan(text: separator),
          TextSpan(
              text: l,
              style: link,
              recognizer: TapGestureRecognizer()..onTap = () => openLink(hrefFor(l))),
        ],
      ]),
      style: legalBodyStyle(context),
    );
  }
}
