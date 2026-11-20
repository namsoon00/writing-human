import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Keep small labels legible while retaining OS accessibility text scaling.
class ReadingTextScaler extends TextScaler {
  const ReadingTextScaler(this.system);
  final TextScaler system;

  @override
  double scale(double fontSize) {
    assert(fontSize >= 0);
    return fontSize == 0 ? 0 : system.scale(math.max(14.0, fontSize));
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is ReadingTextScaler && other.system == system;

  @override
  int get hashCode => system.hashCode;
}
