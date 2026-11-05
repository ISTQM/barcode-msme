import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:barcode_msme/core/barcode_codec.dart';
import 'package:barcode_msme/core/label_geometry.dart';
import 'package:barcode_msme/core/label_painter.dart';
import 'package:barcode_msme/core/sheet_layout.dart';
import 'package:barcode_msme/data/label_job.dart';
import 'package:barcode_msme/services/label_docx.dart';
import 'package:barcode_msme/services/label_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

LabelJob job({
  int copies = 24,
  PaperSize paper = PaperSize.a4,
  LabelSize size = LabelSize.medium,
  LabelStyle style = LabelStyle.nameAndPrice,
}) {
  return LabelJob(
    content: const LabelContent(
      symbology: BarcodeSymbology.ean13,
      code: '4006381333931',
      name: 'Lucky Me',
      priceText: '₱15.00',
    ),
    style: style,
    size: size,
    paper: paper,
    copies: copies,
    cutGuides: true,
  );
}

/// How many times [pattern] appears in [text].
int count(String text, Pattern pattern) => pattern.allMatches(text).length;

void main() {
  group('PDF', () {
    final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();

    Future<String> build(LabelJob job) async {
      final bytes = await LabelPdf.build(
        job,
        regularFont: regular,
        boldFont: bold,
      );
      // latin1 keeps every byte, so the page dictionaries can be counted.
      return latin1.decode(bytes);
    }

    int pages(String pdf) => count(pdf, RegExp(r'/Type\s*/Page(?![a-z])'));

    test('is a PDF with one page per full sheet', () async {
      final one = await build(job(copies: 24));
      expect(one.startsWith('%PDF'), isTrue);
      expect(pages(one), 1);
      expect(pages(await build(job(copies: 25))), 2);
      expect(pages(await build(job(copies: 48))), 2);
    });

    test('page count follows the paper', () async {
      // A4 holds 24 of these labels and long bond 27, so 80 need 4 and 3.
      final a4 = job(copies: 80, paper: PaperSize.a4);
      final long = job(copies: 80, paper: PaperSize.longBond);
      expect(pages(await build(a4)), a4.layout.pages);
      expect(pages(await build(long)), long.layout.pages);
      expect(a4.layout.pages, 4);
      expect(long.layout.pages, 3);
    });

    test('the page is the size of the chosen paper', () async {
      final pdf = await build(job(paper: PaperSize.shortBond));
      final box = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]')
          .firstMatch(pdf)!;
      // 8.5 x 11 in is 612 x 792 pt.
      expect(double.parse(box.group(1)!), closeTo(612, 1));
      expect(double.parse(box.group(2)!), closeTo(792, 1));
    });

    test('the largest run builds', () async {
      final pdf = await build(job(copies: LabelJob.maxCopies));
      expect(pages(pdf), job(copies: LabelJob.maxCopies).layout.pages);
    });
  });

  group('DOCX', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    Map<String, ArchiveFile> unzip(Uint8List bytes) => {
          for (final file in ZipDecoder().decodeBytes(bytes)) file.name: file,
        };

    test('is a zip holding the parts Word needs', () {
      final parts = unzip(LabelDocx.build(job(), png));
      expect(
        parts.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/_rels/document.xml.rels',
          'word/media/label.png',
        ]),
      );
      expect(parts['word/media/label.png']!.content, png);
    });

    test('lays the labels out as a table on the chosen paper', () {
      final doc = LabelDocx.document(job(copies: 30));
      final layout = job(copies: 30).layout;

      expect(count(doc, '<w:gridCol '), layout.columns);
      expect(count(doc, '<w:tr>'), (30 / layout.columns).ceil());
      expect(count(doc, '<w:drawing>'), 30);
      // A4 in twentieths of a point.
      expect(doc, contains('<w:pgSz w:w="11906" w:h="16838"/>'));
    });

    test('every picture has its own id and the same size', () {
      final doc = LabelDocx.document(job(copies: 10));
      final ids = RegExp(r'<wp:docPr id="(\d+)"')
          .allMatches(doc)
          .map((m) => m.group(1))
          .toList();
      expect(ids.toSet(), hasLength(10));
      // 50 x 30 mm in EMU.
      expect(count(doc, '<wp:extent cx="1800000" cy="1080000"/>'), 10);
    });

    test('a partly filled last row is padded with empty cells', () {
      final layout = job(copies: 4).layout;
      final doc = LabelDocx.document(job(copies: 4));
      final rows = (4 / layout.columns).ceil();
      expect(count(doc, '<w:tc>'), rows * layout.columns);
      expect(count(doc, '<w:drawing>'), 4);
    });

    test('tags are balanced', () {
      final doc = LabelDocx.document(job(copies: 30));
      for (final tag in ['w:tbl', 'w:tr', 'w:tc', 'w:p', 'w:body']) {
        expect(count(doc, '<$tag>') + count(doc, '<$tag '),
            count(doc, '</$tag>'),
            reason: tag);
      }
    });
  });

  group('image', () {
    testWidgets('a label renders to a PNG of the requested size',
        (tester) async {
      final geometry = LabelGeometry.build(
        job().content,
        LabelStyle.barcodeOnly,
        widthMm: 60,
        heightMm: 34,
      );
      final bytes = await tester.runAsync(
        () => LabelPainter.renderPng(geometry, widthPx: 600),
      );

      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final header = ByteData.sublistView(bytes);
      // IHDR width and height sit at bytes 16 and 20.
      expect(header.getUint32(16), 600);
      expect(header.getUint32(20), (600 * 34 / 60).round());
    });
  });
}
