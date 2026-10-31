import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../orders/data/models/order.dart';
import '../savings/application/installment_payer.dart' show showToast;
import 'returns.dart';

Future<void> showRequestReturnDialog(BuildContext context, Order order) =>
    showDialog(context: context, builder: (_) => _RequestReturnDialog(order: order));

/// The web Profile's "Request Return" dialog, then its submitted view.
class _RequestReturnDialog extends ConsumerStatefulWidget {
  const _RequestReturnDialog({required this.order});
  final Order order;

  @override
  ConsumerState<_RequestReturnDialog> createState() => _RequestReturnDialogState();
}

class _RequestReturnDialogState extends ConsumerState<_RequestReturnDialog> {
  final _selected = <int>{};
  final _reason = TextEditingController();
  final _description = TextEditingController();
  bool _kvFault = true;
  bool _submitting = false;
  bool _submitted = false;
  VideoInstructions? _video;

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return showToast(context, 'Select at least one item', '', error: true);
    if (_reason.text.trim().isEmpty) return showToast(context, 'Reason is required', '', error: true);
    setState(() => _submitting = true);
    try {
      final items = widget.order.items;
      final video = await ref.read(returnsRepositoryProvider).create(
            orderId: widget.order.id,
            kvFault: _kvFault,
            reason: _reason.text.trim(),
            description: _description.text.trim(),
            items: [
              for (final i in (_selected.toList()..sort()))
                ReturnItemInput(
                    product: items[i].productId,
                    name: items[i].productName,
                    quantity: items[i].quantity,
                    price: items[i].unitPrice),
            ],
          );
      ref.invalidate(myReturnsProvider);
      setState(() {
        _submitted = true;
        _video = video;
      });
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not submit return', e is ApiException ? e.message : 'Please try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final small = TextStyle(fontSize: 14, color: muted);

    if (_submitted) {
      final v = _video;
      return AlertDialog(
        title: const Text('Return Request Submitted'),
        content: SingleChildScrollView(
          child: v == null
              ? Text(
                  "Since this isn't a KV-fault claim, it's eligible for exchange or store credit only (not a cash "
                  "refund) — our team will reach out to arrange the exchange.",
                  style: small)
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.05),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.chat_bubble_outline, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('Send us your unboxing video',
                          style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                        'To process your KV-fault claim, WhatsApp your unboxing video (unedited, from before opening '
                        'the sealed parcel through the full reveal) to:',
                        style: small),
                    const SizedBox(height: 8),
                    SelectableText(v.whatsappNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text("Include this code as the video's caption so we can match it to your claim:", style: small),
                    const SizedBox(height: 8),
                    Row(children: [
                      SelectableText(v.referenceCode,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace', letterSpacing: 2)),
                      IconButton(
                        tooltip: 'Copy code',
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () => Clipboard.setData(ClipboardData(text: v.referenceCode)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                        'Please send it within ${v.windowHours} hours of delivery — claims without a matching video '
                        'cannot be processed.',
                        style: TextStyle(fontSize: 12, color: muted)),
                  ]),
                ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      );
    }

    final window = ref.watch(claimWindowHoursProvider).valueOrNull;
    final shortId = widget.order.shortId;
    Widget option(bool kv, String title, String body) => InkWell(
          onTap: () => setState(() => _kvFault = kv),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Radio<bool>(
                value: kv,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(body, style: TextStyle(fontSize: 12, color: muted)),
                ]),
              ),
            ]),
          ),
        );

    return AlertDialog(
      title: Text('Request Return — Order #$shortId'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Which items?', style: TextStyle(fontWeight: FontWeight.w500)),
          for (final (i, item) in widget.order.items.indexed)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(i),
              onChanged: (on) => setState(() => on == true ? _selected.add(i) : _selected.remove(i)),
              title: Text('${item.productName} (Qty ${item.quantity})', style: const TextStyle(fontSize: 14)),
            ),
          const SizedBox(height: 16),
          const Text('Reason for return', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          RadioGroup<bool>(
            groupValue: _kvFault,
            onChanged: (v) => setState(() => _kvFault = v ?? true),
            child: Column(children: [
              option(true, "Wrong, damaged, or defective item (KV's fault)",
                  'Eligible for refund or replacement — requires an unboxing video sent via WhatsApp.'),
              option(false, 'Changed my mind / other reason',
                  'Eligible for exchange or store credit only — no video required.'),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _reason,
              decoration: const InputDecoration(
                  labelText: 'Short reason', hintText: 'e.g. Received a damaged bangle')),
          const SizedBox(height: 16),
          TextField(
              controller: _description,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Additional details (optional)', alignLabelWithHint: true)),
          if (window != null) ...[
            const SizedBox(height: 12),
            Text('Returns must be filed within $window hours of delivery.',
                style: TextStyle(fontSize: 12, color: muted)),
          ],
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Submitting...' : 'Submit Return Request'),
        ),
      ],
    );
  }
}
