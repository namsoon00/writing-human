import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'user_audio_context.dart';

class NarrationOutput {
  AudioPlayer? _player;

  Future<void> ready() async {}

  Future<void> play(
    Uint8List wav,
    Future<void> stopped,
    void Function() onStart,
  ) async {
    final player = _player ??= AudioPlayer();
    final done = Completer<void>();
    final subscription = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    }, onError: done.completeError);
    try {
      await player.play(
        BytesSource(wav, mimeType: 'audio/wav'),
        ctx: AudioContext(iOS: userAudioIOS()),
      );
      onStart();
      await Future.any([done.future, stopped]);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> close() async {
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
