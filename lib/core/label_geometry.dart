import 'dart:math' as math;

import 'package:barcode/barcode.dart';

import 'barcode_codec.dart';

/// How much of the product is printed around the bars.
enum LabelStyle {
  barcodeOnly('Barcode', 'Bars and number only'),
  withName('With name', 'Product name above the bars'),
  nameAndPrice('Name & price', 'Name above the bars, price below');

  const LabelStyle(this.label, this.description);

  final String label;
  final String description;

  bool get showsName => this != barcodeOnly;
  bool get showsPrice => this == nameAndPrice;
}

/// Everything a label prints. Plain data, so it can cross into an isolate.
class LabelContent {
  const LabelContent({
    required this.symbology,
    required this.code,
    required this.name,
    this.details = '',
    this.priceText = '',
  });

  final BarcodeSymbology symbology;
  final String code;
  final String name;

  /// Size or variant, printed after the name.
  final String details;

  /// Already formatted, for example "₱25.00". Empty prints no price.
  final String priceText;

  String get title => details.isEmpty ? name : '$name · $details';
}

enum LabelAlign { left, center, right }

/// A filled black rectangle. Coordinates are millimetres from the top left.
class LabelRect {
  const LabelRect(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;
}

/// A single line of text inside a box. The font size is the box height, and
/// whoever draws it shrinks the text to fit the box width.
class LabelText {
  const LabelText({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.text,
    required this.align,
    this.bold = false,
  });

  final double x;
  final double y;
  final double w;
  final double h;
  final String text;
  final LabelAlign align;
  final bool bold;
}

/// The drawing of one label as rectangles and text boxes, in millimetres.
///
/// It has no dependency on Flutter, so the on-screen preview, the PNG export
/// and the PDF all draw from this one description and match each other.
class LabelGeometry {
  const LabelGeometry({
    required this.widthMm,
    required this.heightMm,
    required this.bars,
    required this.texts,
    required this.moduleMm,
    required this.barHeightMm,
  });

  /// Narrowest bar a scanner can resolve reliably.
  static const double minModuleMm = 0.25;

  /// Shortest bars a hand-held scanner can be aimed at.
  static const double minBarHeightMm = 6;

  final double widthMm;
  final double heightMm;
  final List<LabelRect> bars;
  final List<LabelText> texts;

  /// Width of the narrowest bar.
  final double moduleMm;
  final double barHeightMm;

  bool get scansReliably =>
      moduleMm >= minModuleMm && barHeightMm >= minBarHeightMm;

  factory LabelGeometry.build(
    LabelContent content,
    LabelStyle style, {
    required double widthMm,
    required double heightMm,
  }) {
    final pad = (math.min(widthMm, heightMm) * 0.08).clamp(1.5, 3.0);
    const gap = 0.6;
    final innerWidth = widthMm - 2 * pad;
    final innerHeight = heightMm - 2 * pad;

    final texts = <LabelText>[];
    var top = pad;
    var bottom = heightMm - pad;

    if (style.showsName) {
      final rowHeight = (innerHeight * 0.17).clamp(2.0, 4.5);
      texts.add(
        LabelText(
          x: pad,
          y: top,
          w: innerWidth,
          h: rowHeight,
          text: _truncate(content.title, innerWidth, rowHeight),
          align: LabelAlign.center,
          bold: true,
        ),
      );
      top += rowHeight + gap;
    }

    if (style.showsPrice && content.priceText.isNotEmpty) {
      final rowHeight = (innerHeight * 0.2).clamp(2.4, 5.5);
      texts.add(
        LabelText(
          x: pad,
          y: bottom - rowHeight,
          w: innerWidth,
          h: rowHeight,
          text: content.priceText,
          align: LabelAlign.center,
          bold: true,
        ),
      );
      bottom -= rowHeight + gap;
    }

    final areaHeight = bottom - top;
    final digitHeight = (areaHeight * 0.2).clamp(1.8, 3.2);
    const digitPadding = 0.4;

    // The symbol is centred and its bars sized so the blank space beside them
    // is at least the quiet zone the symbology asks for. EAN-13 draws its
    // first digit and end marker inside that space, so they count towards it.
    var barcodeLeft = pad;
    var barcodeWidth = innerWidth;
    if (content.symbology == BarcodeSymbology.ean13) {
      const modules = 95;
      final module = math.min(
        (innerWidth - 2 * digitHeight) / modules,
        widthMm / (modules + 2 * content.symbology.quietModules),
      );
      barcodeWidth = modules * module + 2 * digitHeight;
      barcodeLeft = (widthMm - barcodeWidth) / 2;
    } else {
      const edge = 1.0;
      final quiet = content.symbology.quietModules;
      final modules = _moduleCount(content);
      final module = (widthMm - 2 * edge) / (modules + 2 * quiet);
      barcodeLeft = edge + quiet * module;
      barcodeWidth = modules * module;
    }

    final bars = <LabelRect>[];
    for (final element in content.symbology.encoder.make(
      content.code,
      width: barcodeWidth,
      height: areaHeight,
      drawText: true,
      fontHeight: digitHeight,
      textPadding: digitPadding,
    )) {
      final left = barcodeLeft + element.left;
      final y = top + element.top;
      if (element is BarcodeBar) {
        if (element.black) {
          bars.add(LabelRect(left, y, element.width, element.height));
        }
      } else if (element is BarcodeText) {
        texts.add(
          LabelText(
            x: left,
            y: y,
            w: element.width,
            h: element.height,
            text: element.text,
            align: switch (element.align) {
              BarcodeTextAlign.left => LabelAlign.left,
              BarcodeTextAlign.center => LabelAlign.center,
              BarcodeTextAlign.right => LabelAlign.right,
            },
          ),
        );
      }
    }

    return LabelGeometry(
      widthMm: widthMm,
      heightMm: heightMm,
      bars: bars,
      texts: texts,
      moduleMm: bars.map((bar) => bar.w).reduce(math.min),
      barHeightMm: bars.map((bar) => bar.h).reduce(math.max),
    );
  }

  /// Width of the symbol in modules (narrowest bars), found by encoding it
  /// once without text and dividing by the narrowest bar.
  static int _moduleCount(LabelContent content) {
    final bars = content.symbology.encoder
        .make(content.code, width: 1000, height: 1)
        .whereType<BarcodeBar>();
    return (1000 / bars.map((bar) => bar.width).reduce(math.min)).round();
  }

  /// Cuts a title that would shrink below 70% of the row height, since text
  /// that small cannot be read once printed.
  static String _truncate(String text, double widthMm, double heightMm) {
    final maxChars = (widthMm / (heightMm * 0.7 * 0.58)).floor();
    if (text.length <= maxChars) return text;
    final kept = text.substring(0, math.max(1, maxChars - 1));
    return '${kept.replaceAll(RegExp(r'[\s·,\-]+$'), '')}…';
  }
}
