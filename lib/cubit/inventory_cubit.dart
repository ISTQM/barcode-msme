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
    int priceCentavos = 0,
  }) async {
    await _repository.put(
      InventoryItem(
        barcode: barcode,
        name: name.trim(),
        quantity: quantity,
        scannedAt: DateTime.now(),
        priceCentavos: priceCentavos,
      ),
    );
    _reload();
  }

  /// Drops the item from state first so a swiped tile leaves the tree in the
  /// same frame, then removes it from disk.
  Future<void> delete(String barcode) async {
    emit(
      state.copyWith(
        items: state.items.where((item) => item.barcode != barcode).toList(),
      ),
    );
    await _repository.delete(barcode);
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
