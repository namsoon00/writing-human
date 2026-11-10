import 'source_intake.dart';
import 'source_platform_native.dart'
    if (dart.library.js_interop) 'source_platform_web.dart'
    as platform;

SourceIntake createSourceIntake() => platform.createSourceIntake();
