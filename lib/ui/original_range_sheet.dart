import 'package:flutter/material.dart';

import '../data/model.dart';
import '../source/photo_lines.dart';
import '../source/source_scan.dart';
import 'source_scan_preview.dart';

typedef OriginalRangeChoice = ({PencilMark? range});

Future<OriginalRangeChoice?> chooseOriginalRange(
  BuildContext context,
  String text, {
  PencilMark? current,
  SourceScan? photo,
  List<OriginalPhotoLine> photoLines = const [],
}) => showModalBottomSheet<OriginalRangeChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _OriginalRangeSheet(
    text: text,
    current: current,
    photo: photo,
    photoLines: photoLines,
  ),
);

class _OriginalRangeSheet extends StatefulWidget {
  const _OriginalRangeSheet({
    required this.text,
    this.current,
    this.photo,
    required this.photoLines,
  });

  final String text;
  final PencilMark? current;
  final SourceScan? photo;
  final List<OriginalPhotoLine> photoLines;

  @override
  State<_OriginalRangeSheet> createState() => _OriginalRangeSheetState();
}

class _OriginalRangeSheetState extends State<_OriginalRangeSheet> {
  late final _text = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.text,
      selection: TextSelection(
        baseOffset: widget.current?.start ?? 0,
        extentOffset: widget.current?.end ?? widget.text.length,
      ),
    ),
  );
  late final _lines = _lineRanges(widget.text);
  late int _first = _lineAt(widget.current?.start ?? 0);
  late int _last = _lineAt((widget.current?.end ?? widget.text.length) - 1);

  late bool _showPhoto = widget.photo != null;
  OriginalPhotoLine? _startOnPhoto;

  void _pickLine(Offset point) {
    final hit = widget.photoLines
        .where((line) => line.bounds.inflate(.008).contains(point))
        .firstOrNull;
    if (hit == null) return;
    final anchor = _startOnPhoto;
    final first = anchor == null || hit.range.start < anchor.range.start
        ? hit
        : anchor;
    final last = anchor == null || hit.range.end > anchor.range.end
        ? hit
        : anchor;
    setState(() {
      _startOnPhoto = anchor == null ? hit : null;
      _first = _lineAt(first.range.start);
      _last = _lineAt(last.range.end - 1);
      _text.selection = TextSelection(
        baseOffset: first.range.start,
        extentOffset: last.range.end,
      );
    });
  }

  Widget _photoPreview() => LayoutBuilder(
    builder: (context, constraints) => InteractiveViewer(
      maxScale: 5,
      child: SourceScanPreview(
        scan: widget.photo!,
        height: constraints.maxHeight,
        selection: [
          for (final line in widget.photoLines)
            if (line.range.start < _text.selection.end &&
                line.range.end > _text.selection.start)
              line.bounds,
        ],
        onTap: widget.photoLines.isEmpty ? null : _pickLine,
      ),
    ),
  );

  static List<PencilMark> _lineRanges(String text) => [
    for (final match in RegExp(r'[^\n]+').allMatches(text))
      if (match.group(0)!.trim().isNotEmpty) PencilMark(match.start, match.end),
  ];

  int _lineAt(int offset) {
    final index = _lines.indexWhere((line) => offset < line.end);
    return index < 0 ? _lines.length - 1 : index;
  }

  void _selectLines() {
    _text.selection = TextSelection(
      baseOffset: _lines[_first].start,
      extentOffset: _lines[_last].end,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: FractionallySizedBox(
      heightFactor: .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('필사 범위', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.photo != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _showPhoto = !_showPhoto;
                    _startOnPhoto = null;
                  }),
                  child: Text(_showPhoto ? '글로 선택' : '사진으로 선택'),
                ),
              ),
            if (_showPhoto)
              Text(
                widget.photoLines.isEmpty
                    ? '사진을 참고하고 줄 번호로 범위를 고르세요.'
                    : _startOnPhoto == null
                    ? '사진에서 시작 줄을 누르세요.'
                    : '끝 줄을 누르세요. 지금 적용하면 한 줄만 선택됩니다.',
              )
            else
              const Text('시작 줄과 끝 줄을 고르거나, 글에서 원하는 부분을 선택하세요.'),
            if (_lines.length > 1 &&
                (!_showPhoto || widget.photoLines.isEmpty)) ...[
              RangeSlider(
                key: const ValueKey('original-line-range'),
                values: RangeValues(_first.toDouble(), _last.toDouble()),
                max: (_lines.length - 1).toDouble(),
                divisions: _lines.length - 1,
                semanticFormatterCallback: (value) =>
                    '${value.round() + 1}번째 줄',
                onChanged: (value) {
                  setState(() {
                    _first = value.start.round();
                    _last = value.end.round();
                  });
                  _selectLines();
                },
              ),
              Text('${_first + 1}–${_last + 1}줄'),
            ],
            if (_showPhoto)
              Expanded(child: _photoPreview())
            else
              Expanded(
                child: TextField(
                  key: const ValueKey('original-range-text'),
                  controller: _text,
                  readOnly: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ValueListenableBuilder(
              valueListenable: _text,
              builder: (context, value, _) {
                final selected = value.selection;
                final range = PencilMark(selected.start, selected.end);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showPhoto && validOriginalRange(widget.text, range))
                      Text(
                        widget.text.substring(range.start, range.end),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, (
                            range: null as PencilMark?,
                          )),
                          child: const Text('전체 페이지'),
                        ),
                        FilledButton(
                          onPressed: validOriginalRange(widget.text, range)
                              ? () => Navigator.pop(context, (
                                  range:
                                      range.start == 0 &&
                                          range.end == widget.text.length
                                      ? null
                                      : range,
                                ))
                              : null,
                          child: const Text('범위 적용'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
