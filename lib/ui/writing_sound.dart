import 'dart:async';
import 'dart:collection';

import 'paper_sound_effect.dart';
import 'writing_sound_native.dart'
    if (dart.library.js_interop) 'writing_sound_web.dart';

class PaperSound {
  PaperSound.writing({PaperSoundPlayback? playback})
    : _output = playback ?? PaperSoundOutput(PaperSoundEffect.pencilContacts);

  PaperSound.pageTurn()
    : _output = PaperSoundOutput(const [PaperSoundEffect.pageTurn]);

  final PaperSoundPlayback _output;
  PaperSoundRequest? _page;
  final _strokes = ListQueue<PaperSoundEffect>();
  bool Function()? _isStillWriting;
  Timer? _timer;
  bool _closed = false;

  void play(bool Function() isCurrent) {
    if (_closed || !isCurrent()) return;
    _page = PaperSoundRequest(PaperSoundEffect.pageTurn, isCurrent);
    if (_timer == null) _turnPage();
  }

  void _turnPage() {
    _timer = null;
    final request = _page;
    _page = null;
    if (request == null || !request.canPlay) return;
    _output.play(request);
    _timer = Timer(request.effect.interval, _turnPage);
  }

  void write(List<PaperSoundEffect> strokes, bool Function() isCurrent) {
    if (_closed || strokes.isEmpty || !isCurrent()) return;
    _isStillWriting = isCurrent;

    // Retain short sequences during IME composition. When input runs ahead
    // of the recorded hand, let the sounding contact finish and catch up with
    // the latest gesture, so old contacts do not build up behind the text.
    final queuedTime = _strokes.fold<Duration>(
      Duration.zero,
      (time, stroke) => time + stroke.interval + _penLift,
    );
    if (queuedTime > _maximumQueuedTime) _strokes.clear();
    _strokes.addAll(strokes);
    if (_timer == null) _writeStroke();
  }

  static const _penLift = Duration(milliseconds: 24);
  static const _maximumQueuedTime = Duration(milliseconds: 450);

  void _writeStroke() {
    _timer = null;
    final isCurrent = _isStillWriting;
    if (_strokes.isEmpty || isCurrent == null || !isCurrent()) {
      _strokes.clear();
      _isStillWriting = null;
      return;
    }
    final effect = _strokes.removeFirst();
    _output.play(PaperSoundRequest(effect, isCurrent));
    _timer = Timer(effect.interval + _penLift, _writeStroke);
  }

  void pause() {
    if (_closed) return;
    _timer?.cancel();
    _timer = null;
    _strokes.clear();
    _isStillWriting = null;
    _output.pause();
  }

  Future<void> dispose() {
    _closed = true;
    _timer?.cancel();
    _page = null;
    _strokes.clear();
    _isStillWriting = null;
    return _output.dispose();
  }
}
