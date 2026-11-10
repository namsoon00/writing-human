import 'package:flutter/material.dart';
import 'paper.dart';

class NewBookDialog extends StatefulWidget {
  const NewBookDialog({super.key});
  @override
  State<NewBookDialog> createState() => NewBookDialogState();
}

class NewBookDialogState extends State<NewBookDialog> {
  final title = TextEditingController(), author = TextEditingController();
  final form = GlobalKey<FormState>();
  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, (title.text, author.text));
    }
  }

  @override
  void dispose() {
    title.dispose();
    author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text(
      '새 책 만들기',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 360,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '읽는 책도, 나만의 문장 모음도 좋아요.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: title,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '책 이름',
                hintText: '예: 오래 곁에 둘 문장들',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '책 이름을 입력해 주세요.' : null,
              onFieldSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: author,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '저자 · 선택',
                hintText: '비워 두어도 괜찮아요.',
              ),
              onFieldSubmitted: (_) => submit(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: submit,
        style: FilledButton.styleFrom(backgroundColor: green),
        child: const Text('책 만들고 쓰기'),
      ),
    ],
  );
}

class SourceDialog extends StatefulWidget {
  const SourceDialog({super.key, required this.source});
  final String source;
  @override
  State<SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<SourceDialog> {
  late final text = TextEditingController(text: widget.source);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('원문 메모', style: TextStyle(fontSize: 20)),
    content: SizedBox(
      width: 320,
      child: TextField(
        key: const ValueKey('source-text'),
        controller: text,
        minLines: 3,
        maxLines: 8,
        decoration: const InputDecoration(hintText: '옮겨 쓸 원문을 적어 주세요.'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, text.text),
        child: const Text('저장'),
      ),
    ],
  );
}
