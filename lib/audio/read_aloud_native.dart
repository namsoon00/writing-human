import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'read_aloud.dart';

ReadAloud createReadAloud() => _NativeReadAloud();

class _NativeReadAloud implements ReadAloud {
  final _tts = FlutterTts();
  Future<void>? _voiceReady;
  int _generation = 0;

  int _quality(Map<String, String> voice) => switch (voice['quality']) {
    'premium' || 'very high' => 3,
    'enhanced' || 'high' => 2,
    'normal' || 'default' => 1,
    _ => 0,
  };

  Future<void> _configure() async {
    final reported = await _tts.getVoices;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final korean = [
      if (reported is List)
        for (final entry in reported.whereType<Map>())
          if (entry['locale'] is String &&
              isKoreanVoice(entry['locale'] as String) &&
              (!android ||
                  (entry['network_required'] == '0' &&
                      !(entry['features'] as String? ?? '')
                          .split('\t')
                          .contains('notInstalled'))))
            Map<String, String>.from(entry),
    ]..sort((a, b) => _quality(b).compareTo(_quality(a)));
    if (korean.isEmpty) throw const KoreanVoiceUnavailable();

    final voice = korean.first;
    if (await _tts.setVoice({
          'name': voice['name']!,
          'locale': voice['locale']!,
          if (voice['identifier'] case final String id) 'identifier': id,
        }) !=
        1) {
      throw const KoreanVoiceUnavailable();
    }
    await _tts.setSpeechRate(readAloudRate / 2);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(String text) async {
    final generation = _generation;
    try {
      await (_voiceReady ??= _configure()).timeout(const Duration(seconds: 10));
    } catch (_) {
      _voiceReady = null;
      rethrow;
    }
    if (generation != _generation) return;
    if (await _tts.speak(text) != 1 && generation == _generation) {
      throw StateError('Speech did not complete.');
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _tts.stop();
  }
}
