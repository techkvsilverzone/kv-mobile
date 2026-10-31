import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../core/ui/kv_ui.dart';
import '../../core/widgets/links.dart';
import '../cart/presentation/widgets/item_thumb.dart';
import '../orders/data/models/order.dart';
import 'returns.dart';

/// Opens the full-screen return request for a delivered [order].
Future<void> openRequestReturn(BuildContext context, Order order) => Navigator.of(context)
    .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => RequestReturnScreen(order: order)));

/// The web Profile's "Request Return" dialog as a native flow: pick items,
/// choose the claim type, describe it, submit; then the WhatsApp video steps.
class RequestReturnScreen extends ConsumerStatefulWidget {
  const RequestReturnScreen({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<RequestReturnScreen> createState() => _RequestReturnScreenState();
}

class _RequestReturnScreenState extends ConsumerState<RequestReturnScreen> {
  final _selected = <int>{};
  final _reason = TextEditingController();
  final _description = TextEditingController();
  bool _kvFault = true;
  bool _submitting = false;
  bool _submitted = false;
  bool _showErrors = false;
  VideoInstructions? _video;

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (_selected.isEmpty || _reason.text.trim().isEmpty) return;
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
        showKvToast(context, 'Could not submit return',
            message: e is ApiException ? e.message : 'Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SubmittedView(video: _video);

    final window = ref.watch(claimWindowHoursProvider).valueOrNull;
    final itemsError = _showErrors && _selected.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Return · Order #${widget.order.shortId}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, Kv.gap),
        children: [
          SectionHeader(
            title: 'Which items?',
            subtitle: itemsError ? null : 'Select everything you want to return',
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          if (itemsError)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('Select at least one item', style: TextStyle(color: Kv.danger, fontSize: 13)),
            ),
          for (final (i, item) in widget.order.items.indexed) ...[
            _Choice(
              selected: _selected.contains(i),
              checkbox: true,
              semanticsLabel: item.productName,
              onTap: () => setState(() => _selected.contains(i) ? _selected.remove(i) : _selected.add(i)),
              child: Row(children: [
                ItemThumb(image: item.image, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Qty ${item.quantity}', style: const TextStyle(fontSize: 12, color: Kv.muted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const SectionHeader(title: 'What happened?', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
          _Choice(
            selected: _kvFault,
            onTap: () => setState(() => _kvFault = true),
            child: const _ReasonType(
              icon: Icons.report_gmailerrorred_rounded,
              title: 'Damaged, wrong or defective',
              body: 'Refund or replacement. Needs your unboxing video on WhatsApp.',
            ),
          ),
          const SizedBox(height: 10),
          _Choice(
            selected: !_kvFault,
            onTap: () => setState(() => _kvFault = false),
            child: const _ReasonType(
              icon: Icons.swap_horiz_rounded,
              title: 'Changed my mind / other',
              body: 'Exchange or store credit only. No video needed.',
            ),
          ),
          const SizedBox(height: Kv.gap),
          const SectionHeader(title: 'Tell us more', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
          TextField(
            controller: _reason,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _showErrors ? setState(() {}) : null,
            decoration: InputDecoration(
              labelText: 'Short reason',
              hintText: 'e.g. Received a damaged bangle',
              errorText: _showErrors && _reason.text.trim().isEmpty ? 'Reason is required' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'More details (optional)', alignLabelWithHint: true),
          ),
          if (window != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 16, color: Kv.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Returns must be filed within $window hours of delivery.',
                    style: const TextStyle(fontSize: 12, color: Kv.muted)),
              ),
            ]),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _submitting
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit request'),
        ),
      ),
    );
  }
}

/// Selectable card: blue border + tint when selected, check or radio on the right.
class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.onTap, required this.child, this.checkbox = false, this.semanticsLabel});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool checkbox;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        selected: selected,
        button: true,
        child: Material(
          color: selected ? Kv.blueSoft : Kv.surface,
          shape: RoundedRectangleBorder(
            borderRadius: Kv.cardRadius,
            side: BorderSide(color: selected ? Kv.blue : Kv.line, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: child),
                const SizedBox(width: 8),
                Icon(
                  checkbox
                      ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                      : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  color: selected ? Kv.blue : Kv.subtle,
                ),
              ]),
            ),
          ),
        ),
      );
}

class _ReasonType extends StatelessWidget {
  const _ReasonType({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Kv.surface, shape: BoxShape.circle),
          child: Icon(icon, color: Kv.ink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 13, color: Kv.muted, height: 1.35)),
          ]),
        ),
      ]);
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.video});
  final VideoInstructions? video;

  @override
  Widget build(BuildContext context) {
    final v = video;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Return requested')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, 24, Kv.pad, Kv.gap), children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: Kv.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 40, color: Kv.success),
          ),
        ),
        const SizedBox(height: 16),
        const Text('We’ve got your request',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          v == null
              ? "Since this isn't a KV-fault claim, it's eligible for exchange or store credit only (not a cash "
                  'refund). Our team will reach out to arrange the exchange.'
              : 'One more step: send us your unboxing video so we can process your claim.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Kv.muted, height: 1.4),
        ),
        if (v != null) ...[
          const SizedBox(height: Kv.gap),
          KvCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Step(
                n: 1,
                text: 'Record or find your unedited unboxing video, from the sealed parcel through the full reveal.',
              ),
              const SizedBox(height: 16),
              _Step(n: 2, text: 'WhatsApp it to', value: v.whatsappNumber),
              const SizedBox(height: 16),
              _Step(n: 3, text: 'Add this code as the caption', value: v.referenceCode, mono: true),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 16, color: Kv.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Send it within ${v.windowHours} hours of delivery — claims without a matching video '
                    'cannot be processed.',
                    style: const TextStyle(fontSize: 12, color: Kv.warning),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openLink('https://wa.me/${v.whatsappNumber.replaceAll(RegExp(r'\D'), '')}'),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Open WhatsApp'),
          ),
        ],
      ]),
      bottomNavigationBar: BottomActionBar(
        action: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.value, this.mono = false});
  final int n;
  final String text;
  final String? value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Kv.blueSoft,
          child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Kv.blue)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
            if (value != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: SelectableText(value!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: mono ? 2 : 0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value!));
                    showKvToast(context, 'Copied');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ]),
            ],
          ]),
        ),
      ]);
}
