import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/label_geometry.dart';
import '../core/sheet_layout.dart';
import '../data/label_job.dart';

/// Lays labels out on sheets of paper. Pure Dart, so it runs offline and can
/// be called from a background isolate. Bars are drawn as vector rectangles,
/// which print sharper than an embedded picture.
class LabelPdf {
  LabelPdf._();

  static Future<Uint8List> build(
    LabelJob job, {
    required Uint8List regularFont,
    required Uint8List boldFont,
  }) {
    final regular = pw.Font.ttf(ByteData.sublistView(regularFont));
    final bold = pw.Font.ttf(ByteData.sublistView(boldFont));
    final geometry = job.geometry;
    final layout = job.layout;

    // A widget keeps the position it was laid out at, so every label on the
    // sheet needs its own instance.
    pw.Widget label() => pw.SizedBox(
          width: job.size.widthMm * PdfPageFormat.mm,
          height: job.size.heightMm * PdfPageFormat.mm,
          child: pw.Builder(
            builder: (context) {
              final regularFont = regular.getFont(context);
              final boldFont = bold.getFont(context);
              return pw.CustomPaint(
                painter: (canvas, size) => _paint(
                  canvas,
                  size,
                  geometry,
                  regular: regularFont,
                  bold: boldFont,
                  cutGuides: job.cutGuides,
                ),
              );
            },
          ),
        );

    final gap = SheetLayout.gapMm * PdfPageFormat.mm;
    final document = pw.Document(
      title: 'Barcode labels',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    var remaining = job.copies;
    while (remaining > 0) {
      final onPage = remaining < layout.perPage ? remaining : layout.perPage;
      remaining -= onPage;

      final rows = <pw.Widget>[];
      for (var start = 0; start < onPage; start += layout.columns) {
        final inRow = onPage - start < layout.columns
            ? onPage - start
            : layout.columns;
        rows.add(
          pw.Row(
            children: [
              for (var i = 0; i < inRow; i++) ...[
                label(),
                if (i < inRow - 1) pw.SizedBox(width: gap),
              ],
            ],
          ),
        );
        if (start + layout.columns < onPage) {
          rows.add(pw.SizedBox(height: gap));
        }
      }

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            job.paper.widthMm * PdfPageFormat.mm,
            job.paper.heightMm * PdfPageFormat.mm,
            marginAll: SheetLayout.marginMm * PdfPageFormat.mm,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rows,
          ),
        ),
      );
    }

    return document.save();
  }

  /// Draws one label. The PDF origin is the bottom left, the geometry's is
  /// the top left, so every y is flipped.
  static void _paint(
    PdfGraphics canvas,
    PdfPoint size,
    LabelGeometry geometry, {
    required PdfFont regular,
    required PdfFont bold,
    required bool cutGuides,
  }) {
    final scale = size.x / geometry.widthMm;

    for (final bar in geometry.bars) {
      canvas.drawRect(
        bar.x * scale,
        size.y - (bar.y + bar.h) * scale,
        bar.w * scale,
        bar.h * scale,
      );
    }
    canvas
      ..setFillColor(PdfColors.black)
      ..fillPath();

    for (final text in geometry.texts) {
      final font = text.bold ? bold : regular;
      var fontSize = text.h * scale;
      final metrics = font.stringMetrics(text.text);
      final boxWidth = text.w * scale;
      if (metrics.width * fontSize > boxWidth) {
        fontSize = boxWidth / metrics.width;
      }
      final width = metrics.width * fontSize;
      final left = text.x * scale +
          switch (text.align) {
            LabelAlign.left => 0.0,
            LabelAlign.center => (boxWidth - width) / 2,
            LabelAlign.right => boxWidth - width,
          };
      final baseline = size.y -
          (text.y + text.h) * scale -
          metrics.descent * fontSize +
          (text.h * scale - fontSize) / 2;
      canvas
        ..setFillColor(PdfColors.black)
        ..drawString(font, fontSize, text.text, left, baseline);
    }

    if (cutGuides) {
      canvas
        ..setStrokeColor(PdfColors.grey500)
        ..setLineWidth(0.4)
        ..drawRect(0.2, 0.2, size.x - 0.4, size.y - 0.4)
        ..strokePath();
    }
  }
}
