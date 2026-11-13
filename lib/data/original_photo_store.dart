import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'model.dart';
import 'original_photo_store_native.dart'
    if (dart.library.js_interop) 'original_photo_store_web.dart'
    as platform;

const originalPhotoLimit = 20 * 1024 * 1024;

class OriginalPhotoStore {
  const OriginalPhotoStore();

  Future<String> save(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > originalPhotoLimit) {
      throw const FormatException('사진은 20MB까지 보관할 수 있어요.');
    }
    final id = sha256.convert(bytes).toString();
    await platform.writePhoto(id, bytes);
    return id;
  }

  Future<Uint8List?> load(String id) async {
    if (!validOriginalPhotoId(id)) throw const FormatException('잘못된 사진 ID');
    return platform.readPhoto(id);
  }
}
