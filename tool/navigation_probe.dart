// Browser verification fixture. No user store, account or production records.
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:writing_human/data/model.dart';
import 'package:writing_human/data/store.dart';
import 'package:writing_human/main.dart' as app;

@JS('navigationSnapshot')
external set snapshot(JSFunction value);

class ProbeStore implements LibraryStore {
  Library data = const Library(
    books: [
      Book(id: 'a', title: '쓰던 책'),
      Book(
        id: 'b',
        title: '살펴볼 책',
        originals: [
          RegisteredOriginal('source-b', '다른 책의 문장을 읽습니다.', citation: '둘째 원문'),
        ],
      ),
    ],
    records: [
      WritingRecord(id: 'ra', title: '쓰던 글', bookId: 'a'),
      WritingRecord(id: 'rb', title: '다른 글', bookId: 'b'),
    ],
    pages: [
      WritingPage(
        id: 'pa',
        recordId: 'ra',
        number: 1,
        text: '종이 위에',
        base: 2,
        extent: 2,
      ),
      WritingPage(
        id: 'pb',
        recordId: 'rb',
        number: 1,
        text: '다른 책의',
        base: 3,
        extent: 3,
      ),
    ],
    activePageId: 'pa',
    writing: true,
    style: WritingStyle(pageMotion: false),
  );
  @override
  Future<Library> load() async => data;
  @override
  Future<void> save(Library library) async {
    data = library;
  }

  @override
  Future<void> close() async {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final store = ProbeStore();
  snapshot = (() => store.data.encode().toJS).toJS;
  runApp(app.WritingHumanApp(store: store));
}
