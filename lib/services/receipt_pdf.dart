import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/money.dart';
import '../data/receipt.dart';

/// Lays out a thermal-roll receipt. Pure Dart, so it runs offline and can be
/// called from a background isolate.
class ReceiptPdf {
  ReceiptPdf._();

  /// Printed verbatim at the very bottom of every document. Do not reword.
  static const String disclaimer =
      'This document is not valid for claim of input tax. '
      'For internal tracking purposes only.';

  static final DateFormat _date = DateFormat('MMM d, y');
  static final DateFormat _time = DateFormat('h:mm a');

  static Future<Uint8List> build(
    Receipt receipt, {
    required Uint8List regularFont,
    required Uint8List boldFont,
  }) {
    final regular = pw.Font.ttf(ByteData.sublistView(regularFont));
    final bold = pw.Font.ttf(ByteData.sublistView(boldFont));
    final sizes = _Sizes(wide: receipt.paper == PaperWidth.mm80);

    pw.TextStyle style(double size, {bool strong = false}) =>
        pw.TextStyle(font: strong ? bold : regular, fontSize: size);

    pw.Widget rule() => pw.Divider(
          height: 10,
          thickness: 0.7,
          borderStyle: pw.BorderStyle.dashed,
        );

    pw.Widget split(String left, String right, pw.TextStyle textStyle) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(left, style: textStyle),
          pw.Text(right, style: textStyle),
        ],
      );
    }

    final document = pw.Document(
      title: receipt.type.title,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    document.addPage(
      pw.Page(
        // Infinite height makes the page exactly as long as the content.
        pageFormat: PdfPageFormat(
          receipt.paper.mm * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                receipt.type.title,
                textAlign: pw.TextAlign.center,
                style: style(sizes.title, strong: true),
              ),
              rule(),
              split('Date', _date.format(receipt.issuedAt), style(sizes.body)),
              pw.SizedBox(height: 2),
              split('Time', _time.format(receipt.issuedAt), style(sizes.body)),
              rule(),
              split(
                'Qty x Unit Price',
                'Amount (PHP)',
                style(sizes.small, strong: true),
              ),
              pw.SizedBox(height: 6),
              for (final line in receipt.lines) ...[
                pw.Text(line.name, style: style(sizes.body, strong: true)),
                pw.SizedBox(height: 1),
                split(
                  '${line.quantity} x ${Money.format(line.unitPriceCentavos)}',
                  Money.format(line.amountCentavos),
                  style(sizes.body),
                ),
                pw.SizedBox(height: 6),
              ],
              rule(),
              split(
                'TOTAL',
                'PHP ${Money.format(receipt.totalCentavos)}',
                style(sizes.total, strong: true),
              ),
              pw.SizedBox(height: sizes.signatureGap),
              pw.Text('Received By:', style: style(sizes.body)),
              pw.SizedBox(height: sizes.signatureGap),
              pw.Divider(height: 1, thickness: 0.8),
              pw.SizedBox(height: 14),
              pw.Text(
                disclaimer,
                textAlign: pw.TextAlign.center,
                style: style(sizes.disclaimer),
              ),
            ],
          );
        },
      ),
    );

    return document.save();
  }
}

class _Sizes {
  _Sizes({required bool wide})
      : title = wide ? 17 : 13,
        body = wide ? 10 : 8.5,
        small = wide ? 8 : 7,
        total = wide ? 13 : 11,
        disclaimer = wide ? 7.5 : 6.5,
        signatureGap = wide ? 22 : 18;

  final double title;
  final double body;
  final double small;
  final double total;
  final double disclaimer;
  final double signatureGap;
}
