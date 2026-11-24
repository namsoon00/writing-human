import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/audio/audio_session_policy.dart';
import 'package:writing_human/audio/user_audio_context.dart';

class _Access implements AudioSessionAccess {
  String? value = 'ambient';
  bool denied = false, ignored = false;
  final writes = <String>[];
  @override
  String? get type => value;
  @override
  set type(String next) {
    if (denied) throw StateError('read only');
    if (ignored) return;
    writes.add(next);
    value = next;
  }
}

void main() {
  test(
    'Audio policy stays idle until an explicit request and restores on end',
    () {
      final access = _Access(), owner = Object();
      final sessions = AudioSessionLeases(access);
      expect(access.writes, isEmpty);
      expect(sessions.acquire(owner), isTrue);
      expect(access.type, 'playback');
      sessions.release(owner);
      expect(access.type, 'ambient');
    },
  );
  test(
    'Overlapping writing and cafe sounds retain playback until both finish',
    () {
      final access = _Access(), writing = Object(), cafe = Object();
      final sessions = AudioSessionLeases(access);
      sessions.acquire(writing);
      sessions.acquire(writing);
      sessions.acquire(cafe);
      sessions.release(writing);
      sessions.release(writing);
      expect(access.type, 'playback');
      sessions.release(cafe);
      expect(access.type, 'ambient');
      expect(access.writes, ['playback', 'ambient']);
    },
  );
  test(
    'Unavailable or denied APIs fail safely without a bogus session owner',
    () {
      for (final access in [
        _Access()..value = null,
        _Access()..denied = true,
        _Access()..ignored = true,
      ]) {
        final sessions = AudioSessionLeases(access), owner = Object();
        final original = access.type;
        expect(sessions.acquire(owner), isFalse);
        sessions.release(owner);
        expect(access.type, original);
      }
    },
  );
  test(
    'Another feature taking the session is not overwritten during cleanup',
    () {
      final access = _Access(), owner = Object();
      final sessions = AudioSessionLeases(access);
      sessions.acquire(owner);
      access.value = 'play-and-record';
      expect(sessions.acquire(Object()), isFalse);
      sessions.release(owner);
      expect(access.type, 'play-and-record');
    },
  );
  test(
    'A pre-existing media session remains playback after this sound finishes',
    () {
      final access = _Access()..value = 'playback';
      final sessions = AudioSessionLeases(access), owner = Object();
      sessions.acquire(owner);
      sessions.release(owner);
      expect(access.type, 'playback');
      expect(access.writes, isEmpty);
    },
  );
  test(
    'Native iPhone audio uses playback with mixing, without a recording route',
    () {
      final context = userAudioIOS();
      expect(context.category, AVAudioSessionCategory.playback);
      expect(context.options, {AVAudioSessionOptions.mixWithOthers});
    },
  );
}
