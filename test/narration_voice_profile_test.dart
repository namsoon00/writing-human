import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/audio/narration_model_assets.dart';
import 'package:writing_human/audio/narration_voice_profile.dart';
import 'package:writing_human/audio/voice_stretch_native.dart'
    if (dart.library.js_interop) 'package:writing_human/audio/voice_stretch_web.dart';

Float32List signal(int rate, {double seconds = 2, double hz = 220}) =>
    Float32List.fromList(
      List.generate(
        (rate * seconds).round(),
        (i) => .14 * math.sin(2 * math.pi * hz * i / rate),
      ),
    );

double frequency(Float32List data, int rate) {
  final from = math.min(rate ~/ 2, data.length ~/ 4),
      length = math.min(rate, data.length - from - 200);
  final correlations = <int, double>{};
  for (var lag = (rate / 350).floor(); lag < (rate / 100).ceil(); lag++) {
    var corr = 0.0;
    for (var i = from; i < from + length; i++) {
      corr += data[i] * data[i + lag];
    }
    correlations[lag] = corr;
  }
  final peaks = correlations.keys
      .where(
        (lag) =>
            correlations.containsKey(lag - 1) &&
            correlations.containsKey(lag + 1) &&
            correlations[lag]! > correlations[lag - 1]! &&
            correlations[lag]! >= correlations[lag + 1]!,
      )
      .toList();
  final max = peaks.map((lag) => correlations[lag]!).reduce(math.max);
  return rate / peaks.firstWhere((lag) => correlations[lag]! >= max * .95);
}

double rms(Iterable<double> values) {
  final list = values.toList();
  return math.sqrt(list.fold(0.0, (sum, x) => sum + x * x) / list.length);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    const base = String.fromEnvironment('VOICE_TEST_ASSET_BASE');
    if (base.isEmpty) {
      throw StateError(
        'Run node tool/test_narration_web.mjs for browser assets',
      );
    }
    // The Flutter browser-test messenger does not serve application assets.
    // Supply the real bundled modules from the test-only local HTTP fixture.
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final path = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      final response = await http.get(Uri.parse(base).resolve(path));
      if (response.statusCode != 200) {
        throw StateError('Missing test asset: $path');
      }
      return ByteData.sublistView(response.bodyBytes);
    });
  }
  test(
    'Only the approved F1 preset is downloaded; old voices are not alternatives',
    () {
      expect(narrationVoiceId, 'F1');
      expect(
        narrationAssets
            .where((asset) => asset.path.startsWith('voice_styles/'))
            .map((a) => a.path),
        ['voice_styles/F1.json'],
      );
      expect(narrationSynthesisSpeed, .90);
      expect(narrationSpeechSpeed, .78);
      expect(narrationPitchSemitones, -2);
    },
  );

  test(
    'Real DSP stretches duration independently from pitch and does not lose the signal',
    () async {
      final dsp = VoiceStretch();
      addTearDown(dsp.close);
      const rate = 22050;
      final input = signal(rate);
      final output = await dsp.process(input, rate, .78, -2, () {});
      expect(output.length, (input.length / .78).round());
      expect(output.every((x) => x.isFinite), isTrue);
      expect(rms(output), greaterThan(.03));
      expect(frequency(output, rate), closeTo(220 * math.pow(2, -2 / 12), 3));
    },
  );

  test(
    'A silent request after speech does not retain the previous audio',
    () async {
      final dsp = VoiceStretch();
      addTearDown(dsp.close);
      await dsp.process(signal(16000), 16000, .78, -2, () {});
      final silence = await dsp.process(
        Float32List(16000),
        16000,
        .78,
        -2,
        () {},
      );
      expect(silence.every((x) => x.isFinite), isTrue);
      expect(silence.map((x) => x.abs()).reduce(math.max), lessThan(.00001));
    },
  );

  test(
    'A stop while processing prevents the late audio from becoming playable',
    () async {
      final dsp = VoiceStretch();
      addTearDown(dsp.close);
      var stopped = false;
      final result = dsp.process(signal(22050), 22050, .78, -2, () {
        if (stopped) throw StateError('stopped');
      });
      stopped = true;
      await expectLater(result, throwsStateError);
      await dsp.close();
      await expectLater(
        dsp.process(signal(16000), 16000, .78, -2, () {}),
        throwsStateError,
      );
    },
  );

  test('WAV input rejects damaged PCM instead of hiding the failure', () {
    expect(() => readVoiceWav(Uint8List(44)), throwsFormatException);
    final wav = writeVoiceWav(signal(16000), 16000);
    final decoded = readVoiceWav(wav);
    expect(decoded.$2, 16000);
    expect(decoded.$1.length, 32000);
    final truncated = Uint8List.fromList(wav.sublist(0, wav.length - 10));
    expect(() => readVoiceWav(truncated), throwsFormatException);
  });

  test(
    'Full approved profile is slower, lower, level-bounded and softer at its close',
    () async {
      const rate = 22050;
      final profile = NarrationVoiceProfile();
      addTearDown(profile.close);
      final input = signal(rate, seconds: 3);
      final wav = await profile.process(writeVoiceWav(input, rate), () {});
      final (output, outputRate) = readVoiceWav(wav);
      expect(outputRate, rate);
      expect(output.length, greaterThan(input.length / .8));
      expect(output.every((x) => x.isFinite), isTrue);
      expect(output.map((x) => x.abs()).reduce(math.max), lessThan(.91));
      expect(frequency(output, rate), closeTo(220 * math.pow(2, -2 / 12), 3));
      final opening = rms(output.skip(rate).take(rate ~/ 3));
      final close = rms(
        output
            .skip(output.length - (rate * .3).round())
            .take((rate * .2).round()),
      );
      expect(close, lessThan(opening * .9));
    },
  );
}
