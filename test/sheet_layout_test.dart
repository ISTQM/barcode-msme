import 'package:barcode_msme/core/sheet_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A4 holds 3 x 8 medium labels', () {
    final layout = SheetLayout.compute(
      paper: PaperSize.a4,
      label: LabelSize.medium,
      copies: 30,
    );
    expect(layout.columns, 3);
    expect(layout.rows, 8);
    expect(layout.perPage, 24);
    expect(layout.pages, 2);
  });

  test('long bond fits more rows than short bond', () {
    SheetLayout layout(PaperSize paper) => SheetLayout.compute(
          paper: paper,
          label: LabelSize.medium,
          copies: 1,
        );
    expect(layout(PaperSize.longBond).rows,
        greaterThan(layout(PaperSize.shortBond).rows));
  });

  test('copies exactly filling a page need one page', () {
    final layout = SheetLayout.compute(
      paper: PaperSize.a4,
      label: LabelSize.medium,
      copies: 24,
    );
    expect(layout.pages, 1);
  });

  test('a label larger than the printable area does not fit', () {
    final layout = SheetLayout.compute(
      paper: PaperSize.a4,
      label: const LabelSize(210, 40),
      copies: 1,
    );
    expect(layout.fits, isFalse);
    expect(layout.pages, 0);
  });

  test('LabelSize prints whole numbers without a decimal', () {
    expect(LabelSize.medium.text, '50 × 30 mm');
    expect(const LabelSize(52.5, 30).text, '52.5 × 30 mm');
  });
}
