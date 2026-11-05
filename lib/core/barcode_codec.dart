import 'dart:math';

import 'package:barcode/barcode.dart';

/// The symbologies offered for products numbered inside the app. All three are
/// linear codes that every Philippine retail scanner, and the scanner in this
/// app, reads without configuration.
enum BarcodeSymbology {
  ean13('EAN-13', 'Standard on Philippine retail packs. 13 digits.'),
  ean8('EAN-8', 'For small packs with little room. 8 digits.'),
  code128('Code 128', 'Your own SKU codes. Letters and numbers.');

  const BarcodeSymbology(this.label, this.description);

  final String label;
  final String description;

  bool get numericOnly => this != code128;

  /// Digits typed before the check digit is appended. Zero means free text.
  int get payloadLength => switch (this) {
        ean13 => 12,
        ean8 => 7,
        code128 => 0,
      };

  /// Blank modules the symbology needs beside the bars, where a module is the
  /// width of the narrowest bar. EAN-13 asks for 11 on the left and 7 on the
  /// right, and a label's own margin and digits cover both.
  int get quietModules => switch (this) {
        ean13 => 11,
        ean8 => 7,
        code128 => 10,
      };

  Barcode get encoder => switch (this) {
        ean13 => Barcode.ean13(drawEndChar: true),
        ean8 => Barcode.ean8(),
        code128 => Barcode.code128(),
      };
}

/// Outcome of [BarcodeCodec.check]: either the full code to store, or a
/// message that can be shown under the text field.
class BarcodeCheck {
  const BarcodeCheck.ok(String this.code) : error = null;
  const BarcodeCheck.error(String this.error) : code = null;

  final String? code;
  final String? error;

  bool get isValid => code != null;
}

class BarcodeCodec {
  BarcodeCodec._();

  /// A longer Code 128 value would need bars too thin to print on a label.
  static const int maxCode128Length = 24;

  /// GS1 modulo-10 check digit. The digit next to the check position weighs 3,
  /// then 1, 3, 1 going left, which holds for EAN-13 and EAN-8 alike.
  static String checkDigit(String payload) {
    var sum = 0;
    for (var i = 0; i < payload.length; i++) {
      final digit = payload.codeUnitAt(payload.length - 1 - i) - 0x30;
      sum += i.isEven ? digit * 3 : digit;
    }
    return ((10 - sum % 10) % 10).toString();
  }

  /// Validates what the user typed. EAN input may omit the check digit, which
  /// is then added; when it is included it has to be right.
  static BarcodeCheck check(BarcodeSymbology symbology, String input) {
    final value = input.trim();

    if (!symbology.numericOnly) {
      if (value.isEmpty) return const BarcodeCheck.error('Enter a code.');
      if (value.length > maxCode128Length) {
        return const BarcodeCheck.error(
          'Use $maxCode128Length characters or fewer.',
        );
      }
      final printable = value.codeUnits.every((c) => c >= 0x20 && c <= 0x7E);
      if (!printable) {
        return const BarcodeCheck.error(
          'Use letters, numbers and basic symbols only.',
        );
      }
      return BarcodeCheck.ok(value);
    }

    final payload = symbology.payloadLength;
    if (!RegExp(r'^\d*$').hasMatch(value)) {
      return const BarcodeCheck.error('Digits only.');
    }
    if (value.length == payload) {
      return BarcodeCheck.ok(value + checkDigit(value));
    }
    if (value.length == payload + 1) {
      final expected = checkDigit(value.substring(0, payload));
      if (value.substring(payload) != expected) {
        return BarcodeCheck.error(
          'The last digit should be $expected. '
          'Or type only the first $payload digits.',
        );
      }
      return BarcodeCheck.ok(value);
    }
    return BarcodeCheck.error(
      'Type $payload digits (the check digit is added) or ${payload + 1}.',
    );
  }

  /// A fresh number for the shop's own products. EAN numbers start with 2,
  /// the range GS1 sets aside for in-store use, so they never collide with a
  /// manufacturer's registered prefix such as 480 for the Philippines.
  static String generate(BarcodeSymbology symbology, Random random) {
    String digits(int count) =>
        List.generate(count, (_) => random.nextInt(10)).join();

    switch (symbology) {
      case BarcodeSymbology.ean13:
        final payload = '2${digits(11)}';
        return payload + checkDigit(payload);
      case BarcodeSymbology.ean8:
        final payload = '2${digits(6)}';
        return payload + checkDigit(payload);
      case BarcodeSymbology.code128:
        return 'SKU${digits(7)}';
    }
  }
}
