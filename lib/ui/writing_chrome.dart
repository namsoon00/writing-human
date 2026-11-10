import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'paper.dart';

/// Small, native controls over the same paper as the editor. Decorative
/// materials never replace editable text or accessible button labels.
class WritingHeader extends StatelessWidget {
  const WritingHeader({
    super.key,
    required this.onCollection,
    required this.onNewSheet,
    this.bookTitle,
    this.compact = false,
  });
  final VoidCallback onCollection, onNewSheet;
  final String? bookTitle;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        (compact ? 68 : 98) +
        (MediaQuery.textScalerOf(context).scale(20) - 20) * 1.3,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 88),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const InkMark(size: 22),
              const SizedBox(height: 3),
              const Text(
                '쓰는 인간',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: serif,
                  fontSize: 20,
                  color: brandInk,
                  height: 1.3,
                  letterSpacing: .4,
                ),
              ),
              if (bookTitle != null && !compact) ...[
                const SizedBox(height: 5),
                Text(
                  bookTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onCollection,
            style: TextButton.styleFrom(
              foregroundColor: brandInk,
              minimumSize: const Size(68, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('보관함', style: TextStyle(fontSize: 13)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onNewSheet,
            tooltip: '새 종이',
            color: brandInk,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(CupertinoIcons.plus, size: 25),
          ),
        ),
      ],
    ),
  );
}

class WritingFooter extends StatelessWidget {
  const WritingFooter({
    super.key,
    required this.status,
    required this.onTools,
    required this.onStatus,
    required this.onMore,
    required this.onDone,
    required this.focused,
    this.pageLabel,
    this.onPages,
    this.failed = false,
  });
  final String status;
  final VoidCallback onTools, onStatus, onMore, onDone;
  final VoidCallback? onPages;
  final String? pageLabel;
  final bool focused, failed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Tooltip(
            message: '쓰기 도구',
            child: TextButton(
              onPressed: onTools,
              style: TextButton.styleFrom(
                foregroundColor: brandInk,
                minimumSize: const Size(48, 48),
              ),
              child: Semantics(
                label: '쓰기 도구',
                excludeSemantics: true,
                child: const CustomPaint(
                  painter: _Underline(),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'Aa',
                      style: TextStyle(fontFamily: serif, fontSize: 21),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Tooltip(
            message: '저장 상태와 동기화',
            child: TextButton(
              onPressed: onStatus,
              child: Semantics(
                liveRegion: failed,
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: failed ? burgundy : muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (pageLabel != null)
          TextButton(
            onPressed: onPages,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(40, 48),
            ),
            child: Text(
              pageLabel!,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
        SizedBox(
          width: 64,
          child: focused
              ? TextButton(
                  onPressed: onDone,
                  child: const Text('완료', style: TextStyle(fontSize: 12)),
                )
              : IconButton(
                  tooltip: '더 보기',
                  onPressed: onMore,
                  color: brandInk,
                  icon: const Icon(CupertinoIcons.ellipsis, size: 23),
                ),
        ),
      ],
    ),
  );
}

class _Underline extends CustomPainter {
  const _Underline();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(-2, size.height - 1)
        ..quadraticBezierTo(
          size.width * .5,
          size.height - 5,
          size.width + 2,
          size.height - 3,
        ),
      Paint()
        ..color = brandInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Underline oldDelegate) => false;
}
