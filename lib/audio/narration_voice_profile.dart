import 'dart:math' as math;
import 'dart:typed_data';
import 'voice_stretch_native.dart'
    if (dart.library.js_interop) 'voice_stretch_web.dart';

/// The one approved voice: warm F1, low register, unhurried, gentle endings.
const narrationVoiceId = 'F1';
const narrationSynthesisSpeed = .90;
const narrationSpeechSpeed = .78;
const narrationPitchSemitones = -2.0;

class NarrationVoiceProfile {
  final _stretch = VoiceStretch();

  Future<Uint8List> process(Uint8List wav, void Function() check) async {
    final (audio, rate) = readVoiceWav(wav);
    check();
    var result = await _stretch.process(
      audio,
      rate,
      narrationSpeechSpeed,
      narrationPitchSemitones,
      check,
    );
    _shelf(result, rate, 180, 1.2, high: false);
    _shelf(result, rate, 3800, -2, high: true);
    _normalize(result);
    check();
    // Preserve natural lead-in and release; remove only unusually long edge silence.
    result = _trim(result, rate);
    final end = _lastActive(result, rate);
    if (end > rate * .3) {
      final start = math.max(0, end - rate);
      final original = Float32List.fromList(result.sublist(start));
      final tail = await _stretch.process(original, rate, .88, 0, check);
      final blend = math.min(
        (rate * .04).round(),
        math.min(original.length, tail.length),
      );
      for (var i = 0; i < blend; i++) {
        final t = i / math.max(1, blend - 1);
        tail[i] = original[i] * (1 - t) + tail[i] * t;
      }
      final voiceEnd = (end - start) / .88;
      final rampStart = rate * .15;
      for (var i = 0; i < tail.length; i++) {
        final t = ((i - rampStart) / math.max(1, voiceEnd - rampStart)).clamp(
          0.0,
          1.0,
        );
        final smooth = t * t * (3 - 2 * t);
        tail[i] *= math.pow(10, -3.5 * smooth / 20).toDouble();
      }
      result = Float32List(start + tail.length)
        ..setRange(0, start, result)
        ..setRange(start, start + tail.length, tail);
    }
    check();
    return writeVoiceWav(result, rate);
  }

  Future<void> close() => _stretch.close();
}

(Float32List, int) readVoiceWav(Uint8List wav) {
  if (wav.length < 44) throw const FormatException('Invalid voice WAV');
  final b = ByteData.sublistView(wav);
  if (b.getUint32(0) != 0x52494646 || b.getUint32(8) != 0x57415645) {
    throw const FormatException('Invalid voice WAV header');
  }
  int? rate, start, count;
  var position = 12;
  while (position + 8 <= wav.length) {
    final kind = b.getUint32(position);
    final size = b.getUint32(position + 4, Endian.little);
    final data = position + 8;
    if (size > wav.length - data) {
      throw const FormatException('Truncated voice WAV');
    }
    if (kind == 0x666d7420) {
      if (size < 16 ||
          b.getUint16(data, Endian.little) != 1 ||
          b.getUint16(data + 2, Endian.little) != 1 ||
          b.getUint16(data + 14, Endian.little) != 16) {
        throw const FormatException('Unsupported voice PCM');
      }
      rate = b.getUint32(data + 4, Endian.little);
    } else if (kind == 0x64617461) {
      start = data;
      count = size ~/ 2;
    }
    position = data + size + size % 2;
  }
  if (rate == null ||
      rate < 8000 ||
      rate > 96000 ||
      start == null ||
      count == null ||
      count == 0 ||
      count > rate * 90) {
    throw const FormatException('Invalid voice PCM length');
  }
  return (
    Float32List.fromList([
      for (var i = 0; i < count; i++)
        b.getInt16(start + 2 * i, Endian.little) / 32768,
    ]),
    rate,
  );
}

Uint8List writeVoiceWav(Float32List audio, int rate) {
  final bytes = ByteData(44 + audio.length * 2);
  bytes
    ..setUint32(0, 0x52494646)
    ..setUint32(4, 36 + audio.length * 2, Endian.little)
    ..setUint32(8, 0x57415645)
    ..setUint32(12, 0x666d7420)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461)
    ..setUint32(40, audio.length * 2, Endian.little);
  for (var i = 0; i < audio.length; i++) {
    if (!audio[i].isFinite) {
      throw const FormatException('Invalid generated voice');
    }
    bytes.setInt16(
      44 + 2 * i,
      (audio[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

void _normalize(Float32List audio) {
  var square = 0.0, peak = 0.0;
  for (final value in audio) {
    square += value * value;
    peak = math.max(peak, value.abs());
  }
  if (!peak.isFinite || peak == 0) return;
  final rms = math.sqrt(square / audio.length),
      gain = math.min(.09 / rms, .9 / peak);
  for (var i = 0; i < audio.length; i++) {
    audio[i] *= gain;
  }
}

int _lastActive(Float32List audio, int rate) {
  final hop = (rate * .01).round();
  for (var end = audio.length; end > 0; end -= hop) {
    final start = math.max(0, end - hop);
    var energy = 0.0;
    for (var i = start; i < end; i++) {
      energy += audio[i] * audio[i];
    }
    if (math.sqrt(energy / (end - start)) > .006) return end;
  }
  return 0;
}

Float32List _trim(Float32List audio, int rate) {
  final end = _lastActive(audio, rate);
  if (end == 0) return audio;
  final hop = (rate * .01).round();
  var first = 0;
  for (; first < audio.length; first += hop) {
    final finish = math.min(first + hop, audio.length);
    var energy = 0.0;
    for (var i = first; i < finish; i++) {
      energy += audio[i] * audio[i];
    }
    if (math.sqrt(energy / (finish - first)) > .006) break;
  }
  return Float32List.fromList(
    audio.sublist(
      math.max(0, first - (rate * .70).round()),
      math.min(audio.length, end + (rate * .90).round()),
    ),
  );
}

// RBJ shelf coefficients, with a gentle Q. Shared by every target platform.
void _shelf(
  Float32List data,
  int rate,
  double frequency,
  double db, {
  required bool high,
}) {
  final a = math.pow(10, db / 40).toDouble(),
      omega = 2 * math.pi * frequency / rate;
  final c = math.cos(omega), alpha = math.sin(omega) / (2 * math.sqrt(.5));
  final beta = 2 * math.sqrt(a) * alpha;
  final b0 = high
      ? a * ((a + 1) + (a - 1) * c + beta)
      : a * ((a + 1) - (a - 1) * c + beta);
  final b1 = high
      ? -2 * a * ((a - 1) + (a + 1) * c)
      : 2 * a * ((a - 1) - (a + 1) * c);
  final b2 = high
      ? a * ((a + 1) + (a - 1) * c - beta)
      : a * ((a + 1) - (a - 1) * c - beta);
  final a0 = high ? (a + 1) - (a - 1) * c + beta : (a + 1) + (a - 1) * c + beta;
  final a1 = high ? 2 * ((a - 1) - (a + 1) * c) : -2 * ((a - 1) + (a + 1) * c);
  final a2 = high ? (a + 1) - (a - 1) * c - beta : (a + 1) + (a - 1) * c - beta;
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  for (var i = 0; i < data.length; i++) {
    final x = data[i],
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    data[i] = y;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
  }
}
