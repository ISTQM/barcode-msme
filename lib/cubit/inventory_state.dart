import '../data/inventory_item.dart';

class InventoryState {
  const InventoryState({this.items = const [], this.query = ''});

  /// Every stored item, newest scan first.
  final List<InventoryItem> items;
  final String query;

  /// Items matching the search query by name or barcode.
  List<InventoryItem> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (item) =>
              item.name.toLowerCase().contains(q) ||
              item.barcode.toLowerCase().contains(q),
        )
        .toList();
  }

  InventoryState copyWith({List<InventoryItem>? items, String? query}) {
    return InventoryState(
      items: items ?? this.items,
      query: query ?? this.query,
    );
  }
}
