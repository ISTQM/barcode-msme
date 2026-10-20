/// The only two document titles this app is allowed to print.
enum ReceiptType {
  acknowledgement('ACKNOWLEDGEMENT RECEIPT', 'Acknowledgement', 'ACK_RECEIPT'),
  orderSlip('ORDER SLIP', 'Order Slip', 'ORDER_SLIP');

  const ReceiptType(this.title, this.label, this.filePrefix);

  /// Printed at the top of the document.
  final String title;

  /// Shown on the type toggle.
  final String label;

  final String filePrefix;
}

/// Thermal roll widths.
enum PaperWidth {
  mm58(58),
  mm80(80);

  const PaperWidth(this.mm);

  final int mm;

  String get label => '$mm mm';
}

class ReceiptLine {
  const ReceiptLine({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.unitPriceCentavos,
  });

  final String barcode;
  final String name;
  final int quantity;
  final int unitPriceCentavos;

  int get amountCentavos => quantity * unitPriceCentavos;

  ReceiptLine copyWith({int? quantity, int? unitPriceCentavos}) {
    return ReceiptLine(
      barcode: barcode,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPriceCentavos: unitPriceCentavos ?? this.unitPriceCentavos,
    );
  }
}

class Receipt {
  const Receipt({
    required this.type,
    required this.paper,
    required this.issuedAt,
    required this.lines,
  });

  final ReceiptType type;
  final PaperWidth paper;
  final DateTime issuedAt;
  final List<ReceiptLine> lines;

  int get totalCentavos =>
      lines.fold(0, (sum, line) => sum + line.amountCentavos);
}
