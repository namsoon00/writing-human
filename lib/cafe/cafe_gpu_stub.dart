import 'package:flutter/widgets.dart';
import 'cafe_renderer.dart';

Widget cafeSurface(CafeRenderer painter) =>
    CustomPaint(painter: painter, size: Size.infinite);
