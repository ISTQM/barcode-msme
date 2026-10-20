import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/receipt.dart';
import 'receipt_pdf.dart';

/// Builds the receipt PDF on the device and hands it to the native share sheet.
/// Nothing here touches the network.
class ReceiptService {
  static const String _regularFont = 'assets/fonts/Roboto-Regular.ttf';
  static const String _boldFont = 'assets/fonts/Roboto-Bold.ttf';

  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<File> createPdf(Receipt receipt) async {
    final regular = (await rootBundle.load(_regularFont)).buffer.asUint8List();
    final bold = (await rootBundle.load(_boldFont)).buffer.asUint8List();

    final Uint8List bytes = await Isolate.run(
      () => ReceiptPdf.build(receipt, regularFont: regular, boldFont: bold),
    );

    final directory = await getTemporaryDirectory();
    final name =
        '${receipt.type.filePrefix}_${_fileStamp.format(receipt.issuedAt)}.pdf';
    return File('${directory.path}${Platform.pathSeparator}$name')
        .writeAsBytes(bytes, flush: true);
  }

  /// Opens the share sheet, so the PDF can go to Viber, email or a Bluetooth
  /// thermal printer app.
  Future<ShareResult> share(File file, {Rect? origin}) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [file.uri.pathSegments.last],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Build and share in one step, which is what the Print/Share button runs.
  Future<ShareResult> printAndShare(Receipt receipt, {Rect? origin}) async {
    final file = await createPdf(receipt);
    return share(file, origin: origin);
  }
}
