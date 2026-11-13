import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Accept a single visible grapheme at the edit position. A composing range can
/// move forward when the IME commits one syllable and starts the next.
bool hasNewWrittenCharacter(TextEditingValue before, TextEditingValue after) {
  if (before == after ||
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
  final end = composing ? after.composing.start : after.selection.end;
  final newEnd = composing ? after.composing.end : end;
  if (start < 0 ||
      oldEnd > before.text.length ||
      end <= start ||
      end - start > 24 ||
      (!wasComposing && composing) ||
      (!wasComposing && before.text == after.text)) {
    return false;
  }

  // Check the edited range, including when input happens in the middle.
  final tailLength = before.text.length - oldEnd;
  if (after.text.length - newEnd != tailLength ||
      !after.text.startsWith(before.text.substring(0, start)) ||
      !after.text.endsWith(before.text.substring(oldEnd))) {
    return false;
  }
  final inserted = after.text.substring(start, end);
  return inserted.trim().isNotEmpty && inserted.characters.length == 1;
}

class WritingSound {
  AudioPlayer? _player;
  final _interval = Stopwatch();
  bool _busy = false, _disposed = false;

  Future<void> stroke(bool Function() isFocused) async {
    // Coalesce bursts and keep only one playback in flight.
    if (_disposed ||
        _busy ||
        (_interval.isRunning && _interval.elapsedMilliseconds < 92)) {
      return;
    }
    _busy = true;
    _interval
      ..reset()
      ..start();
    try {
      var player = _player;
      if (player == null) {
        player = _player = AudioPlayer();
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
              usageType: AndroidUsageType.assistanceSonification,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(.26);
        await player.setSource(AssetSource('audio/pen-stroke.wav'));
      }
      if (!_disposed && isFocused()) await player.resume();
    } catch (error) {
      debugPrint('Writing sound unavailable: $error');
      final player = _player;
      _player = null;
      await _disposePlayer(player);
    } finally {
      _busy = false;
      if (_disposed) await _disposePlayer(_player);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (!_busy) await _disposePlayer(_player);
  }

  Future<void> _disposePlayer(AudioPlayer? player) async {
    try {
      await player?.dispose();
    } catch (error) {
      debugPrint('Could not release writing audio: $error');
    }
  }
}
