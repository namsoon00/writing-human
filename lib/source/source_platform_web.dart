import 'dart:js_interop';

import 'source_intake.dart';

@JS('writingHumanRecognizePhoto')
external JSPromise<JSArray<JSString>> _recognize(JSUint8Array bytes);

@JS('writingHumanCancelOcr')
external void _cancel();

SourceIntake createSourceIntake() => _WebSourceIntake();

class _WebSourceIntake extends SourceIntake {
  @override
  Future<List<String>> recognize(SourcePhoto photo) async {
    try {
      final blocks = await _recognize(photo.bytes.toJS).toDart;
      return blocks.toDart.map((text) => text.toDart).toList();
    } catch (_) {
      throw const SourceIntakeException('사진 속 글자를 읽지 못했어요. 다시 시도하거나 붙여넣어 주세요.');
    }
  }

  @override
  void cancelRecognition() => _cancel();
}
