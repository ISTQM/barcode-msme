import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/sheet_layout.dart';
import '../data/label_job.dart';

/// Writes a Word document that tiles one label picture across a table.
///
/// A .docx is a zip of XML parts, so this needs no Word library and works
/// offline. The same PNG is referenced by every cell, which keeps the file
/// small however many copies are printed.
class LabelDocx {
  LabelDocx._();

  static const String _wordNs =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const String _packageRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  static const String _documentRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/label.png"/>'
      '</Relationships>';

  /// [labelPng] is one rendered label, already carrying its cut guides if the
  /// job asks for them.
  static Uint8List build(LabelJob job, Uint8List labelPng) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _packageRels))
      ..addFile(ArchiveFile.string('word/document.xml', document(job)))
      ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', _documentRels))
      ..addFile(ArchiveFile('word/media/label.png', labelPng.length, labelPng));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// The body of word/document.xml. Exposed so tests can inspect the table.
  static String document(LabelJob job) {
    final layout = job.layout;
    final cell = _twips(job.size.widthMm + SheetLayout.gapMm);
    final row = _twips(job.size.heightMm + SheetLayout.gapMm);
    final imageWidth = _emu(job.size.widthMm);
    final imageHeight = _emu(job.size.heightMm);
    final margin = _twips(SheetLayout.marginMm);

    final rowCount = (job.copies / layout.columns).ceil();
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document xmlns:w="$_wordNs" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
      )
      ..write('<w:body><w:tbl><w:tblPr>')
      ..write('<w:tblW w:w="${cell * layout.columns}" w:type="dxa"/>')
      ..write('<w:tblLayout w:type="fixed"/>')
      ..write(
        '<w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/>'
        '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar>',
      )
      ..write('</w:tblPr><w:tblGrid>');
    for (var i = 0; i < layout.columns; i++) {
      buffer.write('<w:gridCol w:w="$cell"/>');
    }
    buffer.write('</w:tblGrid>');

    var drawingId = 1;
    var placed = 0;
    for (var r = 0; r < rowCount; r++) {
      buffer.write(
        '<w:tr><w:trPr><w:cantSplit/><w:trHeight w:val="$row" w:hRule="exact"/></w:trPr>',
      );
      for (var c = 0; c < layout.columns; c++) {
        buffer.write('<w:tc><w:tcPr><w:tcW w:w="$cell" w:type="dxa"/></w:tcPr><w:p>');
        // A 1 pt paragraph mark keeps Word from adding line height under the
        // picture, which would push the row past its exact height.
        buffer.write(
          '<w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>'
          '<w:rPr><w:sz w:val="2"/></w:rPr></w:pPr>',
        );
        if (placed < job.copies) {
          buffer.write(_picture(drawingId++, imageWidth, imageHeight));
          placed++;
        }
        buffer.write('</w:p></w:tc>');
      }
      buffer.write('</w:tr>');
    }

    buffer
      ..write('</w:tbl>')
      ..write(
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/>'
        '<w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>',
      )
      ..write(
        '<w:sectPr><w:pgSz w:w="${_twips(job.paper.widthMm)}" w:h="${_twips(job.paper.heightMm)}"/>'
        '<w:pgMar w:top="$margin" w:right="$margin" w:bottom="$margin" w:left="$margin" '
        'w:header="0" w:footer="0" w:gutter="0"/></w:sectPr>',
      )
      ..write('</w:body></w:document>');
    return buffer.toString();
  }

  static String _picture(int id, int width, int height) {
    return '<w:r><w:rPr><w:sz w:val="2"/></w:rPr><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$width" cy="$height"/>'
        '<wp:docPr id="$id" name="Label $id"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="label.png"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$width" cy="$height"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  static int _twips(double mm) => (mm / 25.4 * 1440).round();

  static int _emu(double mm) => (mm * 36000).round();
}
