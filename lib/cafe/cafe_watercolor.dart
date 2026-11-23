import 'dart:math' as math;
import 'dart:ui' as ui;

/// Object-space watercolor materials. Drawn once at room entry, never as a
/// screen filter: moving the camera does not move the paint across a surface.
abstract final class CafeWatercolor {
  static const _size = 512.0;

  /// The caller retains and disposes [source]. Each returned timber owns a
  /// separate image handle, including on CanvasKit.
  static Future<ui.Image> timber(ui.Image source, {bool walnut = false}) =>
      _image((canvas) {
        final paint = ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..colorFilter = ui.ColorFilter.matrix([
            .85,
            .15,
            0,
            0,
            0,
            .05,
            .90,
            .05,
            0,
            6,
            .05,
            .15,
            .80,
            0,
            18,
            0,
            0,
            0,
            1,
            0,
          ]);
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            0,
            0,
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          const ui.Rect.fromLTWH(0, 0, _size, _size),
          paint,
        );
        if (walnut) {
          canvas.drawColor(const ui.Color(0xffbaae9e), ui.BlendMode.modulate);
        }
      });

  static Future<ui.Image> _image(void Function(ui.Canvas) draw) async {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(512, 512);
    } finally {
      picture.dispose();
    }
  }

  static void _grain(ui.Canvas canvas, math.Random random, {int count = 9000}) {
    final paint = ui.Paint();
    for (var i = 0; i < count; i++) {
      paint.color =
          (i.isEven ? const ui.Color(0xffffffff) : const ui.Color(0xff766044))
              .withValues(alpha: .018 + random.nextDouble() * .032);
      canvas.drawOval(
        ui.Rect.fromLTWH(
          random.nextDouble() * _size,
          random.nextDouble() * _size,
          .3 + random.nextDouble() * 1.1,
          .3 + random.nextDouble() * .6,
        ),
        paint,
      );
    }
  }

  static void _pool(
    ui.Canvas canvas,
    math.Random random,
    ui.Offset center,
    double rx,
    double ry,
    ui.Color color, {
    bool wrap = true,
  }) {
    final outline = List.generate(16, (i) {
      final a = i * math.pi / 8, r = .78 + random.nextDouble() * .22;
      return ui.Offset(math.cos(a) * rx * r, math.sin(a) * ry * r);
    });
    final path = ui.Path();
    final start = (outline.last + outline.first) / 2;
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < outline.length; i++) {
      final p = outline[i], next = outline[(i + 1) % outline.length];
      final middle = (p + next) / 2;
      path.quadraticBezierTo(p.dx, p.dy, middle.dx, middle.dy);
    }
    path.close();
    // Transparent nested washes and a fine pigment rim, without blur shaders.
    for (final dx in wrap ? [-_size, 0.0, _size] : [0.0]) {
      for (final dy in wrap ? [-_size, 0.0, _size] : [0.0]) {
        if (center.dx + dx + rx < 0 ||
            center.dx + dx - rx > _size ||
            center.dy + dy + ry < 0 ||
            center.dy + dy - ry > _size) {
          continue;
        }
        canvas.save();
        canvas.translate(center.dx + dx, center.dy + dy);
        final paint = ui.Paint()..color = color;
        canvas.drawPath(path, paint);
        canvas.scale(.89, .91);
        paint.color = color.withValues(alpha: color.a * .35);
        canvas.drawPath(path, paint);
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = color.withValues(alpha: color.a * .45);
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }
  }

  static void _washes(
    ui.Canvas canvas,
    math.Random random,
    ui.Color color, {
    int count = 65,
    double strength = .55,
  }) {
    for (var i = 0; i < count; i++) {
      _pool(
        canvas,
        random,
        ui.Offset(random.nextDouble() * _size, random.nextDouble() * _size),
        45 + random.nextDouble() * 140,
        14 + random.nextDouble() * 70,
        (i % 3 == 0 ? const ui.Color(0xffffffff) : color).withValues(
          alpha: (.025 + random.nextDouble() * .055) * strength,
        ),
      );
    }
  }

  static Future<ui.Image> wood({bool walnut = false}) => _image((canvas) {
    final random = math.Random(walnut ? 735 : 211);
    canvas.drawColor(
      walnut ? const ui.Color(0xff9c7658) : const ui.Color(0xffd7b585),
      ui.BlendMode.src,
    );
    _washes(canvas, random, const ui.Color(0xff765433));
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;
    for (var i = 0; i < 165; i++) {
      final x = random.nextDouble() * _size;
      final phase = random.nextDouble() * math.pi * 2;
      final sway = 1 + random.nextDouble() * 5;
      paint
        ..color =
            (i % 4 == 0
                    ? const ui.Color(0xffffefcc)
                    : const ui.Color(0xff684b32))
                .withValues(alpha: .035 + random.nextDouble() * .10)
        ..strokeWidth = .3 + random.nextDouble() * 2.0;
      for (final dx in [-_size, 0.0, _size]) {
        final path = ui.Path();
        for (var y = 0; y <= 512; y += 8) {
          final xx = x + dx + math.sin(y * math.pi * 2 / _size + phase) * sway;
          if (y == 0) {
            path.moveTo(xx, 0);
          } else {
            path.lineTo(xx, y.toDouble());
          }
        }
        canvas.drawPath(path, paint);
      }
    }
    _grain(canvas, random);
  });

  static Future<ui.Image> plaster() => _image((canvas) {
    canvas.drawColor(const ui.Color(0xfffff9ee), ui.BlendMode.src);
    final random = math.Random(884);
    _washes(
      canvas,
      random,
      const ui.Color(0xffac9983),
      count: 45,
      strength: .22,
    );
    _grain(canvas, random, count: 15000);
  });

  static Future<ui.Image> stone() => _image((canvas) {
    canvas.drawColor(const ui.Color(0xfff6ecda), ui.BlendMode.src);
    final random = math.Random(916);
    _washes(
      canvas,
      random,
      const ui.Color(0xffa99a88),
      count: 80,
      strength: .45,
    );
    _grain(canvas, random, count: 14000);
  });

  static Future<ui.Image> linen() => _image((canvas) {
    canvas.drawColor(const ui.Color(0xffe4cfaa), ui.BlendMode.src);
    final random = math.Random(362), paint = ui.Paint()..strokeWidth = .6;
    _washes(canvas, random, const ui.Color(0xffbda27d));
    for (var i = 0; i < 512; i += 3) {
      paint.color = const ui.Color(0xff9c8666).withValues(alpha: .12);
      canvas.drawLine(
        ui.Offset(i.toDouble(), 0),
        ui.Offset(i + .4, _size),
        paint,
      );
      paint.color = const ui.Color(0xfffff9df).withValues(alpha: .24);
      canvas.drawLine(
        ui.Offset(0, i.toDouble()),
        ui.Offset(_size, i + .4),
        paint,
      );
    }
    _grain(canvas, random);
  });

  static Future<ui.Image> gravel() => _image((canvas) {
    canvas.drawColor(const ui.Color(0xffddcfb6), ui.BlendMode.src);
    final random = math.Random(891);
    _washes(canvas, random, const ui.Color(0xffa59c83));
    for (var i = 0; i < 1300; i++) {
      _pool(
        canvas,
        random,
        ui.Offset(random.nextDouble() * _size, random.nextDouble() * _size),
        1.8 + random.nextDouble() * 3.2,
        1.1 + random.nextDouble() * 2.4,
        (i.isEven ? const ui.Color(0xff9c947d) : const ui.Color(0xffffffff))
            .withValues(alpha: .11 + random.nextDouble() * .10),
      );
    }
    _grain(canvas, random);
  });

  static Future<ui.Image> tree() => _image((canvas) {
    final random = math.Random(351),
        paint = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round;
    // One trunk with a few branching limbs, rather than a fan of equal stems.
    void branch(ui.Offset from, ui.Offset to, double width) {
      final path = ui.Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(
          (from.dx + to.dx) / 2 - 12,
          from.dy * .35 + to.dy * .65,
          to.dx,
          to.dy,
        );
      paint
        ..color = const ui.Color(0xff877351).withValues(alpha: .82)
        ..strokeWidth = width;
      canvas.drawPath(path, paint);
      paint
        ..color = const ui.Color(0xffd3bc88).withValues(alpha: .45)
        ..strokeWidth = width * .28;
      canvas.drawPath(path, paint);
    }

    branch(const ui.Offset(255, 510), const ui.Offset(248, 255), 10);
    for (final end in [
      const ui.Offset(115, 195),
      const ui.Offset(177, 90),
      const ui.Offset(287, 75),
      const ui.Offset(398, 175),
      const ui.Offset(427, 280),
    ]) {
      branch(const ui.Offset(250, 335), end, 4);
      branch(
        ui.Offset.lerp(const ui.Offset(250, 335), end, .65)!,
        end + const ui.Offset(-38, -34),
        1.8,
      );
    }
    for (var i = 0; i < 700; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final r = math.sqrt(random.nextDouble());
      final center = ui.Offset(
        256 + math.cos(a) * 218 * r,
        204 + math.sin(a) * 166 * r,
      );
      final color = [
        const ui.Color(0xff7e8b57),
        const ui.Color(0xffa5ad72),
        const ui.Color(0xffc1c687),
        const ui.Color(0xff617850),
      ][i % 4];
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(a + .5);
      final length = 5 + random.nextDouble() * 8;
      final leaf = ui.Path()
        ..moveTo(-length, 0)
        ..cubicTo(
          -length * .3,
          -length * .6,
          length * .5,
          -length * .48,
          length,
          0,
        )
        ..cubicTo(
          length * .1,
          length * .55,
          -length * .5,
          length * .4,
          -length,
          0,
        )
        ..close();
      final leafPaint = ui.Paint()
        ..color = color.withValues(alpha: .45 + random.nextDouble() * .35);
      canvas.drawPath(leaf, leafPaint);
      canvas.scale(.8, .7);
      leafPaint.color = color.withValues(alpha: .18);
      canvas.drawPath(leaf, leafPaint);
      canvas.restore();
    }
  });

  static Future<ui.Image> flowers() => _image((canvas) {
    final random = math.Random(791),
        paint = ui.Paint()
          ..strokeCap = ui.StrokeCap.round
          ..strokeWidth = 1.2;
    for (var i = 0; i < 85; i++) {
      final x = 12 + random.nextDouble() * 488;
      final y = 170 + random.nextDouble() * 310;
      paint.color = const ui.Color(0xff6e815b).withValues(alpha: .7);
      canvas.drawLine(
        ui.Offset(x - 5, math.min(508, y + 110)),
        ui.Offset(x + 12, y),
        paint,
      );
      _pool(
        canvas,
        random,
        ui.Offset(x, y + 45),
        10,
        23,
        const ui.Color(0xff8c9e6a).withValues(alpha: .38),
        wrap: false,
      );
      if (i % 3 == 0) continue;
      final pink = i % 6 == 0;
      for (var p = 0; p < 5; p++) {
        final a = p * math.pi * 2 / 5;
        _pool(
          canvas,
          random,
          ui.Offset(x + 12 + math.cos(a) * 5, y + math.sin(a) * 5),
          5.5,
          5.2,
          (pink ? const ui.Color(0xffcfb2b2) : const ui.Color(0xfffffae5))
              .withValues(alpha: .9),
          wrap: false,
        );
      }
      canvas.drawCircle(
        ui.Offset(x + 12, y),
        2.2,
        ui.Paint()..color = const ui.Color(0xffc4aa64).withValues(alpha: .85),
      );
    }
  });
}
