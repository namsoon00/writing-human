import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'audio_session_policy.dart';

extension type _NavigatorSession(JSObject value) implements JSObject {
  external _BrowserSession? get audioSession;
}
extension type _BrowserSession(JSObject value) implements JSObject {
  external String get type;
  external set type(String value);
}

class BrowserAudioSessionAccess implements AudioSessionAccess {
  BrowserAudioSessionAccess(JSObject navigator)
    : _navigator = _NavigatorSession(navigator);
  final _NavigatorSession _navigator;
  @override
  String? get type => _navigator.audioSession?.type;
  @override
  set type(String value) {
    _navigator.audioSession?.type = value;
  }
}

final _leases = AudioSessionLeases(
  BrowserAudioSessionAccess(web.window.navigator),
);

class UserAudioSession {
  void activate() => _leases.acquire(this);
  void release() => _leases.release(this);
}
