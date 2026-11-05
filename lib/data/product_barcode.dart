import '../core/barcode_codec.dart';
import '../core/label_geometry.dart';
import '../core/money.dart';

/// A barcode the shop made for one of its own products.
class ProductBarcode {
  const ProductBarcode({
    required this.barcode,
    required this.symbology,
    required this.style,
    required this.name,
    required this.createdAt,
    this.details = '',
    this.priceCentavos = 0,
    this.photo,
  });

  final String barcode;
  final BarcodeSymbology symbology;

  /// Label style chosen when the barcode was made. Printing can override it.
  final LabelStyle style;
  final String name;

  /// Size or variant, for example "250 ml".
  final String details;

  /// Unit price in centavos. Zero means no price was entered.
  final int priceCentavos;

  /// File name of the product photo inside the app's photo folder.
  final String? photo;
  final DateTime createdAt;

  LabelContent get content => LabelContent(
        symbology: symbology,
        code: barcode,
        name: name,
        details: details,
        priceText: priceCentavos > 0 ? Money.peso(priceCentavos) : '',
      );

  ProductBarcode copyWith({String? photo}) {
    return ProductBarcode(
      barcode: barcode,
      symbology: symbology,
      style: style,
      name: name,
      createdAt: createdAt,
      details: details,
      priceCentavos: priceCentavos,
      photo: photo ?? this.photo,
    );
  }

  /// The barcode is the box key, so it is not part of the stored map.
  Map<String, Object> toMap() {
    return {
      'format': symbology.name,
      'style': style.name,
      'name': name,
      'details': details,
      'price': priceCentavos,
      'photo': ?photo,
      'at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Unknown or missing enum names fall back to the first value, so a record
  /// written by a newer build still opens.
  factory ProductBarcode.fromMap(String barcode, Map<dynamic, dynamic> map) {
    return ProductBarcode(
      barcode: barcode,
      symbology: BarcodeSymbology.values.firstWhere(
        (value) => value.name == map['format'],
        orElse: () => BarcodeSymbology.ean13,
      ),
      style: LabelStyle.values.firstWhere(
        (value) => value.name == map['style'],
        orElse: () => LabelStyle.barcodeOnly,
      ),
      name: map['name'] as String? ?? '',
      details: map['details'] as String? ?? '',
      priceCentavos: map['price'] as int? ?? 0,
      photo: map['photo'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['at'] as int? ?? 0),
    );
  }
}
