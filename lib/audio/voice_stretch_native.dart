import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

@Native<
  Int32 Function(Pointer<Float>, Int32, Pointer<Float>, Int32, Int32, Double)
>(symbol: 'writing_voice_stretch')
external int _writingVoiceStretch(
  Pointer<Float> input,
  int inputCount,
  Pointer<Float> output,
  int outputCount,
  int sampleRate,
  double semitones,
);

class VoiceStretch {
  bool _closed = false;

  Future<Float32List> process(
    Float32List input,
    int rate,
    double speed,
    double pitch,
    void Function() check,
  ) async {
    if (_closed) throw StateError('Voice processor closed');
    check();
    final result = await Isolate.run(() => _process(input, rate, speed, pitch));
    check();
    if (_closed) throw StateError('Voice processor closed');
    return result;
  }

  static Float32List _process(
    Float32List data,
    int rate,
    double speed,
    double pitch,
  ) {
    final count = (data.length / speed).round();
    final input = calloc<Float>(data.length), output = calloc<Float>(count);
    try {
      input.asTypedList(data.length).setAll(0, data);
      if (_writingVoiceStretch(
            input,
            data.length,
            output,
            count,
            rate,
            pitch,
          ) !=
          1) {
        throw StateError('Voice processing failed');
      }
      return Float32List.fromList(output.asTypedList(count));
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  Future<void> close() async {
    _closed = true;
  }
}
