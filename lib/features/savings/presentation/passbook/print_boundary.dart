import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Rasterises the RepaintBoundary under [boundary] and opens the system print sheet,
/// slicing the image over as many A4 pages as it needs (the web's react-to-print).
Future<void> printBoundary(BuildContext context, GlobalKey boundary, String name) async {
  try {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // ~1600px wide whatever the on-screen width, so narrow receipts print sharp too.
    final image = await render.toImage(pixelRatio: 1600 / render.size.width);
    const format = PdfPageFormat.a4;
    const margin = 24.0;
    final pageW = format.width - 2 * margin, pageH = format.height - 2 * margin;
    final sliceH = (image.width * pageH / pageW).floor();
    final doc = pw.Document();
    for (var top = 0; top < image.height; top += sliceH) {
      final h = math.min(sliceH, image.height - top);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(0, top.toDouble(), image.width.toDouble(), h.toDouble()),
        Rect.fromLTWH(0, 0, image.width.toDouble(), h.toDouble()),
        Paint(),
      );
      final slice = await recorder.endRecording().toImage(image.width, h);
      final png = (await slice.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) =>
            pw.Align(alignment: pw.Alignment.topCenter, child: pw.Image(pw.MemoryImage(png), width: pageW)),
      ));
    }
    await Printing.layoutPdf(name: name, onLayout: (_) => doc.save());
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not print. Please try again.')));
    }
  }
}
