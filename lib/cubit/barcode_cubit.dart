import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/barcode_repository.dart';
import '../data/product_barcode.dart';
import 'barcode_state.dart';

class BarcodeCubit extends Cubit<BarcodeState> {
  BarcodeCubit(this._repository) : super(const BarcodeState()) {
    _reload();
  }

  final BarcodeRepository _repository;

  ProductBarcode? find(String barcode) => _repository.find(barcode);

  File? photoOf(ProductBarcode product) => _repository.photoFile(product.photo);

  /// Stores a new barcode, copying [photo] into the app folder first.
  Future<void> create(ProductBarcode product, {File? photo}) async {
    final stored =
        photo == null ? null : await _repository.savePhoto(photo, product.barcode);
    await _repository.put(product.copyWith(photo: stored));
    _reload();
  }

  Future<void> delete(String barcode) async {
    await _repository.delete(barcode);
    _reload();
  }

  void _reload() {
    final items = _repository.all()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(items: items));
  }
}
