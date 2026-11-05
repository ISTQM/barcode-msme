import 'dart:math';

import 'package:barcode_msme/core/barcode_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkDigit', () {
    test('matches published EAN-13 and EAN-8 examples', () {
      expect(BarcodeCodec.checkDigit('400638133393'), '1');
      expect(BarcodeCodec.checkDigit('7351353'), '7');
    });

    test('is 0 when the weighted sum is a multiple of ten', () {
      expect(BarcodeCodec.checkDigit('000000000000'), '0');
    });
  });

  group('check', () {
    test('EAN-13 appends the check digit to 12 digits', () {
      final result = BarcodeCodec.check(BarcodeSymbology.ean13, '400638133393');
      expect(result.code, '4006381333931');
    });

    test('EAN-13 accepts 13 digits with a correct check digit', () {
      final result =
          BarcodeCodec.check(BarcodeSymbology.ean13, ' 4006381333931 ');
      expect(result.code, '4006381333931');
    });

    test('EAN-13 rejects a wrong check digit and names the right one', () {
      final result =
          BarcodeCodec.check(BarcodeSymbology.ean13, '4006381333930');
      expect(result.isValid, isFalse);
      expect(result.error, contains('should be 1'));
    });

    test('EAN rejects other lengths and non-digits', () {
      expect(BarcodeCodec.check(BarcodeSymbology.ean13, '12345').isValid,
          isFalse);
      expect(BarcodeCodec.check(BarcodeSymbology.ean13, '').isValid, isFalse);
      expect(BarcodeCodec.check(BarcodeSymbology.ean8, '12AB567').error,
          'Digits only.');
    });

    test('EAN-8 appends the check digit to 7 digits', () {
      expect(BarcodeCodec.check(BarcodeSymbology.ean8, '7351353').code,
          '73513537');
    });

    test('Code 128 takes printable ASCII up to the length limit', () {
      expect(BarcodeCodec.check(BarcodeSymbology.code128, 'RICE-5KG').code,
          'RICE-5KG');
      expect(BarcodeCodec.check(BarcodeSymbology.code128, '').isValid,
          isFalse);
      expect(BarcodeCodec.check(BarcodeSymbology.code128, 'Café').isValid,
          isFalse);
      expect(
        BarcodeCodec.check(BarcodeSymbology.code128, 'A' * 25).isValid,
        isFalse,
      );
    });
  });

  group('generate', () {
    test('every symbology generates a code that passes its own check', () {
      final random = Random(7);
      for (final symbology in BarcodeSymbology.values) {
        for (var i = 0; i < 50; i++) {
          final code = BarcodeCodec.generate(symbology, random);
          expect(BarcodeCodec.check(symbology, code).code, code);
        }
      }
    });

    test('EAN codes use the in-store prefix and the right length', () {
      final random = Random(1);
      final ean13 = BarcodeCodec.generate(BarcodeSymbology.ean13, random);
      final ean8 = BarcodeCodec.generate(BarcodeSymbology.ean8, random);
      expect(ean13.length, 13);
      expect(ean13.startsWith('2'), isTrue);
      expect(ean8.length, 8);
      expect(ean8.startsWith('2'), isTrue);
    });
  });
}
