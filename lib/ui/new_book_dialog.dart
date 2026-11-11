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

class BookTitleDialog extends StatefulWidget {
  const BookTitleDialog({super.key, required this.title});
  final String title;

  @override
  State<BookTitleDialog> createState() => _BookTitleDialogState();
}

class _BookTitleDialogState extends State<BookTitleDialog> {
  late final text = TextEditingController(text: widget.title);
  final form = GlobalKey<FormState>();

  void _submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, text.text.trim());
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('책 이름 변경'),
    content: SizedBox(
      width: 320,
      child: Form(
        key: form,
        child: TextFormField(
          key: const ValueKey('book-title-input'),
          controller: text,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: '책 이름'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '책 이름을 입력해 주세요.' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _submit, child: const Text('저장')),
    ],
  );
}

class BookOwnerDialog extends StatefulWidget {
  const BookOwnerDialog({super.key, required this.owner});
  final String owner;
  @override
  State<BookOwnerDialog> createState() => _BookOwnerDialogState();
}

class _BookOwnerDialogState extends State<BookOwnerDialog> {
  late final text = TextEditingController(text: widget.owner);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text(
      '이 책의 주인',
      style: TextStyle(
        fontFamily: appFontFamily,
        fontFamilyFallback: appFontFallback,
        fontSize: 20,
      ),
    ),
    content: SizedBox(
      width: 320,
      child: TextField(
        key: const ValueKey('book-owner'),
        controller: text,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: '장서표에 남길 이름',
          hintText: '이름이나 필명을 적어 주세요.',
        ),
        onSubmitted: (_) => Navigator.pop(context, text.text),
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

class BookIndexDialog extends StatefulWidget {
  const BookIndexDialog({super.key, required this.label, required this.title});
  final String label, title;
  @override
  State<BookIndexDialog> createState() => _BookIndexDialogState();
}

class _BookIndexDialogState extends State<BookIndexDialog> {
  late final text = TextEditingController(text: widget.label);
  final form = GlobalKey<FormState>();

  void _submit() {
    if (form.currentState!.validate()) Navigator.pop(context, text.text);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('색인 이름', style: TextStyle(fontSize: 20)),
    content: SizedBox(
      width: 320,
      child: Form(
        key: form,
        child: TextFormField(
          key: const ValueKey('book-index-label'),
          controller: text,
          maxLength: 24,
          decoration: InputDecoration(
            labelText: '탭에 남길 이름',
            hintText: widget.title,
            helperText: '비워 두면 책 이름을 표시해요.',
            helperMaxLines: 2,
          ),
          validator: (value) =>
              (value?.trim().length ?? 0) > 80 ? '이름을 조금 줄여 주세요.' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(onPressed: _submit, child: const Text('저장')),
    ],
  );
}
