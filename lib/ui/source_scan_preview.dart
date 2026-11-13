import 'package:flutter/material.dart';

import '../source/source_scan.dart';
import 'paper.dart';

const scanPageBounds = Rect.fromLTWH(0, 0, 1, 1);

class SourceScanPreview extends StatelessWidget {
  const SourceScanPreview({
    super.key,
    required this.scan,
    this.selection = const [],
    this.focus,
    this.onTap,
    this.height,
  });

  final SourceScan scan;
  final List<Rect> selection;
  final Rect? focus;
  final ValueChanged<Offset>? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final width = scan.width, height = scan.height;
    if (width == null || height == null) {
      return Semantics(
        label: '인식한 책 사진',
        image: true,
        child: SizedBox(
          height: this.height ?? 116,
          width: double.infinity,
          child: Image.memory(
            scan.photo,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    final viewport = focus == null
        ? scanPageBounds
        : focus!.inflate(.045).intersect(scanPageBounds);
    return Semantics(
      label: focus == null ? '인식한 책 사진' : '사진 속 해당 줄 확대',
      image: true,
      child: ColoredBox(
        color: paper,
        child: SizedBox(
          height: this.height ?? (focus == null ? 208 : 116),
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final area = constraints.biggest;
              final source = Size(
                width * viewport.width,
                height * viewport.height,
              );
              final size = applyBoxFit(
                BoxFit.contain,
                source,
                area,
              ).destination;
              final frame = Alignment.center.inscribe(size, Offset.zero & area);
              final sx = size.width / viewport.width;
              final sy = size.height / viewport.height;
              final origin =
                  frame.topLeft - Offset(viewport.left * sx, viewport.top * sy);
              Rect position(Rect bounds) => Rect.fromLTRB(
                origin.dx + bounds.left * sx,
                origin.dy + bounds.top * sy,
                origin.dx + bounds.right * sx,
                origin.dy + bounds.bottom * sy,
              );
              return GestureDetector(
                key: const ValueKey('source-scan-preview'),
                behavior: HitTestBehavior.opaque,
                onTapUp: onTap == null
                    ? null
                    : (details) {
                        final point = details.localPosition;
                        if (frame.contains(point)) {
                          onTap!(
                            Offset(
                              (point.dx - origin.dx) / sx,
                              (point.dy - origin.dy) / sy,
                            ),
                          );
                        }
                      },
                child: ClipRect(
                  clipper: _ScanFrame(frame),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: position(scanPageBounds),
                        child: Image.memory(
                          scan.photo,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                      for (final bounds in selection)
                        Positioned.fromRect(
                          rect: position(bounds),
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0x3bd39a43),
                                border: Border.all(
                                  color: const Color(0xff875620),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (focus case final line?)
                        Positioned.fromRect(
                          rect: position(line),
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: brandInk, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScanFrame extends CustomClipper<Rect> {
  const _ScanFrame(this.frame);
  final Rect frame;

  @override
  Rect getClip(Size size) => frame;

  @override
  bool shouldReclip(_ScanFrame oldClipper) => frame != oldClipper.frame;
}
