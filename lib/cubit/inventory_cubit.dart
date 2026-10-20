import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/inventory_item.dart';
import '../data/inventory_repository.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._repository) : super(const InventoryState()) {
    _reload();
  }

  final InventoryRepository _repository;

  InventoryItem? find(String barcode) => _repository.find(barcode);

  /// Saves a scan or an edit and stamps it with the current time.
  Future<void> save({
    required String barcode,
    required String name,
    required int quantity,
  }) async {
    await _repository.put(
      InventoryItem(
        barcode: barcode,
        name: name.trim(),
        quantity: quantity,
        scannedAt: DateTime.now(),
      ),
    );
    _reload();
  }

  Future<void> delete(String barcode) async {
    await _repository.delete(barcode);
    _reload();
  }

  /// Puts back a deleted item untouched, used by the undo snackbar.
  Future<void> restore(InventoryItem item) async {
    await _repository.put(item);
    _reload();
  }

  void search(String query) => emit(state.copyWith(query: query));

  void _reload() {
    final items = _repository.all()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    emit(state.copyWith(items: items));
  }
}
