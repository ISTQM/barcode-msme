import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/label_geometry.dart';
import '../core/label_painter.dart';
import '../data/label_job.dart';
import 'label_docx.dart';
import 'label_pdf.dart';

/// Builds label files on the device and hands them to the native share sheet
/// (print, Viber, email, Files). Nothing here touches the network.
class LabelExportService {
  static const String _regularFont = 'assets/fonts/Roboto-Regular.ttf';
  static const String _boldFont = 'assets/fonts/Roboto-Bold.ttf';

  /// Pixels per millimetre for pictures placed in a document (about 300 dpi).
  static const double _docPxPerMm = 12;

  /// Width of the exported barcode image, large enough to resize or redraw.
  static const int _imageWidthPx = 1200;

  /// Shape of the exported barcode image. Roomy enough for the quiet zone.
  static const double _imageWidthMm = 60;
  static const double _imageHeightMm = 34;

  static final DateFormat _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<File> createPdf(LabelJob job) async {
    final regular = (await rootBundle.load(_regularFont)).buffer.asUint8List();
    final bold = (await rootBundle.load(_boldFont)).buffer.asUint8List();
    final bytes = await Isolate.run(
      () => LabelPdf.build(job, regularFont: regular, boldFont: bold),
    );
    return _write(job.content.code, SheetFormat.pdf.extension, bytes);
  }

  Future<File> createDocx(LabelJob job) async {
    final png = await LabelPainter.renderPng(
      job.geometry,
      widthPx: (job.size.widthMm * _docPxPerMm).round(),
      cutGuides: job.cutGuides,
    );
    return _write(
      job.content.code,
      SheetFormat.docx.extension,
      LabelDocx.build(job, png),
    );
  }

  /// The barcode alone, bars and number on white, for use in other layouts.
  Future<File> createImage(LabelContent content) async {
    final geometry = LabelGeometry.build(
      content,
      LabelStyle.barcodeOnly,
      widthMm: _imageWidthMm,
      heightMm: _imageHeightMm,
    );
    final png = await LabelPainter.renderPng(geometry, widthPx: _imageWidthPx);
    return _write(content.code, 'png', png, prefix: 'Barcode');
  }

  Future<File> _write(
    String code,
    String extension,
    Uint8List bytes, {
    String prefix = 'Labels',
  }) async {
    final directory = await getTemporaryDirectory();
    final safeCode = code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final name =
        '${prefix}_${safeCode}_${_fileStamp.format(DateTime.now())}.$extension';
    return File('${directory.path}${Platform.pathSeparator}$name')
        .writeAsBytes(bytes, flush: true);
  }

  Future<ShareResult> share(File file, {required String mime, Rect? origin}) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        fileNameOverrides: [file.uri.pathSegments.last],
        sharePositionOrigin: origin,
      ),
    );
  }
}
