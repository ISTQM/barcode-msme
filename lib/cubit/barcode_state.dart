import '../data/product_barcode.dart';

class BarcodeState {
  const BarcodeState({this.items = const []});

  /// Every barcode the shop has made, newest first.
  final List<ProductBarcode> items;

  BarcodeState copyWith({List<ProductBarcode>? items}) {
    return BarcodeState(items: items ?? this.items);
  }
}
