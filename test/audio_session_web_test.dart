@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:writing_human/audio/audio_session_policy.dart';
import 'package:writing_human/audio/user_audio_web.dart';
import 'package:writing_human/ui/writing_sound_web.dart';
import 'package:writing_human/ui/paper_sound_effect.dart';

@JS('Object.defineProperty')
external JSObject _defineProperty(
  JSObject object,
  JSString name,
  JSObject descriptor,
);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _descriptor(JSObject object, JSString name);
@JS('Reflect.deleteProperty')
external JSBoolean _delete(JSObject object, JSString name);

void main() {
  testWidgets(
    'Real writing output requests playback only for input and releases on pause',
    (tester) async {
      final name = 'audioSession'.toJS;
      final previous = _descriptor(web.window.navigator, name);
      final audio = JSObject()..setProperty('type'.toJS, 'auto'.toJS);
      _defineProperty(
        web.window.navigator,
        name,
        JSObject()
          ..setProperty('value'.toJS, audio)
          ..setProperty('configurable'.toJS, true.toJS),
      );
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (_) async => ByteData(1),
      );
      final output = PaperSoundOutput(PaperSoundEffect.writingRhythm);
      try {
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'auto');
        output.play(PaperSoundRequest(() => false));
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'auto');
        output.play(PaperSoundRequest(() => true));
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'playback');
        output.pause();
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'auto');
        output.play(PaperSoundRequest(() => true));
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'playback');
      } finally {
        await output.dispose();
        expect(audio.getProperty<JSString>('type'.toJS).toDart, 'auto');
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
        if (previous == null) {
          _delete(web.window.navigator, name);
        } else {
          _defineProperty(web.window.navigator, name, previous);
        }
      }
    },
  );

  test(
    'Browser adapter sets playback and restores through the real interop boundary',
    () {
      final audio = JSObject()..setProperty('type'.toJS, 'auto'.toJS);
      final navigator = JSObject()..setProperty('audioSession'.toJS, audio);
      final access = BrowserAudioSessionAccess(navigator);
      final sessions = AudioSessionLeases(access), owner = Object();
      expect(sessions.acquire(owner), isTrue);
      expect(audio.getProperty<JSString>('type'.toJS).toDart, 'playback');
      sessions.release(owner);
      expect(audio.getProperty<JSString>('type'.toJS).toDart, 'auto');
    },
  );
  test(
    'Missing browser API is harmless and does not create an audio session',
    () {
      final navigator = JSObject();
      final access = BrowserAudioSessionAccess(navigator);
      final sessions = AudioSessionLeases(access), owner = Object();
      expect(sessions.acquire(owner), isFalse);
      sessions.release(owner);
      expect(navigator.hasProperty('audioSession'.toJS).toDart, isFalse);
      // Inspect support only; do not change the actual browser's global policy.
      expect(
        () => BrowserAudioSessionAccess(web.window.navigator).type,
        returnsNormally,
      );
    },
  );
  test(
    'An exposed but read-only API does not report activation as successful',
    () {
      final audio = JSObject();
      _defineProperty(
        audio,
        'type'.toJS,
        JSObject()
          ..setProperty('value'.toJS, 'ambient'.toJS)
          ..setProperty('writable'.toJS, false.toJS),
      );
      final navigator = JSObject()..setProperty('audioSession'.toJS, audio);
      final access = BrowserAudioSessionAccess(navigator);
      final sessions = AudioSessionLeases(access), owner = Object();
      expect(sessions.acquire(owner), isFalse);
      sessions.release(owner);
      expect(access.type, 'ambient');
    },
  );
}
