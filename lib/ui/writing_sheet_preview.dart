import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/model.dart';
import 'book_details.dart';
import 'paper.dart';

class WritingSheetPreview extends StatelessWidget {
  const WritingSheetPreview({
    super.key,
    required this.excerpt,
    required this.style,
    required this.onOpen,
    this.notebook,
    this.date,
    this.heading,
  });

  final String excerpt;
  final WritingStyle style;
  final String? notebook, date, heading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = paperColors[style.paperIndex];
    final writtenOn = DateTime.tryParse(date ?? '');
    final metadata = [
      ?notebook,
      if (writtenOn != null) '${writtenOn.month}월 ${writtenOn.day}일',
    ].join(' · ');
    return CustomPaint(
      painter: _SheetEdge(color),
      child: ClipPath(
        clipper: const _SheetClipper(),
        child: Material(
          color: color,
          child: Ink(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/cotton-paper.jpg'),
                repeat: ImageRepeat.repeat,
                scale: 2,
                opacity: .36,
                colorFilter: ColorFilter.mode(color, BlendMode.modulate),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, .23)!,
                  color,
                  Color.lerp(color, brandInk, .065)!,
                ],
                stops: const [0, .48, 1],
              ),
            ),
            child: InkWell(
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 156),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (heading != null) ...[
                        Text(
                          heading!,
                          style: const TextStyle(fontSize: 12, color: burgundy),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: writingTextStyle(
                          style.fontIndex,
                          size: 18,
                          color: penColors[style.penIndex],
                          useDevelopmentTypeface: style.useDevelopmentTypeface,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (date != null && style.bookDetails.dateStamp.enabled)
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (notebook != null)
                                Text(notebook!, style: _metadataStyle),
                              DateStamp(
                                date: date!,
                                choice: style.bookDetails.dateStamp,
                              ),
                            ],
                          )
                        else
                          Text(metadata, style: _metadataStyle),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _metadataStyle = TextStyle(fontSize: 12, color: burgundy, height: 1.5);

Path _sheetShape(Size size) {
  if (size.width < 12 || size.height < 12) {
    return Path()..addRect(Offset.zero & size);
  }
  final width = size.width, height = size.height;
  final path = Path()..moveTo(6, 1.5);
  for (var x = 6.0; x < width - 5; x += 3) {
    path.lineTo(x, 1.5 + math.sin(x * .17) * .55 + math.sin(x * .73) * .26);
  }
  path.quadraticBezierTo(width - 1, 0, width - 1, 6);
  for (var y = 6.0; y < height - 5; y += 3) {
    path.lineTo(width - 1.4 + math.sin(y * .18) * .45, y);
  }
  path.quadraticBezierTo(width, height - 1, width - 6, height - 1);
  for (var x = width - 6; x > 5; x -= 3) {
    path.lineTo(
      x,
      height - 1.5 + math.sin(x * .16) * .57 + math.sin(x * .57) * .35,
    );
  }
  path.quadraticBezierTo(0, height, 1.4, height - 6);
  for (var y = height - 6; y > 5; y -= 3) {
    path.lineTo(1.4 + math.sin(y * .21) * .45, y);
  }
  return path
    ..quadraticBezierTo(0, 0, 6, 1.5)
    ..close();
}

class _SheetClipper extends CustomClipper<Path> {
  const _SheetClipper();

  @override
  Path getClip(Size size) => _sheetShape(size);

  @override
  bool shouldReclip(_SheetClipper oldClipper) => false;
}

class _SheetEdge extends CustomPainter {
  const _SheetEdge(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _sheetShape(size);
    canvas.drawShadow(
      shape.shift(const Offset(0, 3)),
      const Color(0x715d412e),
      5,
      false,
    );
    canvas.drawPath(
      shape.shift(const Offset(0, 3)),
      Paint()..color = Color.lerp(color, brandInk, .27)!,
    );
    canvas.drawPath(
      shape.shift(const Offset(0, 1.6)),
      Paint()..color = Color.lerp(color, brandInk, .15)!,
    );
  }

  @override
  bool shouldRepaint(_SheetEdge oldDelegate) => color != oldDelegate.color;
}
