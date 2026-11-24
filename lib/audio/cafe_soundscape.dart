import 'cafe_sound_output.dart';
import 'cafe_sound_native.dart'
    if (dart.library.js_interop) 'cafe_sound_web.dart'
    as platform;
export 'cafe_sound_output.dart';

CafeSoundOutput createCafeSoundscape(void Function(Object) onError) =>
    platform.CafeSoundscape(onError);
