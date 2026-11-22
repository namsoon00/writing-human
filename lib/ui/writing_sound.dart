import 'dart:async';

import 'package:flutter/material.dart';

import 'paper_sound_effect.dart';
import 'writing_sound_native.dart'
    if (dart.library.js_interop) 'writing_sound_web.dart';

/// Keep one writing rhythm active across brief pauses, or play page samples.
class PaperSound {
  PaperSound.writing() : this._(PaperSoundEffect.writingRhythm);
  PaperSound.pageTurn() : this._(PaperSoundEffect.pageTurn);
  PaperSound._(this._effect) : _output = PaperSoundOutput(_effect);

  final PaperSoundEffect _effect;
  final PaperSoundOutput _output;
  PaperSoundRequest? _pending;
  Timer? _timer;
  bool _closed = false;

  void play(bool Function() isCurrent) {
    if (_closed || !isCurrent()) return;
    final request = PaperSoundRequest(isCurrent);
    if (_effect.loops) {
      _timer?.cancel();
      _timer = Timer(writingRhythmIdle, pause);
      _output.play(request);
      return;
    }
    _pending = request;
    if (_timer == null) _flush();
  }

  void pause() {
    if (_closed || !_effect.loops) return;
    _timer?.cancel();
    _timer = null;
    _output.pause();
  }

  void _flush() {
    _timer = null;
    final request = _pending;
    if (request == null || !request.canPlay) {
      _pending = null;
      return;
    }
    _pending = null;
    _timer = Timer(_effect.minimumInterval, _flush);
    _output.play(request);
  }

  Future<void> dispose() {
    _closed = true;
    _timer?.cancel();
    _pending = null;
    return _output.dispose();
  }
}

/// Play once when a visible letter is inserted or starts composing. As an IME
/// updates a syllable in place or commits it, that syllable already had a sound.
bool hasNewWrittenCharacter(TextEditingValue before, TextEditingValue after) {
  if (before.text == after.text ||
      !after.selection.isValid ||
      !after.selection.isCollapsed ||
      after.selection.end > after.text.length) {
    return false;
  }
  final wasComposing =
      before.isComposingRangeValid && !before.composing.isCollapsed;
  final composing = after.isComposingRangeValid && !after.composing.isCollapsed;
  final start = wasComposing ? before.composing.start : before.selection.start;
  final oldEnd = wasComposing ? before.composing.end : before.selection.end;
  if (wasComposing &&
      (!composing || after.composing.start <= before.composing.start)) {
    return false;
  }
  final insertedStart = composing ? after.composing.start : start;
  final newEnd = composing ? after.composing.end : after.selection.end;
  if (start < 0 ||
      oldEnd > before.text.length ||
      insertedStart < start ||
      newEnd <= insertedStart ||
      newEnd - insertedStart > 24) {
    return false;
  }

  // Check the edited range, including when input happens in the middle.
  final tailLength = before.text.length - oldEnd;
  if (after.text.length - newEnd != tailLength ||
      !after.text.startsWith(before.text.substring(0, start)) ||
      !after.text.endsWith(before.text.substring(oldEnd))) {
    return false;
  }
  final inserted = after.text.substring(insertedStart, newEnd);
  return inserted.trim().isNotEmpty && inserted.characters.length == 1;
}
