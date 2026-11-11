import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/ui/editor.dart';

class PenHarness extends StatefulWidget {
  const PenHarness({super.key, this.initial = ''});
  final String initial;
  @override
  State<PenHarness> createState() => PenHarnessState();
}

class PenHarnessState extends State<PenHarness> {
  bool enabled = true, reduced = false, useDevelopmentTypeface = false;
  double scale = 1;
  int font = 1;
  String saved = '';
  void change(VoidCallback update) => setState(update);
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: PageEditor(
              page: WritingPage(
                id: 'p',
                recordId: 'r',
                number: 1,
                text: widget.initial,
              ),
              style: WritingStyle(
                fontIndex: font,
                penMotion: enabled,
                useDevelopmentTypeface: useDevelopmentTypeface,
              ),
              // Simulate the workspace/save-status rebuilds during typing.
              onChanged: (_, value, base, extent, scroll) =>
                  setState(() => saved = value),
            ),
          ),
        ),
      ),
    ),
  );
}

final _field = find.byKey(const ValueKey('page-text'));
final _pen = find.byKey(const ValueKey('writing-ink-point'));

Offset nibPoint(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(_pen);
  return box.localToGlobal(box.size.center(Offset.zero));
}

void expectNibAtCaret(WidgetTester tester) {
  expect(_pen, findsOneWidget);
  final editable = tester
      .state<EditableTextState>(find.byType(EditableText))
      .renderEditable;
  expect(editable.showCursor.value, isFalse);
  final value = tester.widget<TextField>(_field).controller!.value;
  final expected = editable.localToGlobal(
    editable.getLocalRectForCaret(value.selection.extent).bottomRight +
        const Offset(2, -3),
  );
  expect((nibPoint(tester) - expected).distance, lessThan(.2));
}

void main() {
  Future<GlobalKey<PenHarnessState>> open(
    WidgetTester tester, {
    String text = '',
  }) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final key = GlobalKey<PenHarnessState>();
    await tester.pumpWidget(PenHarness(key: key, initial: text));
    await tester.pumpAndSettle();
    await tester.tap(_field);
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets(
    'Ink settles after committed typing and follows wrapping and taps',
    (tester) async {
      final key = await open(tester);
      expectNibAtCaret(tester);
      final first = nibPoint(tester);
      await tester.enterText(_field, '한');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final duringStroke = nibPoint(tester);
      expect(find.byKey(const ValueKey('fresh-ink')), findsOneWidget);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      expect(duringStroke.dx, greaterThan(first.dx));
      expect(duringStroke, nibPoint(tester));
      expect(find.byKey(const ValueKey('fresh-ink')), findsNothing);
      expect(nibPoint(tester).dx, greaterThan(first.dx));
      final singleLine = nibPoint(tester);
      final prose = '한 문장\n${List.filled(4, '천천히 옮겨 쓰는 문장 ').join()}';
      await tester.enterText(_field, prose);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      expect(nibPoint(tester).dy, greaterThan(singleLine.dy));
      expect(key.currentState!.saved, prose);
      final controller = tester.widget<TextField>(_field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      expect(controller.text, prose);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
      expectNibAtCaret(tester);
      final beforeIdle = controller.value;
      await tester.pump(const Duration(milliseconds: 650));
      expectNibAtCaret(tester);
      expect(controller.value, beforeIdle);
      // The ink overlay must not intercept a tap in the writing field.
      await tester.tapAt(tester.getCenter(_field));
      await tester.pumpAndSettle();
      expect(controller.text, prose);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Korean composing and emoji are untouched; selection hides the pen',
    (tester) async {
      final key = await open(tester);
      final controller = tester.widget<TextField>(_field).controller!;
      const prefix = '문장 🌿 ';
      for (final syllable in ['ㅎ', '하', '한']) {
        final text = '$prefix$syllable';
        final value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: prefix.length, end: text.length),
        );
        tester.testTextInput.updateEditingValue(value);
        await tester.pumpAndSettle();
        key.currentState!.change(
          () => key.currentState!.useDevelopmentTypeface = true,
        );
        await tester.pumpAndSettle();
        expect(controller.value, value);
        expect(find.byKey(const ValueKey('fresh-ink')), findsNothing);
        expectNibAtCaret(tester);
        final point = nibPoint(tester);
        await tester.pump(const Duration(milliseconds: 60));
        expect(nibPoint(tester), point);
        expect(controller.value, value);
      }
      final committed = TextEditingValue(
        text: controller.text,
        selection: TextSelection.collapsed(offset: controller.text.length),
      );
      tester.testTextInput.updateEditingValue(committed);
      await tester.pumpAndSettle();
      expect(controller.value, committed);
      expectNibAtCaret(tester);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );
      await tester.pumpAndSettle();
      expect(_pen, findsNothing);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Viewport, scroll, font scale, motion switch and reduced motion stay safe',
    (tester) async {
      final key = await open(
        tester,
        text: List.filled(60, '오래 곁에 둘 문장').join('\n'),
      );
      final field = tester.widget<TextField>(_field);
      field.controller!.selection = const TextSelection.collapsed(offset: 1);
      await tester.pumpAndSettle();
      field.scrollController!.jumpTo(0);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      field.scrollController!.jumpTo(800);
      await tester.pumpAndSettle();
      expect(_pen, findsNothing);
      field.scrollController!.jumpTo(0);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      key.currentState!.change(() {
        key.currentState!.scale = 1.35;
        key.currentState!.font = 2;
      });
      tester.view.physicalSize = const Size(640, 390);
      await tester.pumpAndSettle();
      expectNibAtCaret(tester);
      final value = field.controller!.value;
      key.currentState!.change(() => key.currentState!.enabled = false);
      await tester.pumpAndSettle();
      expect(_pen, findsNothing);
      expect(
        tester.widget<TextField>(_field).controller,
        same(field.controller),
      );
      key.currentState!.change(() {
        key.currentState!.enabled = true;
        key.currentState!.reduced = true;
      });
      await tester.pumpAndSettle();
      expect(_pen, findsNothing);
      expect(field.controller!.value, value);
      expect(tester.takeException(), isNull);
    },
  );
}
