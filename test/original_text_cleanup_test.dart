import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:writing_human/source/original_text_cleanup.dart';
import 'package:writing_human/ui/original_text_cleanup.dart';

void main() {
  test('따옴표와 기호를 키보드 문자로 바꾸고 문장과 줄바꿈을 보존한다', () {
    const original = '「봄」의 ‘빛’…\n\n첫째—둘째 · 셋째\n① ＡＢＣ１２３！ 2×3≤6';
    const cleaned = '"봄"의 \'빛\'...\n\n첫째-둘째 , 셋째\n1 ABC123! 2*3<=6';
    expect(cleanOriginalText(original), cleaned);
    expect(cleanOriginalText(cleaned), cleaned);
    expect(needsOriginalTextCleanup(cleaned), isFalse);
  });

  test('장식과 이모지는 단어를 합치지 않고 제거한다', () {
    expect(cleanOriginalText('하늘♥★바람'), '하늘 바람');
    expect(cleanOriginalText('달 🌙 빛'), '달 빛');
    expect(cleanOriginalText('문장★.'), '문장.');
    expect(cleanOriginalText('👩🏽‍💻🇰🇷'), isEmpty);
    expect(cleanOriginalText('1️⃣ 2️⃣'), '1 2');
    expect(cleanOriginalText('한\u200b글\u00ad\ufeff'), '한글');
    expect(cleanOriginalText('첫\u00a0줄\u2009끝'), '첫 줄 끝');
  });

  test('한글·한자·외국어와 시의 들여쓰기·빈 줄을 보존한다', () {
    const text = '  한글 漢字 café العربية\n\n    다음 행\n∞ ∑ ㎏';
    expect(needsOriginalTextCleanup(text), isFalse);
    expect(cleanOriginalText(text), text);
    expect(cleanOriginalText('“말”\n\n    들여쓴 행'), '"말"\n\n    들여쓴 행');
  });

  testWidgets('조합 중에는 정리하지 않으며 되돌리기는 전체 입력 상태를 복원한다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OriginalTextCleanup(controller: controller)),
      ),
    );
    const composing = TextEditingValue(
      text: '“하ㄴ”…',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 1, end: 4),
    );
    controller.value = composing;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '특수문자 정리'))
          .onPressed,
      isNull,
    );
    expect(controller.value, composing);
    final before = composing.copyWith(composing: TextRange.empty);
    controller.value = before;
    await tester.pumpAndSettle();
    final queuedClean = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '특수문자 정리'))
        .onPressed!;
    controller.value = composing;
    queuedClean();
    expect(controller.value, composing);
    controller.value = before;
    await tester.pumpAndSettle();
    await tester.tap(find.text('특수문자 정리'));
    await tester.pumpAndSettle();
    expect(controller.text, '"하ㄴ"...');
    await tester.tap(find.text('정리 되돌리기'));
    await tester.pumpAndSettle();
    expect(controller.value, before);

    await tester.tap(find.text('특수문자 정리'));
    await tester.pumpAndSettle();
    final queuedUndo = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '정리 되돌리기'))
        .onPressed!;
    controller.text += ' 새로 쓴 글';
    queuedUndo();
    await tester.pumpAndSettle();
    expect(find.text('정리 되돌리기'), findsNothing);
    expect(controller.text, endsWith('새로 쓴 글'));
  });
}
