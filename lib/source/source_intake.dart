import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

const sourceLengthLimit = 50000;
const _photoSizeLimit = 20 * 1024 * 1024;

String normalizeSource(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

final _paragraphBreak = RegExp(r'\n[^\S\n]*\n(?:[^\S\n]*\n)*');

List<String> splitSourceParagraphs(String text) =>
    normalizeSource(text).split(_paragraphBreak);

class SourcePhoto {
  const SourcePhoto(this.path, this.bytes);
  final String path;
  final Uint8List bytes;
}

class IncomingSource {
  const IncomingSource(this.id, this.text);
  final String id, text;
}

class SourceIntakeException implements Exception {
  const SourceIntakeException(this.message);
  final String message;
}

/// Platform acquisition only. A photo or an OS share never writes a record.
abstract class SourceIntake {
  bool get canUseCamera => false;
  final ImagePicker _picker = ImagePicker();

  Future<SourcePhoto?> pickPhoto({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    return file == null ? null : readPhoto(file);
  }

  Future<SourcePhoto?> recoverPhoto() async => null;
  Future<SourcePhoto> readPhoto(XFile file) async {
    if (await file.length() > _photoSizeLimit) {
      throw const SourceIntakeException('20MB보다 작은 사진을 골라 주세요.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _photoSizeLimit) {
      throw const SourceIntakeException('사진을 읽지 못했어요. 다른 사진을 골라 주세요.');
    }
    return SourcePhoto(file.path, bytes);
  }

  Future<List<String>> recognize(SourcePhoto photo);
  void cancelRecognition() {}
  Stream<void> get incomingChanges => const Stream.empty();
  Future<List<IncomingSource>> pendingShares() async => const [];
  Future<void> acknowledgeShare(String id) async {}
  void dispose() {}
}
