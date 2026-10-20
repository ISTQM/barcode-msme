class InventoryItem {
  const InventoryItem({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.scannedAt,
  });

  final String barcode;
  final String name;
  final int quantity;
  final DateTime scannedAt;

  InventoryItem copyWith({String? name, int? quantity, DateTime? scannedAt}) {
    return InventoryItem(
      barcode: barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  /// The barcode is the box key, so it is not part of the stored map.
  Map<String, Object> toMap() {
    return {
      'name': name,
      'qty': quantity,
      'at': scannedAt.millisecondsSinceEpoch,
    };
  }

  factory InventoryItem.fromMap(String barcode, Map<dynamic, dynamic> map) {
    return InventoryItem(
      barcode: barcode,
      name: map['name'] as String? ?? '',
      quantity: map['qty'] as int? ?? 0,
      scannedAt: DateTime.fromMillisecondsSinceEpoch(map['at'] as int? ?? 0),
    );
  }
}
