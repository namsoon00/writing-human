// Manual browser fixture for the real PaperSound controller/output.
// Build separately with -t tool/writing_audio_probe.dart; never the app entry.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:writing_human/ui/writing_sound.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sound = PaperSound.writing();
  web.window.setProperty(
    'pencilPulse'.toJS,
    (() => sound.play(() => true)).toJS,
  );
  web.window.setProperty(
    'pencilClose'.toJS,
    (() => sound.dispose().then((_) => true.toJS).toJS).toJS,
  );
  web.window.setProperty('pencilReady'.toJS, true.toJS);
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('PaperSound verification fixture')),
    ),
  );
}
