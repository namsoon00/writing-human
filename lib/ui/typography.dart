import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Enlarge the app's small original type without discarding OS text scaling.
/// The system scaler receives the larger base size, retaining nonlinear rules.
class ReadingTextScaler extends TextScaler {
  const ReadingTextScaler(this.system);
  final TextScaler system;

  @override
  double scale(double fontSize) {
    assert(fontSize >= 0);
    return fontSize == 0 ? 0 : system.scale(math.max(14.0, fontSize * 1.2));
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is ReadingTextScaler && other.system == system;

  @override
  int get hashCode => system.hashCode;
}
