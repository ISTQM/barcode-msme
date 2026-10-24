class InventoryItem {
  const InventoryItem({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.scannedAt,
    this.priceCentavos = 0,
  });

  final String barcode;
  final String name;
  final int quantity;
  final DateTime scannedAt;

  /// Unit price in centavos. Zero means no price was entered.
  final int priceCentavos;

  InventoryItem copyWith({
    String? name,
    int? quantity,
    DateTime? scannedAt,
    int? priceCentavos,
  }) {
    return InventoryItem(
      barcode: barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      scannedAt: scannedAt ?? this.scannedAt,
      priceCentavos: priceCentavos ?? this.priceCentavos,
    );
  }

  /// The barcode is the box key, so it is not part of the stored map.
  Map<String, Object> toMap() {
    return {
      'name': name,
      'qty': quantity,
      'at': scannedAt.millisecondsSinceEpoch,
      'price': priceCentavos,
    };
  }

  /// Items saved before prices existed have no 'price' key and read as 0.
  factory InventoryItem.fromMap(String barcode, Map<dynamic, dynamic> map) {
    return InventoryItem(
      barcode: barcode,
      name: map['name'] as String? ?? '',
      quantity: map['qty'] as int? ?? 0,
      scannedAt: DateTime.fromMillisecondsSinceEpoch(map['at'] as int? ?? 0),
      priceCentavos: map['price'] as int? ?? 0,
    );
  }
}
