/// Shared page-level policy; no audio, timers or resources are created here.
abstract interface class AudioSessionAccess {
  String? get type;
  set type(String value);
}

class AudioSessionLeases {
  AudioSessionLeases(this.access);
  final AudioSessionAccess access;
  final _owners = <Object>{};
  String? _previous;

  bool acquire(Object owner) {
    try {
      final current = access.type;
      if (current == null || current == 'play-and-record') return false;
      if (_owners.isEmpty) _previous = current;
      if (current != 'playback') access.type = 'playback';
      if (access.type != 'playback') return false;
      _owners.add(owner);
      return true;
    } catch (_) {
      // Older/embedded browsers may expose an unsupported or read-only API.
      return false;
    }
  }

  void release(Object owner) {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return;
    final previous = _previous;
    _previous = null;
    try {
      // Do not overwrite another feature's later session choice.
      if (previous != null &&
          previous != 'playback' &&
          access.type == 'playback') {
        access.type = previous;
      }
    } catch (_) {
      // Releasing a session must not prevent audio resources being closed.
    }
  }
}
