import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_session.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not create the invoice. Please try again.')));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(e is ApiException ? e.message : 'Could not load this order.',
                textAlign: TextAlign.center),
          ),
        ),
        data: (o) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RepaintBoundary(
              key: _boundary,
              child: InvoiceView(
                  order: o, config: config, customerName: user?.name, customerEmail: user?.email),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _download('KV-Silver-Zone-Invoice'),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Invoice'),
            ),
          ],
        ),
      ),
    );
  }
}
