import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../source/camera_page.dart';
import '../source/live_camera.dart';
import '../source/source_intake.dart';
import '../source/source_scan.dart';

typedef LiveSourceResult = ({
  SourcePhoto photo,
  SourceScan scan,
  CameraPage? page,
  int? paragraph,
});

Future<LiveSourceResult?> showLiveSourceCamera(
  BuildContext context,
  SourceIntake intake, {
  required bool pageMode,
}) => Navigator.of(context).push(
  MaterialPageRoute<LiveSourceResult>(
    fullscreenDialog: true,
    builder: (_) => _LiveSourceCamera(intake: intake, pageMode: pageMode),
  ),
);

class _LiveSourceCamera extends StatefulWidget {
  const _LiveSourceCamera({required this.intake, required this.pageMode});

  final SourceIntake intake;
  final bool pageMode;

  @override
  State<_LiveSourceCamera> createState() => _LiveSourceCameraState();
}

class _LiveSourceCameraState extends State<_LiveSourceCamera>
    with WidgetsBindingObserver {
  LiveCamera? _camera;
  LiveSourceResult? _candidate;
  bool _ready = false, _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final camera = LiveCamera();
    _camera = camera;
    try {
      await camera.open().timeout(const Duration(seconds: 20));
      if (!mounted || camera != _camera) return;
      setState(() => _ready = true);
      unawaited(_scanFrames(camera));
    } catch (_) {
      if (!mounted || camera != _camera) return;
      _stop();
      setState(() => _error = '카메라를 열지 못했어요. 권한을 확인하거나 사진을 골라 주세요.');
    }
  }

  Future<void> _scanFrames(LiveCamera camera) async {
    while (mounted && camera == _camera && !_confirming) {
      try {
        final frame = await camera.frame();
        if (frame != null && camera == _camera) {
          var page = widget.pageMode
              ? await compute(findCameraPage, frame.bytes)
              : null;
          final corrected = page == null
              ? null
              : await compute(rectifyCameraPage, (frame.bytes, page));
          if (!mounted || camera != _camera || _confirming) return;
          var scan = await widget.intake
              .scanLiveFrame(
                corrected == null ? frame : SourcePhoto('', corrected),
              )
              .timeout(const Duration(seconds: 25));
          if (page != null &&
              scan.paragraphs.isEmpty &&
              mounted &&
              camera == _camera &&
              !_confirming) {
            page = null;
            scan = await widget.intake
                .scanLiveFrame(frame)
                .timeout(const Duration(seconds: 25));
          }
          if (!mounted || camera != _camera || _confirming) return;
          setState(() {
            _candidate = (
              photo: frame,
              scan: scan,
              page: page,
              paragraph: null,
            );
            _error = null;
          });
        }
      } catch (_) {
        if (!mounted || camera != _camera || _confirming) return;
        widget.intake.cancelRecognition();
        setState(() {
          _candidate = null;
          _error = '글자를 읽지 못했어요. 책을 밝은 곳에서 다시 비춰 주세요.';
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  void _stop() {
    if (_camera case final camera?) {
      camera.close();
      _camera = null;
      widget.intake.endLiveRecognition();
    }
    _ready = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stop();
      setState(() {
        _candidate = null;
        _confirming = false;
        _error = '카메라가 멈췄어요.';
      });
    }
  }

  void _confirm(LiveSourceResult candidate, {int? paragraph}) {
    if (_confirming) return;
    _confirming = true;
    _stop();
    Navigator.pop(context, (
      photo: candidate.photo,
      scan: candidate.scan,
      page: candidate.page,
      paragraph: paragraph,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final scan = candidate?.scan;
    final canConfirm = scan?.paragraphs.isNotEmpty ?? false;
    return Scaffold(
      backgroundColor: const Color(0xff181614),
      appBar: AppBar(title: Text(widget.pageMode ? '한 페이지 · 카메라' : '문단 · 카메라')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = _ready
                      ? _camera!.aspectRatio
                      : (scan?.width ?? 4) / (scan?.height ?? 3);
                  final frame = applyBoxFit(
                    BoxFit.contain,
                    Size(ratio.isFinite ? ratio : 1, 1),
                    constraints.biggest,
                  ).destination;
                  return Center(
                    child: SizedBox.fromSize(
                      size: frame,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_ready) _camera!.preview(),
                          if (widget.pageMode)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _PageOutline(candidate?.page),
                              ),
                            ),
                          if (!widget.pageMode &&
                              candidate != null &&
                              scan != null &&
                              !_confirming)
                            for (final (index, paragraph)
                                in scan.paragraphs.indexed)
                              if (paragraph.bounds case final bounds?)
                                Positioned.fromRect(
                                  rect: Rect.fromLTRB(
                                    bounds.left * frame.width,
                                    bounds.top * frame.height,
                                    bounds.right * frame.width,
                                    bounds.bottom * frame.height,
                                  ),
                                  child: Semantics(
                                    button: true,
                                    label: paragraph.text,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _confirm(candidate, paragraph: index),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xfff4c478),
                                          ),
                                          color: const Color(0x30f4c478),
                                        ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Text(
                    _error ??
                        (!_ready
                            ? '카메라를 여는 중이에요.'
                            : widget.pageMode
                            ? '종이의 네 모서리가 화면 안에 들어오게 비추세요.'
                            : '읽힌 문단이 표시되면 원하는 문단을 누르세요.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (!_ready && _error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (!_ready && !_confirming && _error != null)
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        unawaited(_open());
                      },
                      child: const Text('카메라 다시 열기'),
                    ),
                  if (_ready &&
                      !_confirming &&
                      !widget.pageMode &&
                      canConfirm &&
                      scan!.paragraphs.every((p) => p.bounds == null))
                    FilledButton(
                      onPressed: () => _confirm(candidate!),
                      child: const Text('문단 고르기'),
                    ),
                  if (_ready && !_confirming && widget.pageMode)
                    FilledButton(
                      onPressed: canConfirm ? () => _confirm(candidate!) : null,
                      child: Text(
                        candidate?.page != null ? '이 페이지 사용' : '현재 화면 읽기',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageOutline extends CustomPainter {
  const _PageOutline(this.page);

  final CameraPage? page;

  @override
  void paint(Canvas canvas, Size size) {
    final corners =
        page?.corners ??
        const [
          Offset(.10, .08),
          Offset(.90, .08),
          Offset(.90, .92),
          Offset(.10, .92),
        ];
    final path = Path()
      ..addPolygon([
        for (final p in corners) Offset(p.dx * size.width, p.dy * size.height),
      ], true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = page == null
            ? const Color(0x99ffffff)
            : const Color(0xfff4c478),
    );
  }

  @override
  bool shouldRepaint(_PageOutline oldDelegate) => page != oldDelegate.page;
}
