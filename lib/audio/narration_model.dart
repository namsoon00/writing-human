import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'narration_model_assets.dart';
import 'narration_model_platform.dart'
    if (dart.library.js_interop) 'narration_model_platform_web.dart';

/// Inference pipeline based on Supertone's MIT-licensed Supertonic 3 examples.
class NarrationModel {
  NarrationModel._(this._sessions, this._index, this._styles, this._config);

  final List<OrtSession> _sessions;
  final List<dynamic> _index;
  final Map<String, Map<String, dynamic>> _styles;
  final Map<String, dynamic> _config;
  final _random = math.Random();

  static Future<NarrationModel> open(
    Future<void> stopped,
    void Function() check,
    void Function(double) progress,
  ) async {
    await prepareRuntime();
    final loader = NarrationAssetLoader(stopped);
    final sessions = <OrtSession>[];
    final total = narrationAssets.fold(0, (sum, asset) => sum + asset.size);
    var loaded = 0;
    final json = <String, dynamic>{};
    try {
      for (final asset in narrationAssets) {
        check();
        if (asset.path.endsWith('.onnx')) {
          sessions.add(await loader.openSession(asset));
        } else {
          json[asset.path] = jsonDecode(await loader.readText(asset));
        }
        loaded += asset.size;
        progress(loaded / total);
      }
      check();
      return NarrationModel._(
        sessions,
        json['onnx/unicode_indexer.json'] as List<dynamic>,
        {
          for (final id in ['F3', 'M2'])
            id: json['voice_styles/$id.json'] as Map<String, dynamic>,
        },
        json['onnx/tts.json'] as Map<String, dynamic>,
      );
    } catch (_) {
      await Future.wait(sessions.map((session) => session.close()));
      rethrow;
    }
  }

  Future<void> close() =>
      Future.wait(_sessions.map((session) => session.close()));

  Future<Uint8List> synthesize(
    String text,
    String voice,
    void Function() check,
  ) async {
    final style = _styles[voice]!;
    final ids = _encode(text);
    final rate = _config['ae']['sample_rate'] as int;
    final chunk =
        (_config['ae']['base_chunk_size'] as int) *
        (_config['ttl']['chunk_compress_factor'] as int);
    final channels =
        (_config['ttl']['latent_dim'] as int) *
        (_config['ttl']['chunk_compress_factor'] as int);
    const steps = 12;
    final tensors = <OrtValue>[];
    Future<OrtValue> keep(Future<OrtValue> value) async {
      final tensor = await value;
      tensors.add(tensor);
      check();
      return tensor;
    }

    try {
      final input = await keep(narrationIds(ids));
      final textMask = await keep(
        _float(List<double>.filled(ids.length, 1), [1, 1, ids.length]),
      );
      final durationStyle = await keep(_style(style['style_dp']));
      final voiceStyle = await keep(_style(style['style_ttl']));
      final predicted = await keep(
        _run(0, {
          'text_ids': input,
          'style_dp': durationStyle,
          'text_mask': textMask,
        }),
      );
      final seconds = ((await predicted.asFlattenedList()).single as num) / .96;
      if (!seconds.isFinite || seconds <= 0 || seconds > 90) {
        throw const FormatException('Invalid narration duration');
      }
      final samples = (seconds * rate).round();
      final frames = (samples / chunk).ceil();
      final embedding = await keep(
        _run(1, {
          'text_ids': input,
          'style_ttl': voiceStyle,
          'text_mask': textMask,
        }),
      );
      final latentMask = await keep(
        _float(List<double>.filled(frames, 1), [1, 1, frames]),
      );
      final totalStep = await keep(_float([steps.toDouble()], [1]));
      var latent = await keep(
        _float(List.generate(channels * frames, (_) => _noise()), [
          1,
          channels,
          frames,
        ]),
      );
      for (var step = 0; step < steps; step++) {
        // Let the browser dispatch a stop tap between inference steps.
        await Future<void>.delayed(Duration.zero);
        check();
        final current = await keep(_float([step.toDouble()], [1]));
        final next = await keep(
          _run(2, {
            'noisy_latent': latent,
            'text_emb': embedding,
            'style_ttl': voiceStyle,
            'text_mask': textMask,
            'latent_mask': latentMask,
            'current_step': current,
            'total_step': totalStep,
          }),
        );
        tensors.remove(latent);
        await latent.dispose();
        tensors.remove(current);
        await current.dispose();
        latent = next;
      }
      final output = await keep(_run(3, {'latent': latent}));
      return _wav(await output.asFlattenedList(), samples, rate);
    } finally {
      await Future.wait(tensors.map((tensor) => tensor.dispose()));
    }
  }

  Future<OrtValue> _run(int index, Map<String, OrtValue> inputs) async {
    final outputs = await _sessions[index].run(inputs);
    return outputs.values.single;
  }

  List<int> _encode(String text) {
    final cleaned = unicode
        .nfkd(text)
        .replaceAll(RegExp(r'[–‑—]'), '-')
        .replaceAll(RegExp(r'[“”]'), '"')
        .replaceAll(RegExp(r'[‘’´`]'), "'")
        .replaceAll(RegExp(r'[_\[\]|/#→←\\]'), ' ')
        .replaceAll(
          RegExp(r'[\u{1F000}-\u{1FAFF}\u2600-\u27BF♥☆♡©]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'</?[^<>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final end = RegExp(r'''[.!?;:,'")\]}…。」』】〉》]$''').hasMatch(cleaned)
        ? cleaned
        : '$cleaned.';
    return [
      for (final rune in '<ko>$end</ko>'.runes)
        if (rune < _index.length && (_index[rune] as int) >= 0)
          _index[rune] as int,
    ];
  }

  double _noise() =>
      math.sqrt(-2 * math.log(1 - _random.nextDouble())) *
      math.cos(2 * math.pi * _random.nextDouble());
}

Future<OrtValue> _float(List<double> data, List<int> shape) =>
    OrtValue.fromList(Float32List.fromList(data), shape);

Future<OrtValue> _style(Map<String, dynamic> style) => _float([
  for (final plane in style['data'] as List)
    for (final row in plane as List)
      for (final value in row as List) (value as num).toDouble(),
], List<int>.from(style['dims'] as List));

Uint8List _wav(List<dynamic> wave, int samples, int rate) {
  final length = math.min(samples, wave.length);
  final result = ByteData(44 + 2 * length);
  result
    ..setUint32(0, 0x52494646)
    ..setUint32(4, 36 + 2 * length, Endian.little)
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
    ..setUint32(40, 2 * length, Endian.little);
  for (var index = 0; index < length; index++) {
    final sample = (wave[index] as num).clamp(-1.0, 1.0);
    result.setInt16(44 + 2 * index, (sample * 32767).round(), Endian.little);
  }
  return result.buffer.asUint8List();
}
