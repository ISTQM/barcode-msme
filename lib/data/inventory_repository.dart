import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'inventory_item.dart';

/// Offline-only storage. Hive keeps the box in memory and appends writes to a
/// local file, so reads are instant and every awaited write is on disk.
class InventoryRepository {
  InventoryRepository._(this._box);

  static const String _boxName = 'inventory';

  final Box<Map> _box;

  static Future<InventoryRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>(_boxName);
    return InventoryRepository._(box);
  }

  List<InventoryItem> all() {
    return [
      for (final key in _box.keys)
        InventoryItem.fromMap(key as String, _box.get(key)!),
    ];
  }

  InventoryItem? find(String barcode) {
    final map = _box.get(barcode);
    return map == null ? null : InventoryItem.fromMap(barcode, map);
  }

  /// Insert or overwrite by barcode, so re-scanning an item updates it.
  Future<void> put(InventoryItem item) => _box.put(item.barcode, item.toMap());

  Future<void> delete(String barcode) => _box.delete(barcode);
}
