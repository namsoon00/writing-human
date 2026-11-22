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
                hintText: '표지에 함께 적을 이름',
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
      FilledButton(onPressed: submit, child: const Text('책 만들고 쓰기')),
    ],
  );
}

class BookTitleDialog extends StatefulWidget {
  const BookTitleDialog({
    super.key,
    required this.title,
    this.isWriting = false,
  });
  final String title;
  final bool isWriting;

  @override
  State<BookTitleDialog> createState() => _BookTitleDialogState();
}

class _BookTitleDialogState extends State<BookTitleDialog> {
  late final text = TextEditingController(text: widget.title);
  final form = GlobalKey<FormState>();

  void _submit() {
    if (text.value.isComposingRangeValid && !text.value.composing.isCollapsed) {
      return;
    }
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
    title: Text(widget.isWriting ? '글 이름 변경' : '책 이름 변경'),
    content: SizedBox(
      width: 320,
      child: Form(
        key: form,
        child: TextFormField(
          key: ValueKey(
            widget.isWriting ? 'writing-title-input' : 'book-title-input',
          ),
          controller: text,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: widget.isWriting ? '글 이름' : '책 이름',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? (widget.isWriting ? '글 이름을 입력해 주세요.' : '책 이름을 입력해 주세요.')
              : null,
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
