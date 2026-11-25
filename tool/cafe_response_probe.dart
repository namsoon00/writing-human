// Development-only release benchmark of the real textured CafeScene.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:writing_human/cafe/cafe_renderer.dart';
import 'package:writing_human/cafe/cafe_view_controller.dart';
import 'package:writing_human/cafe/cafe_visit.dart';
import 'package:writing_human/ui/cafe_scene.dart';

void main() => runApp(const MaterialApp(home: Probe()));

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  CafeViewController controller = CafeViewController();
  bool cached = true, running = false, waiting = false;
  int pass = 0, frame = 0;
  final rows = <Map<String, Object>>[];
  String report = 'Ready';
  final cases = [null, CafeSeat.window, CafeSeat.shared];
  void start() {
    if (running) return;
    rows.clear();
    running = true;
    pass = 0;
    nextCase();
  }

  void nextCase() {
    final previous = controller;
    controller = CafeViewController(seat: cases[pass % 3]);
    cached = pass >= 3;
    frame = 0;
    waiting = false;
    setState(() => report = 'Running $pass / 6');
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void timing(CafeRenderTiming t) {
    if (t.courtyard || !running || waiting) return;
    waiting = true;
    rows.add({
      'cached': cached,
      'seat': cases[pass % 3]?.name ?? 'entrance',
      'frame': frame,
      'cacheHit': t.cacheHit,
      'cpuUs':
          t.projectMicros + t.orderMicros + t.submitMicros + t.linkedMicros,
      'projectUs': t.projectMicros,
      'orderUs': t.orderMicros,
      'submitUs': t.submitMicros,
      'linkedUs': t.linkedMicros,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(milliseconds: 25), () {
        if (!mounted) return;
        frame++;
        if (frame == 10) {
          pass++;
          if (pass == 6) {
            setState(() {
              running = false;
              report = jsonEncode(rows);
              debugPrint('CAFE_RESPONSE_RESULT:$report');
            });
          } else {
            nextCase();
          }
        } else {
          waiting = false;
          controller.look(.025, 0);
        }
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(onPressed: start, child: const Text('Compare')),
            TextButton(
              onPressed: () => setState(() => cached = !cached),
              child: Text(cached ? 'Cached' : 'Reference'),
            ),
            TextButton(
              onPressed: () {
                pass = 0;
                nextCase();
              },
              child: const Text('Entrance'),
            ),
          ],
        ),
        Expanded(
          child: CafeScene(
            key: ValueKey(controller),
            controller: controller,
            cacheGeometry: cached,
            hardwareRendering: false,
            onRenderTiming: timing,
            moment: DateTime(2026, 11, 25, 18),
          ),
        ),
        SizedBox(
          height: 90,
          child: SingleChildScrollView(
            child: Text(report, key: const ValueKey('report')),
          ),
        ),
      ],
    ),
  );
}
