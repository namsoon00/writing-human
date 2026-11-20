import 'dart:async';
import 'dart:typed_data';

import 'narration_model.dart';
import 'narration_output.dart'
    if (dart.library.js_interop) 'narration_output_web.dart';
import 'read_aloud.dart';

class ModelReadAloud implements BrandReadAloud {
  ModelReadAloud(this.voice, this.onProgress);

  final NarrationVoice voice;
  final void Function(double?) onProgress;
  final _stopped = Completer<void>();
  final _output = NarrationOutput();
  Future<NarrationModel>? _model;
  Future<Uint8List>? _generation;
  String? _preparedText;

  void _check() {
    if (_stopped.isCompleted) throw const _NarrationStopped();
  }

  Future<Uint8List> _generate(String text) async {
    final model = await (_model ??= NarrationModel.open(
      _stopped.future,
      _check,
      (value) {
        if (!_stopped.isCompleted) onProgress(value);
      },
    ));
    _check();
    return model.synthesize(text, voice.name.toUpperCase(), _check);
  }

  @override
  Future<void> speak(String text, {String? next}) async {
    final ready = _output.ready();
    if (_model == null) onProgress(0);
    await ready;
    _check();
    final generation = _preparedText == text
        ? _generation!
        : (_generation = _generate(text));
    _preparedText = null;
    final wav = await generation;
    _check();
    onProgress(null);
    await _output.play(wav, _stopped.future, () {
      if (next == null || _stopped.isCompleted) return;
      _preparedText = next;
      final prepared = _generation = _generate(next);
      unawaited(prepared.then<void>((_) {}, onError: (Object _) {}));
    });
  }

  @override
  Future<void> stop() async {
    if (_stopped.isCompleted) return;
    _stopped.complete();
    try {
      await _output.close();
    } finally {
      // Native inference calls are not interrupted in the middle of a step.
      // Release the sessions when the outstanding step or download unwinds.
      unawaited(_closeModel());
    }
  }

  Future<void> _closeModel() async {
    try {
      await _generation;
    } catch (_) {
      // Cancellation or an inference error has already ended playback.
    }
    try {
      final model = await _model;
      await model?.close();
    } catch (_) {
      // Failed initialization releases its partial sessions.
    }
  }
}

class _NarrationStopped implements Exception {
  const _NarrationStopped();
}
