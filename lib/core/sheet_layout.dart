/// Paper the labels can be laid out on. The Philippines uses A4 and the two
/// "bond paper" sizes, short (letter) and long (8.5 x 13 in).
enum PaperSize {
  a4('A4', '210 × 297 mm', 210, 297),
  shortBond('Short bond', '8.5 × 11 in', 215.9, 279.4),
  longBond('Long bond', '8.5 × 13 in', 215.9, 330.2);

  const PaperSize(this.label, this.dimensions, this.widthMm, this.heightMm);

  final String label;
  final String dimensions;
  final double widthMm;
  final double heightMm;
}

/// Printed size of one label, in millimetres.
class LabelSize {
  const LabelSize(this.widthMm, this.heightMm);

  static const LabelSize small = LabelSize(38, 25);
  static const LabelSize medium = LabelSize(50, 30);
  static const LabelSize large = LabelSize(70, 40);

  static const double minWidthMm = 20;
  static const double maxWidthMm = 150;
  static const double minHeightMm = 12;
  static const double maxHeightMm = 100;

  final double widthMm;
  final double heightMm;

  String get text => '${_trim(widthMm)} × ${_trim(heightMm)} mm';

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  @override
  bool operator ==(Object other) =>
      other is LabelSize &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(widthMm, heightMm);
}

/// How many labels fit on a sheet and how many sheets a run needs. PDF and
/// DOCX both read their grid from here, so they come out the same.
class SheetLayout {
  SheetLayout._(this.columns, this.rows, this.copies);

  /// Clear border most office printers cannot print into.
  static const double marginMm = 8;

  /// Space to the right of and below every label, for cutting.
  static const double gapMm = 2;

  factory SheetLayout.compute({
    required PaperSize paper,
    required LabelSize label,
    required int copies,
  }) {
    // The tiny epsilon keeps an exact fit from losing a row to float error.
    int fit(double room, double size) =>
        ((room + 1e-6) / (size + gapMm)).floor();
    return SheetLayout._(
      fit(paper.widthMm - 2 * marginMm, label.widthMm),
      fit(paper.heightMm - 2 * marginMm, label.heightMm),
      copies,
    );
  }

  final int columns;
  final int rows;
  final int copies;

  /// False when one label is larger than the printable area.
  bool get fits => columns > 0 && rows > 0;

  int get perPage => columns * rows;

  int get pages => fits ? (copies / perPage).ceil() : 0;
}
