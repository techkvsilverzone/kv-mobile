import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../../../core/widgets/links.dart';

/// Body copy for the legal pages: 15/1.65, ink.
TextStyle? legalBodyStyle(BuildContext context) => const TextStyle(fontSize: 15, height: 1.65, color: Kv.ink);

/// Bold lead-in inside legal copy.
TextStyle legalStrongStyle(BuildContext context) => const TextStyle(color: Kv.ink, fontWeight: FontWeight.w600);

/// Scaffold for a legal page: white, readable column, "Last updated" line on top.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.meta, required this.children});

  final String title;
  final String meta;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Kv.surface,
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
          Row(children: [
            const Icon(Icons.update_rounded, size: 16, color: Kv.subtle),
            const SizedBox(width: 6),
            Expanded(child: Text(meta, style: const TextStyle(fontSize: 13, color: Kv.muted))),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      );
}

/// A numbered policy section: heading, then paragraphs spaced 10px apart.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Kv.ink, height: 1.3)),
          const SizedBox(height: 10),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            child,
          ],
        ]),
      );
}

/// One policy paragraph, optionally bulleted (hanging indent) and with a bold lead-in.
class LegalText extends StatelessWidget {
  const LegalText(this.text, {super.key, this.lead, this.bullet = false});

  final String text;
  final String? lead;
  final bool bullet;

  @override
  Widget build(BuildContext context) {
    final body = Text.rich(
      TextSpan(children: [
        if (lead != null) TextSpan(text: '$lead ', style: legalStrongStyle(context)),
        TextSpan(text: text),
      ]),
      style: legalBodyStyle(context),
    );
    if (!bullet) return body;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 9, right: 12, left: 2),
        child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Kv.subtle, shape: BoxShape.circle)),
      ),
      Expanded(child: body),
    ]);
  }
}

/// Soft tinted intro box.
class LegalIntro extends StatelessWidget {
  const LegalIntro({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 28),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Kv.blueSoft, borderRadius: Kv.cardRadius),
        child: child,
      );
}

/// Contact box at the end of a legal page.
class LegalContactBox extends StatelessWidget {
  const LegalContactBox({super.key, required this.children, this.padding = 16});

  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(color: Kv.bg, borderRadius: Kv.cardRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// A line like "Email: kvszchennai@gmail.com" where each value is a tappable
/// mailto:/tel: link, as on the web.
class LegalLinkLine extends StatelessWidget {
  const LegalLinkLine({super.key, this.label = '', required this.links, this.separator = ' · '});

  final String label;
  final List<String> links;
  final String separator;

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: Kv.blue, fontWeight: FontWeight.w500);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: label),
        for (final (i, l) in links.indexed) ...[
          if (i > 0) TextSpan(text: separator),
          TextSpan(text: l, style: link, recognizer: TapGestureRecognizer()..onTap = () => openLink(hrefFor(l))),
        ],
      ]),
      style: legalBodyStyle(context),
    );
  }
}
