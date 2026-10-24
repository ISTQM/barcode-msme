import '../data/receipt.dart';

class ReceiptState {
  const ReceiptState({
    this.type = ReceiptType.acknowledgement,
    this.paper = PaperWidth.mm58,
    this.lines = const [],
  });

  final ReceiptType type;
  final PaperWidth paper;
  final List<ReceiptLine> lines;

  int get totalCentavos =>
      lines.fold(0, (sum, line) => sum + line.amountCentavos);

  ReceiptState copyWith({
    ReceiptType? type,
    PaperWidth? paper,
    List<ReceiptLine>? lines,
  }) {
    return ReceiptState(
      type: type ?? this.type,
      paper: paper ?? this.paper,
      lines: lines ?? this.lines,
    );
  }
}
