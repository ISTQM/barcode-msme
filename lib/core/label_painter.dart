import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'label_geometry.dart';

/// Paints a [LabelGeometry] on a canvas. The on-screen preview and the PNG
/// export both use it, so what the user sees is what gets exported.
class LabelPainter extends CustomPainter {
  const LabelPainter(this.geometry, {this.cutGuides = false});

  /// The bundled Roboto, declared in pubspec.yaml.
  static const String fontFamily = 'LabelRoboto';

  final LabelGeometry geometry;

  /// Draws a hairline border to cut along. Never used for the plain image.
  final bool cutGuides;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / geometry.widthMm;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final ink = Paint()..color = Colors.black;
    for (final bar in geometry.bars) {
      canvas.drawRect(
        Rect.fromLTWH(bar.x * scale, bar.y * scale, bar.w * scale, bar.h * scale),
        ink,
      );
    }

    for (final text in geometry.texts) {
      _paintText(canvas, text, scale);
    }

    if (cutGuides) {
      final width = (0.2 * scale).clamp(1.0, 4.0);
      canvas.drawRect(
        (Offset.zero & size).deflate(width / 2),
        Paint()
          ..color = const Color(0xFF9CA3AF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
  }

  void _paintText(Canvas canvas, LabelText text, double scale) {
    final boxWidth = text.w * scale;
    final boxHeight = text.h * scale;

    TextPainter layout(double fontSize) {
      return TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: Colors.black,
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: text.bold ? FontWeight.w700 : FontWeight.w400,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    var painter = layout(boxHeight);
    if (painter.width > boxWidth) {
      final fitted = boxHeight * boxWidth / painter.width;
      painter.dispose();
      painter = layout(fitted);
    }

    final dx = switch (text.align) {
      LabelAlign.left => 0.0,
      LabelAlign.center => (boxWidth - painter.width) / 2,
      LabelAlign.right => boxWidth - painter.width,
    };
    painter.paint(
      canvas,
      Offset(text.x * scale + dx, text.y * scale + (boxHeight - painter.height) / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(LabelPainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.cutGuides != cutGuides;

  /// Renders one label to PNG bytes [widthPx] wide.
  static Future<Uint8List> renderPng(
    LabelGeometry geometry, {
    required int widthPx,
    bool cutGuides = false,
  }) async {
    final heightPx = (widthPx * geometry.heightMm / geometry.widthMm).round();
    final recorder = ui.PictureRecorder();
    LabelPainter(geometry, cutGuides: cutGuides).paint(
      Canvas(recorder),
      Size(widthPx.toDouble(), heightPx.toDouble()),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(widthPx, heightPx);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }
}
