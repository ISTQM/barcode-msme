import 'package:barcode_msme/core/barcode_codec.dart';
import 'package:barcode_msme/core/label_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

LabelContent content({
  BarcodeSymbology symbology = BarcodeSymbology.ean13,
  String code = '4006381333931',
  String name = 'Lucky Me Pancit Canton',
  String details = '',
  String priceText = '₱15.00',
}) {
  return LabelContent(
    symbology: symbology,
    code: code,
    name: name,
    details: details,
    priceText: priceText,
  );
}

LabelGeometry build(
  LabelContent c,
  LabelStyle style, {
  double w = 50,
  double h = 30,
}) {
  return LabelGeometry.build(c, style, widthMm: w, heightMm: h);
}

void main() {
  test('every bar and text box stays inside the label', () {
    for (final style in LabelStyle.values) {
      for (final symbology in BarcodeSymbology.values) {
        final code = switch (symbology) {
          BarcodeSymbology.ean13 => '4006381333931',
          BarcodeSymbology.ean8 => '73513537',
          BarcodeSymbology.code128 => 'SKU1234567',
        };
        final g = build(content(symbology: symbology, code: code), style);
        for (final bar in g.bars) {
          expect(bar.x, greaterThanOrEqualTo(0));
          expect(bar.y, greaterThanOrEqualTo(0));
          expect(bar.x + bar.w, lessThanOrEqualTo(g.widthMm + 1e-6));
          expect(bar.y + bar.h, lessThanOrEqualTo(g.heightMm + 1e-6));
        }
        for (final text in g.texts) {
          expect(text.x, greaterThanOrEqualTo(0));
          expect(text.x + text.w, lessThanOrEqualTo(g.widthMm + 1e-6));
          expect(text.y + text.h, lessThanOrEqualTo(g.heightMm + 1e-6));
        }
      }
    }
  });

  test('bars keep the quiet zone the symbology needs on both sides', () {
    // Left and right clear space, in modules, from the label edge to the bars.
    final needs = {
      BarcodeSymbology.ean13: (11, 7),
      BarcodeSymbology.ean8: (7, 7),
      BarcodeSymbology.code128: (10, 10),
    };
    const codes = {
      BarcodeSymbology.ean13: '4006381333931',
      BarcodeSymbology.ean8: '73513537',
      BarcodeSymbology.code128: 'SKU1234567',
    };
    for (final symbology in BarcodeSymbology.values) {
      for (final size in const [(38.0, 25.0), (50.0, 30.0), (70.0, 40.0)]) {
        for (final style in LabelStyle.values) {
          final g = build(
            content(symbology: symbology, code: codes[symbology]!),
            style,
            w: size.$1,
            h: size.$2,
          );
          final (left, right) = needs[symbology]!;
          final first = g.bars.map((b) => b.x).reduce((a, b) => a < b ? a : b);
          final last =
              g.bars.map((b) => b.x + b.w).reduce((a, b) => a > b ? a : b);
          expect(first, greaterThanOrEqualTo(left * g.moduleMm - 1e-6),
              reason: '$symbology ${size.$1}x${size.$2} left');
          expect(g.widthMm - last, greaterThanOrEqualTo(right * g.moduleMm - 1e-6),
              reason: '$symbology ${size.$1}x${size.$2} right');
        }
      }
    }
  });

  test('EAN-13 prints its 13 digits and the end marker', () {
    final g = build(content(), LabelStyle.barcodeOnly);
    final printed = g.texts.map((t) => t.text).join();
    expect(printed, '4006381333931>');
  });

  test('styles add the name and the price rows', () {
    final only = build(content(), LabelStyle.barcodeOnly);
    final named = build(content(), LabelStyle.withName);
    final priced = build(content(), LabelStyle.nameAndPrice);
    expect(only.texts.any((t) => t.text == 'Lucky Me Pancit Canton'), isFalse);
    expect(named.texts.any((t) => t.text == 'Lucky Me Pancit Canton'), isTrue);
    expect(named.texts.any((t) => t.text == '₱15.00'), isFalse);
    expect(priced.texts.any((t) => t.text == '₱15.00'), isTrue);
  });

  test('no price row is drawn when there is no price', () {
    final g = build(content(priceText: ''), LabelStyle.nameAndPrice);
    final noPrice = build(content(priceText: ''), LabelStyle.withName);
    expect(g.texts.length, noPrice.texts.length);
  });

  test('details follow the name', () {
    final g = build(
      content(name: 'Pancit Canton', details: '250 ml'),
      LabelStyle.withName,
    );
    expect(g.texts.any((t) => t.text == 'Pancit Canton · 250 ml'), isTrue);
  });

  test('a very long name is cut with an ellipsis', () {
    final g = build(content(name: 'A' * 80), LabelStyle.withName);
    final title = g.texts.firstWhere((t) => t.bold).text;
    expect(title.endsWith('…'), isTrue);
    expect(title.length, lessThan(80));
  });

  test('a medium EAN-13 label scans reliably, a tiny one does not', () {
    expect(build(content(), LabelStyle.barcodeOnly).scansReliably, isTrue);
    final tiny = build(content(), LabelStyle.barcodeOnly, w: 22, h: 14);
    expect(tiny.scansReliably, isFalse);
  });

  test('narrowest bar is one module wide', () {
    final g = build(content(), LabelStyle.barcodeOnly);
    // 95 modules of bars plus the digit margin on each side.
    expect(g.moduleMm, inInclusiveRange(0.3, 0.5));
  });
}
