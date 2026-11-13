import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'source_intake.dart';

class LiveCamera {
  LiveCamera() {
    _video
      ..autoplay = true
      ..muted = true
      ..playsInline = true
      ..style.objectFit = 'contain';
  }

  final _video = web.HTMLVideoElement();
  web.MediaStream? _stream;
  bool _closed = false;

  Future<void> open() async {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            video: web.MediaTrackConstraints(
              facingMode: 'environment'.toJS,
              width: web.ConstrainULongRange(ideal: 1920),
              height: web.ConstrainULongRange(ideal: 1080),
            ),
          ),
        )
        .toDart;
    if (_closed) {
      _stop(stream);
      return;
    }
    _stream = stream;
    _video.srcObject = stream;
    await _video.play().toDart;
  }

  double get aspectRatio => _video.videoWidth / _video.videoHeight;

  Widget preview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final host = element as web.HTMLElement;
      _video.style
        ..width = '100%'
        ..height = '100%';
      host.style.pointerEvents = 'none';
      host.append(_video);
    },
  );

  Future<SourcePhoto?> frame() async {
    final width = _video.videoWidth, height = _video.videoHeight;
    if (_closed || width == 0 || height == 0 || _video.readyState < 2) {
      return null;
    }
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    context.drawImage(_video, 0, 0);
    final result = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? value) => result.complete(value)).toJS,
      'image/jpeg',
      .92.toJS,
    );
    final blob = await result.future;
    if (blob == null || _closed) return null;
    final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
    return SourcePhoto('', bytes);
  }

  void close() {
    _closed = true;
    if (_stream case final stream?) _stop(stream);
    _stream = null;
    _video
      ..pause()
      ..srcObject = null
      ..remove();
  }

  void _stop(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }
}
