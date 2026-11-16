import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'read_aloud.dart';

ReadAloud createReadAloud() => _WebReadAloud();

class _WebReadAloud implements ReadAloud {
  _WebReadAloud() {
    // Start loading the browser's voice list before the Play gesture.
    try {
      web.window.speechSynthesis.getVoices();
    } catch (_) {
      // Report missing browser support when the user presses Play.
    }
  }

  web.SpeechSynthesisUtterance? _utterance;
  Completer<void>? _completion;

  @override
  Future<void> speak(String text) async {
    final synth = web.window.speechSynthesis;
    final voices = synth.getVoices().toDart.where(
      (voice) => voice.localService && isKoreanVoice(voice.lang),
    );
    final voice =
        voices.where((voice) => voice.default_).firstOrNull ??
        voices.firstOrNull;
    if (voice == null) throw const KoreanVoiceUnavailable();

    final completion = Completer<void>();
    final utterance = web.SpeechSynthesisUtterance(text)
      ..voice = voice
      ..lang = voice.lang
      ..rate = readAloudRate
      ..onend = ((web.Event _) {
        if (!completion.isCompleted) completion.complete();
      }).toJS
      ..onerror = ((web.Event _) {
        if (!completion.isCompleted) {
          completion.completeError(StateError('Browser speech failed.'));
        }
      }).toJS;
    _utterance = utterance;
    _completion = completion;
    try {
      synth.speak(utterance);
      await completion.future;
    } finally {
      if (_utterance == utterance) {
        _utterance = null;
        _completion = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    final completion = _completion;
    if (completion == null || completion.isCompleted) return;
    completion.complete();
    web.window.speechSynthesis.cancel();
  }
}
