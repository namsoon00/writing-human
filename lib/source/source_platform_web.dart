import 'dart:js_interop';
import 'dart:ui' show Rect;

import 'source_intake.dart';
import 'source_scan.dart';

@JS('writingHumanScanPhoto')
external JSPromise<JSArray<JSAny?>> _scan(
  JSUint8Array bytes,
  JSNumber width,
  JSNumber height,
  JSBoolean tight,
);

@JS('writingHumanCancelOcr')
external void _cancel();

SourceIntake createSourceIntake() => _WebSourceIntake();

class _WebSourceIntake extends SourceIntake {
  @override
  Future<SourceScan> scan(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
    try {
      final image = await ScanImage.decode(
        photo.bytes,
        region: region,
        mask: mask,
      );
      final result = await _scan(
        image.bytes.toJS,
        image.width.toJS,
        image.height.toJS,
        (region != null).toJS,
      ).toDart;
      return SourceScan.fromPlatform(image, result.dartify() as List<Object?>);
    } catch (_) {
      throw const SourceIntakeException('사진 속 글자를 읽지 못했어요. 다시 시도하거나 붙여넣어 주세요.');
    }
  }

  @override
  void cancelRecognition() => _cancel();
}
