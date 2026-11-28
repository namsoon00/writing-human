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
          ..colorFilter = const ui.ColorFilter.matrix([
            .972,
            .108,
            0,
            0,
            -10,
            .0216,
            1.0368,
            .0216,
            0,
            -10,
            .0216,
            .0864,
            .972,
            0,
            -4,
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
      }, resolution: 768);

  static Future<ui.Image> lawn() => _image((canvas) {
    final random = math.Random(7421);
    canvas.drawColor(const ui.Color(0xffa1ac7b), ui.BlendMode.src);
    _washes(
      canvas,
      random,
      const ui.Color(0xff657e50),
      count: 90,
      strength: .16,
    );
    _washes(
      canvas,
      random,
      const ui.Color(0xffd7cc9c),
      count: 55,
      strength: .15,
    );
    final paint = ui.Paint()..strokeCap = ui.StrokeCap.round;
    // Several blade directions and lengths avoid an artificial mown stripe.
    for (var i = 0; i < 26000; i++) {
      final x = random.nextDouble() * _size, y = random.nextDouble() * _size;
      final angle = random.nextDouble() * math.pi * 2;
      final length = 1.2 + random.nextDouble() * 3.8;
      final dx = math.cos(angle) * length;
      final dy = math.sin(angle) * length;
      paint
        ..color = const [
          ui.Color(0xff617c47),
          ui.Color(0xffc4ce9b),
          ui.Color(0xff8a9f60),
          ui.Color(0xffd3ce9e),
        ][i % 4].withValues(alpha: .22 + random.nextDouble() * .33)
        ..strokeWidth = .45 + random.nextDouble() * .70;
      for (final ox in [-_size, 0.0, _size]) {
        for (final oy in [-_size, 0.0, _size]) {
          if (x + ox < -8 ||
              x + ox > _size + 8 ||
              y + oy < -8 ||
              y + oy > _size + 8) {
            continue;
          }
          final path = ui.Path()
            ..moveTo(x + ox, y + oy)
            ..quadraticBezierTo(
              x + ox + dx * .2,
              y + oy + dy * .6,
              x + ox + dx,
              y + oy + dy,
            );
          canvas.drawPath(path, paint);
        }
      }
    }
    _grain(canvas, random, count: 7000);
  }, resolution: 768);

  static Future<ui.Image> earth() => _image((canvas) {
    final random = math.Random(281128);
    canvas.drawColor(const ui.Color(0xffbd906e), ui.BlendMode.src);
    _washes(
      canvas,
      random,
      const ui.Color(0xff8d6048),
      count: 80,
      strength: .18,
    );
    _washes(
      canvas,
      random,
      const ui.Color(0xffe6c59c),
      count: 65,
      strength: .20,
    );
    final paint = ui.Paint()..isAntiAlias = true;
    for (var i = 0; i < 13000; i++) {
      final p = ui.Offset(
        random.nextDouble() * _size,
        random.nextDouble() * _size,
      );
      paint.color = const [
        ui.Color(0xff7c5843),
        ui.Color(0xffd7b48c),
        ui.Color(0xffa97758),
      ][i % 3].withValues(alpha: .14 + random.nextDouble() * .2);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: p,
          width: .3 + random.nextDouble() * 1.6,
          height: .3 + random.nextDouble() * .9,
        ),
        paint,
      );
    }
    // Tiny compacted grains rather than gravel or deep cracked desert clay.
    for (var i = 0; i < 220; i++) {
      final p = ui.Offset(
        3 + random.nextDouble() * 506,
        3 + random.nextDouble() * 506,
      );
      paint.color = const ui.Color(0x30734e3a);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: p + const ui.Offset(0, .6),
          width: 1.2,
          height: .8,
        ),
        paint,
      );
      paint.color = const ui.Color(0x70ddc3a4);
      canvas.drawOval(
        ui.Rect.fromCenter(center: p, width: 1.1, height: .65),
        paint,
      );
    }
  }, resolution: 768);

  static Future<ui.Image> fieldstone() => _image((canvas) {
    final random = math.Random(281130);
    // Neutral mineral detail lets each solid stone carry its own warm grey tint.
    canvas.drawColor(const ui.Color(0xffeeeae2), ui.BlendMode.src);
    _washes(
      canvas,
      random,
      const ui.Color(0xff8c887d),
      count: 90,
      strength: .55,
    );
    _washes(
      canvas,
      random,
      const ui.Color(0xffc1b69f),
      count: 55,
      strength: .14,
    );
    final paint = ui.Paint();
    for (var i = 0; i < 14000; i++) {
      paint.color = i.isEven
          ? const ui.Color(0x23857e6d)
          : const ui.Color(0x70ffffff);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(
            random.nextDouble() * _size,
            random.nextDouble() * _size,
          ),
          width: .35 + random.nextDouble() * 1.6,
          height: .30 + random.nextDouble() * .9,
        ),
        paint,
      );
    }
  });

  static Future<ui.Image> blossom() => _image((canvas) {
    final random = math.Random(135);
    final paint = ui.Paint()..strokeCap = ui.StrokeCap.round;
    for (var i = 0; i < 32; i++) {
      final x = 256 + (random.nextDouble() - .5) * 410;
      final y = 45 + random.nextDouble() * 360;
      paint
        ..color = const ui.Color(0xff82734f)
        ..strokeWidth = 2.2;
      canvas.drawLine(const ui.Offset(256, 505), ui.Offset(x, y), paint);
      for (var j = 0; j < 13; j++) {
        final px = x + (random.nextDouble() - .5) * 65;
        final py = y + (random.nextDouble() - .5) * 58;
        paint.color = j.isEven
            ? const ui.Color(0xffd7a7ad)
            : const ui.Color(0xfff3d1cd);
        for (var petal = 0; petal < 5; petal++) {
          final a = petal * math.pi * 2 / 5;
          canvas.drawOval(
            ui.Rect.fromCenter(
              center: ui.Offset(px + math.cos(a) * 3, py + math.sin(a) * 3),
              width: 6,
              height: 5,
            ),
            paint,
          );
        }
        paint.color = const ui.Color(0xffffe8b1);
        canvas.drawCircle(ui.Offset(px, py), 1.3, paint);
      }
    }
  });

  static Future<ui.Image> _image(
    void Function(ui.Canvas) draw, {
    int resolution = 512,
  }) async {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder)..scale(resolution / _size));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(resolution, resolution);
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
