import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image;

import 'source_intake.dart';

class LiveCamera {
  CameraController? _camera;
  CameraImage? _latest;
  bool _closed = false;

  Future<void> open() async {
    final devices = await availableCameras();
    if (_closed) return;
    final device = devices
        .where((camera) => camera.lensDirection == CameraLensDirection.back)
        .firstOrNull;
    if (device == null) throw StateError('No rear camera');
    final camera = CameraController(
      device,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _camera = camera;
    await camera.initialize();
    if (_closed) return;
    await camera.startImageStream((frame) => _latest = frame);
  }

  double get aspectRatio {
    final value = _camera!.value;
    return switch (value.deviceOrientation) {
      DeviceOrientation.portraitUp ||
      DeviceOrientation.portraitDown => 1 / value.aspectRatio,
      _ => value.aspectRatio,
    };
  }

  Widget preview() => CameraPreview(_camera!);

  Future<SourcePhoto?> frame() async {
    final frame = _latest, camera = _camera;
    if (_closed || frame == null || camera == null) return null;
    final orientation = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final angle = Platform.isIOS
        ? 0
        : (camera.description.sensorOrientation - orientation + 360) % 360;
    final bytes = await compute(_encodeFrame, (frame, angle));
    return SourcePhoto('', bytes);
  }

  void close() {
    _closed = true;
    _latest = null;
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      unawaited(camera.dispose().catchError((Object _) {}));
    }
  }
}

Uint8List _encodeFrame((CameraImage, int) input) {
  final (frame, angle) = input;
  final planes = frame.planes;
  final image.Image rgb;
  if (frame.format.group == ImageFormatGroup.bgra8888) {
    final p = planes.single;
    rgb = image.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: p.bytes.buffer,
      bytesOffset: p.bytes.offsetInBytes,
      rowStride: p.bytesPerRow,
      order: image.ChannelOrder.bgra,
    );
  } else {
    final [luma, u, v] = planes;
    rgb = image.Image(width: frame.width, height: frame.height);
    for (var y = 0; y < frame.height; y++) {
      final uRow = (y ~/ 2) * u.bytesPerRow;
      final vRow = (y ~/ 2) * v.bytesPerRow;
      for (var x = 0; x < frame.width; x++) {
        final luminance = luma.bytes[y * luma.bytesPerRow + x];
        final blue = u.bytes[uRow + (x ~/ 2) * (u.bytesPerPixel ?? 1)] - 128;
        final red = v.bytes[vRow + (x ~/ 2) * (v.bytesPerPixel ?? 1)] - 128;
        rgb.setPixelRgb(
          x,
          y,
          (luminance + 1.402 * red).round().clamp(0, 255),
          (luminance - .344 * blue - .714 * red).round().clamp(0, 255),
          (luminance + 1.772 * blue).round().clamp(0, 255),
        );
      }
    }
  }
  return image.encodeJpg(
    angle == 0 ? rgb : image.copyRotate(rgb, angle: angle),
    quality: 92,
  );
}
