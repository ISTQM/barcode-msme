import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/inventory_item.dart';
import '../data/receipt.dart';
import 'receipt_state.dart';

/// Holds the receipt being built. It lives in memory only and never touches
/// stock counts.
class ReceiptCubit extends Cubit<ReceiptState> {
  ReceiptCubit() : super(const ReceiptState());

  void setType(ReceiptType type) => emit(state.copyWith(type: type));

  void setPaper(PaperWidth paper) => emit(state.copyWith(paper: paper));

  /// Adds one unit, or bumps the quantity if the item is already on the receipt.
  void addItem(InventoryItem item) {
    final existing = state.lines.where((l) => l.barcode == item.barcode);
    if (existing.isNotEmpty) {
      setQuantity(item.barcode, existing.first.quantity + 1);
      return;
    }
    emit(
      state.copyWith(
        lines: [
          ...state.lines,
          ReceiptLine(
            barcode: item.barcode,
            name: item.name,
            quantity: 1,
            unitPriceCentavos: item.priceCentavos,
          ),
        ],
      ),
    );
  }

  void setQuantity(String barcode, int quantity) {
    _update(barcode, (line) => line.copyWith(quantity: quantity < 1 ? 1 : quantity));
  }

  void setUnitPrice(String barcode, int centavos) {
    _update(barcode, (line) => line.copyWith(unitPriceCentavos: centavos));
  }

  void remove(String barcode) {
    emit(
      state.copyWith(
        lines: state.lines.where((l) => l.barcode != barcode).toList(),
      ),
    );
  }

  void clear() => emit(state.copyWith(lines: const []));

  /// Snapshot for printing. Date and time are stamped at this moment.
  Receipt build() {
    return Receipt(
      type: state.type,
      paper: state.paper,
      issuedAt: DateTime.now(),
      lines: state.lines,
    );
  }

  int quantityOf(String barcode) {
    for (final line in state.lines) {
      if (line.barcode == barcode) return line.quantity;
    }
    return 0;
  }

  void _update(String barcode, ReceiptLine Function(ReceiptLine) change) {
    emit(
      state.copyWith(
        lines: [
          for (final line in state.lines)
            line.barcode == barcode ? change(line) : line,
        ],
      ),
    );
  }
}
