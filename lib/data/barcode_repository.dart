import 'dart:io';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'product_barcode.dart';

/// Offline storage for the barcodes the shop has made. Records live in a Hive
/// box keyed by barcode, product photos are plain files in the app folder.
class BarcodeRepository {
  BarcodeRepository(this._box, this._photoDirectory);

  static const String _boxName = 'barcodes';

  final Box<Map> _box;
  final Directory _photoDirectory;

  static Future<BarcodeRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>(_boxName);
    final documents = await getApplicationDocumentsDirectory();
    final photos = Directory(
      '${documents.path}${Platform.pathSeparator}product_photos',
    );
    await photos.create(recursive: true);
    return BarcodeRepository(box, photos);
  }

  List<ProductBarcode> all() {
    return [
      for (final key in _box.keys)
        ProductBarcode.fromMap(key as String, _box.get(key)!),
    ];
  }

  ProductBarcode? find(String barcode) {
    final map = _box.get(barcode);
    return map == null ? null : ProductBarcode.fromMap(barcode, map);
  }

  Future<void> put(ProductBarcode product) =>
      _box.put(product.barcode, product.toMap());

  /// Removes the record and its photo.
  Future<void> delete(String barcode) async {
    final photo = photoFile(find(barcode)?.photo);
    await _box.delete(barcode);
    if (photo != null && await photo.exists()) await photo.delete();
  }

  /// Copies a picked photo into the app folder and returns the stored file
  /// name. Only the name is saved: the folder's full path can change when the
  /// app is updated.
  Future<String> savePhoto(File source, String barcode) async {
    final safeCode = barcode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dot = source.path.lastIndexOf('.');
    final extension =
        dot == -1 ? 'jpg' : source.path.substring(dot + 1).toLowerCase();
    final name = '${safeCode}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await source.copy('${_photoDirectory.path}${Platform.pathSeparator}$name');
    return name;
  }

  File? photoFile(String? name) => name == null
      ? null
      : File('${_photoDirectory.path}${Platform.pathSeparator}$name');
}
