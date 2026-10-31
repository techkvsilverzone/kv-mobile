import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../format/currency.dart';
import '../theme/tokens.dart';

/// White card with a hairline border; tappable when [onTap] is set.
class KvCard extends StatelessWidget {
  const KvCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Kv.surface,
      shape: RoundedRectangleBorder(borderRadius: Kv.cardRadius, side: const BorderSide(color: Kv.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.action, this.onAction, this.padding});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Kv.pad, 0, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: text.bodySmall),
            ],
          ]),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// A rupee price, with an optional struck-through original price.
class PriceText extends StatelessWidget {
  const PriceText(this.price, {super.key, this.original, this.size = 16, this.color});

  final double price;
  final double? original;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final showOriginal = original != null && original! > price;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
      Text(formatInr(price),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color ?? Kv.ink, letterSpacing: -0.2)),
      if (showOriginal)
        Text(formatInr(original!),
            style: TextStyle(fontSize: size * 0.78, color: Kv.subtle, decoration: TextDecoration.lineThrough)),
    ]);
  }
}

enum PillTone { neutral, info, success, warning, danger, gold }

/// Small rounded status label.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  static (Color, Color) colors(PillTone t) => switch (t) {
        PillTone.neutral => (const Color(0xFFEFF1F4), Kv.muted),
        PillTone.info => (Kv.blueSoft, Kv.blueDark),
        PillTone.success => (Kv.successSoft, Kv.success),
        PillTone.warning => (Kv.warningSoft, Kv.warning),
        PillTone.danger => (Kv.dangerSoft, Kv.danger),
        PillTone.gold => (Kv.goldSoft, const Color(0xFF8A6A2A)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ),
      ]),
    );
  }
}

/// Designed empty / error state: icon in a soft circle, title, message, action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: Kv.blueSoft, shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: Kv.blue),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontSize: 17)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: Kv.muted)),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            child: Text(actionLabel!),
          ),
        ],
      ]),
    );
  }
}

/// Sticky bar at the bottom of a screen holding its primary action.
/// Put it in `Scaffold.bottomNavigationBar`.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, this.leading, required this.action});

  /// Usually a label + total, e.g. ("Total", ₹1,240).
  final Widget? leading;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Kv.surface, boxShadow: Kv.floatingShadow),
      padding: EdgeInsets.fromLTRB(Kv.pad, 12, Kv.pad, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(children: [
        if (leading != null) ...[Expanded(child: leading!), const SizedBox(width: 16)],
        if (leading == null) Expanded(child: action) else action,
      ]),
    );
  }
}

/// "Total / ₹1,240" block for a [BottomActionBar].
class BarTotal extends StatelessWidget {
  const BarTotal({super.key, required this.label, required this.amount, this.note});
  final String label;
  final double amount;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Kv.muted, fontWeight: FontWeight.w500)),
          Text(formatInr(amount),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Kv.ink, letterSpacing: -0.3)),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 11, color: Kv.subtle)),
        ],
      );
}

/// − n + stepper.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max, this.compact = false});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 44.0;
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
          width: size,
          height: size,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: compact ? 16 : 18,
            onPressed: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onTap();
                  }
                : null,
            icon: Icon(icon),
          ),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Kv.line), borderRadius: Kv.smallRadius, color: Kv.surface),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, value > min, () => onChanged(value - 1)),
        SizedBox(
          width: compact ? 24 : 32,
          child: Text('$value',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
        btn(Icons.add, max == null || value < max!, () => onChanged(value + 1)),
      ]),
    );
  }
}

/// Settings-style group: optional caption, then rows in one card.
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Kv.muted)),
          ),
        KvCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(indent: 56),
            ],
          ]),
        ),
      ]);
}

/// One row of a [MenuGroup].
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: danger ? Kv.danger : Kv.ink, size: 22),
        title: Text(title, style: TextStyle(color: danger ? Kv.danger : Kv.ink)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? (danger ? null : const Icon(Icons.chevron_right, color: Kv.subtle)),
      );
}

/// Bottom sheet with the app's styling. Scrolls; respects the keyboard.
Future<T?> showKvSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          ),
          Flexible(child: builder(ctx)),
        ]),
      ),
    ),
  );
}

/// Floating toast. A newer toast replaces the current one.
void showKvToast(BuildContext context, String title, {String? message, bool error = false, String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? const Color(0xFF7F1D1D) : Kv.ink,
      duration: const Duration(seconds: 3),
      // A toast with an action would otherwise stay until dismissed and follow the user
      // across tabs.
      persist: false,
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle, color: error ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            if (message != null && message.isNotEmpty)
              Text(message, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13)),
          ]),
        ),
      ]),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
