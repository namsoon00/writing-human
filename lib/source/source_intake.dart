import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'source_scan.dart';

import 'package:image_picker/image_picker.dart';

const sourceLengthLimit = 50000;
const _photoSizeLimit = 20 * 1024 * 1024;

String normalizeSource(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

final _paragraphBreak = RegExp(r'\n[^\S\n]*\n(?:[^\S\n]*\n)*');

List<String> splitSourceParagraphs(String text) =>
    normalizeSource(text).split(_paragraphBreak);

String sourceFromParagraph(String text, int index) {
  final paragraphs = splitSourceParagraphs(text);
  return paragraphs.skip(index.clamp(0, paragraphs.length - 1)).join('\n\n');
}

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
  bool get canUseLiveCamera => false;
  final ImagePicker _picker = ImagePicker();

  Future<SourcePhoto?> pickPhoto({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
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

  Future<SourceScan> scan(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  });

  Future<SourceScan> scanLiveFrame(SourcePhoto photo) => scan(photo);
  void endLiveRecognition() => cancelRecognition();
  void cancelRecognition() {}
  Stream<void> get incomingChanges => const Stream.empty();
  Future<List<IncomingSource>> pendingShares() async => const [];
  Future<void> acknowledgeShare(String id) async {}
  void dispose() {}
}
