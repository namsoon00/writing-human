import 'dart:js_interop';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

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
  bool get canUseCamera =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  int _generation = 0;

  @override
  Future<SourceScan> scan(
    SourcePhoto photo, {
    Rect? region,
    List<Rect> mask = const [],
  }) async {
    final generation = ++_generation;
    try {
      final image = await ScanImage.decode(
        photo.bytes,
        region: region,
        mask: mask,
        preserveRegionDetail: true,
      );
      if (generation != _generation) {
        return SourceScan.fromText(photo.bytes, const []);
      }
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
  void cancelRecognition() {
    _generation++;
    _cancel();
  }
}
