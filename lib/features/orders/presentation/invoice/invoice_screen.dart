import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../data/order_repository.dart';
import 'invoice_view.dart';

/// The order's tax invoice with a Download button, which opens the system
/// print / save-as-PDF sheet — the app's counterpart of the web's
/// "Download Invoice" (react-to-print).
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  /// Rasterises the on-screen invoice into a single A4 page, so the PDF is
  /// exactly what the customer sees.
  Future<void> _download(String fileName) async {
    setState(() => _busy = true);
    try {
      final render = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final doc = pw.Document()
        ..addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain)),
        ));
      await Printing.layoutPdf(name: fileName, onLayout: (_) => doc.save());
    } catch (_) {
      if (mounted) {
        showKvToast(context, 'Could not create the invoice', message: 'Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    final config = ref.watch(invoiceConfigProvider).valueOrNull ?? const InvoiceConfig();
    final user = ref.watch(currentUserProvider);
    final o = order.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(o?.invoiceNumber ?? 'Invoice')),
      body: order.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Kv.pad),
          child: KvShimmer(child: KvSkeleton(height: 520, radius: Kv.radius)),
        ),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Could not load the invoice',
            message: e is ApiException ? e.message : 'Please try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(orderProvider(widget.orderId)),
          ),
        ),
        data: (o) => ListView(
          padding: const EdgeInsets.all(Kv.pad),
          children: [
            // The printable invoice stays black-on-white paper.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: Kv.smallRadius,
                border: Border.all(color: Kv.line),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: Kv.smallRadius,
                child: RepaintBoundary(
                  key: _boundary,
                  child: InvoiceView(
                      order: o, config: config, customerName: user?.name, customerEmail: user?.email),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Download saves a PDF or opens your printer.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Kv.subtle)),
          ],
        ),
      ),
      bottomNavigationBar: o == null
          ? null
          : BottomActionBar(
              action: FilledButton.icon(
                onPressed: _busy ? null : () => _download('KV-Silver-Zone-Invoice'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download invoice'),
              ),
            ),
    );
  }
}
