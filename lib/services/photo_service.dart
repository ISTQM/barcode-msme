import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Takes or picks a product photo. Photos are shrunk on the way in so they stay
/// small on a shop phone with limited storage.
class PhotoService {
  const PhotoService();

  static const double _maxSide = 1280;
  static const int _quality = 82;

  /// Null when the person backs out without choosing.
  Future<File?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    return picked == null ? null : File(picked.path);
  }
}
