import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<File> _file(String id) async {
  final root = await getApplicationSupportDirectory();
  return File('${root.path}/original-photos/$id');
}

Future<Uint8List?> readPhoto(String id) async {
  final file = await _file(id);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> writePhoto(String id, Uint8List bytes) async {
  final file = await _file(id);
  if (await file.exists()) return;
  await file.parent.create(recursive: true);
  final temp = await file.parent.createTemp('incoming-');
  try {
    final pending = await File(
      '${temp.path}/photo',
    ).writeAsBytes(bytes, flush: true);
    await pending.rename(file.path);
  } finally {
    await temp.delete(recursive: true);
  }
}
