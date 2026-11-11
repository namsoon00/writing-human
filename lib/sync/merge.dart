import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/model.dart';

bool sameData(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
String _hash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString().substring(0, 32);
T _field<T>(T? base, T local, T remote) =>
    sameData(local, base) ? remote : local;

List<PencilMark> _mergeMarks(
  WritingPage? base,
  WritingPage local,
  WritingPage remote,
  String text,
) {
  final before = base == null
      ? <PencilMark>[]
      : PencilMark.afterEdit(base.text, text, base.pencilMarks);
  final left = PencilMark.afterEdit(local.text, text, local.pencilMarks);
  final right = PencilMark.afterEdit(remote.text, text, remote.pencilMarks);
  String key(PencilMark m) => '${m.start}:${m.end}';
  final all = {
    for (final m in [...before, ...left, ...right]) key(m): m,
  };
  return PencilMark.normalize(
    all.values.where(
      (m) => _field(
        before.any((v) => key(v) == key(m)),
        left.any((v) => key(v) == key(m)),
        right.any((v) => key(v) == key(m)),
      ),
    ),
  );
}

class MergeResult {
  const MergeResult(this.library, this.conflictCopies);
  final Library library;
  final int conflictCopies;
}

/// Append-only three-way reconciliation. Deletions are deliberately unsupported.
/// Conflicting prose is preserved as a separate, visible writing record.
MergeResult mergeLibraries(Library base, Library local, Library remote) {
  final books = <String, Book>{for (final b in remote.books) b.id: b};
  final baseBooks = {for (final b in base.books) b.id: b};
  for (final b in local.books) {
    final r = books[b.id], old = baseBooks[b.id];
    if (r != null && old != null) {
      books[b.id] = Book(
        id: b.id,
        title: _field(old.title, b.title, r.title),
        author: _field(old.author, b.author, r.author),
        owner: _field(old.owner, b.owner, r.owner),
        indexLabel: _field(old.indexLabel, b.indexLabel, r.indexLabel),
        coverIndex: _field(old.coverIndex, b.coverIndex, r.coverIndex),
        paperIndex: _field(old.paperIndex, b.paperIndex, r.paperIndex),
      );
    } else if (r == null ||
        old == null ||
        !sameData(b.toJson(), old.toJson())) {
      books[b.id] = b;
    }
  }
  final records = <String, WritingRecord>{
    for (final r in remote.records) r.id: r,
  };
  final baseRecords = {for (final r in base.records) r.id: r};
  final pages = <String, WritingPage>{for (final p in remote.pages) p.id: p};
  final basePages = {for (final p in base.pages) p.id: p};
  final localRecordIds = local.records.map((r) => r.id).toSet();
  var copies = 0;

  void keepRemote(
    WritingRecord r,
    List<WritingPage> sourcePages,
    String suffix,
  ) {
    final signature = _hash([
      r.toJson(),
      sourcePages
          .map(
            (p) => {
              'id': p.id,
              'number': p.number,
              'text': p.text,
              'pencilMarks': p.pencilMarks.map((m) => m.toJson()).toList(),
              'writtenOn': p.writtenOn,
            },
          )
          .toList(),
    ]);
    final id = 'conflict-$signature';
    if (records.containsKey(id) || localRecordIds.contains(id)) {
      return;
    }
    records[id] = WritingRecord(
      id: id,
      bookId: r.bookId,
      title: '${r.title} · 충돌 보관$suffix',
      source: r.source,
    );
    for (var i = 0; i < sourcePages.length; i++) {
      final p = sourcePages[i];
      final pageId = '$id-${i + 1}';
      pages[pageId] = WritingPage(
        id: pageId,
        recordId: id,
        number: i + 1,
        text: p.text,
        base: p.base,
        extent: p.extent,
        scroll: p.scroll,
        writtenOn: p.writtenOn,
        pencilMarks: p.pencilMarks,
      );
    }
    copies++;
  }

  for (final l in local.records) {
    final r = records[l.id], b = baseRecords[l.id];
    if (r != null &&
        !sameData(l.toJson(), r.toJson()) &&
        (b == null ||
            (!sameData(l.toJson(), b.toJson()) &&
                !sameData(r.toJson(), b.toJson())))) {
      keepRemote(r, remote.pages.where((p) => p.recordId == r.id).toList(), '');
    }
    if (r == null || b == null || !sameData(l.toJson(), b.toJson())) {
      records[l.id] = l;
    }
  }

  for (final l in local.pages) {
    final r = pages[l.id], b = basePages[l.id];
    if (r == null) {
      pages[l.id] = l;
      continue;
    }
    if (l.text == r.text) {
      final useRemotePosition =
          b != null &&
          l.base == b.base &&
          l.extent == b.extent &&
          l.scroll == b.scroll;
      // Annotation changes are independent of caret/scroll changes.
      pages[l.id] = (useRemotePosition ? r : l).withDetails(
        writtenOn: b?.writtenOn ?? l.writtenOn ?? r.writtenOn,
        pencilMarks: _mergeMarks(b, l, r, l.text),
      );
    } else if (b != null && l.text == b.text) {
      pages[l.id] = r.withDetails(
        writtenOn: b.writtenOn ?? l.writtenOn ?? r.writtenOn,
        pencilMarks: _mergeMarks(b, l, r, r.text),
      );
    } else {
      if (b == null || r.text != b.text) {
        final record = remote.records
            .where((record) => record.id == r.recordId)
            .first;
        keepRemote(record, [r], ' (${r.number}쪽)');
      }
      pages[l.id] = b != null && r.text == b.text
          ? l.withDetails(
              writtenOn: b.writtenOn ?? l.writtenOn ?? r.writtenOn,
              pencilMarks: _mergeMarks(b, l, r, l.text),
            )
          : l;
    }
  }

  // Both devices may independently append "page 2". Keep both IDs and bodies.
  final ordered = pages.values.toList()
    ..sort((a, b) {
      final record = a.recordId.compareTo(b.recordId);
      if (record != 0) {
        return record;
      }
      final number = a.number.compareTo(b.number);
      return number == 0 ? a.id.compareTo(b.id) : number;
    });
  final numbers = <String, int>{};
  final normalized = [
    for (final p in ordered)
      WritingPage(
        id: p.id,
        recordId: p.recordId,
        number: numbers.update(p.recordId, (n) => n + 1, ifAbsent: () => 1),
        text: p.text,
        base: p.base,
        extent: p.extent,
        scroll: p.scroll,
        writtenOn: p.writtenOn,
        pencilMarks: p.pencilMarks,
      ),
  ];
  final allFavorites = {
    ...base.style.favoriteBookIds,
    ...local.style.favoriteBookIds,
    ...remote.style.favoriteBookIds,
  }.toList()..sort();
  // Font selection is one choice. Keep its legacy fallback index and the
  // optional development flag together during simultaneous preference edits.
  final fontStyle =
      local.style.fontIndex != base.style.fontIndex ||
          local.style.useDevelopmentTypeface !=
              base.style.useDevelopmentTypeface
      ? local.style
      : remote.style;
  final style = WritingStyle(
    bookDetails: BookDetailsStyle.fromJson({
      for (final kind in BookDetailKind.values)
        kind.name: {
          'enabled': _field(
            base.style.bookDetails.choice(kind).enabled,
            local.style.bookDetails.choice(kind).enabled,
            remote.style.bookDetails.choice(kind).enabled,
          ),
          'variant': _field(
            base.style.bookDetails.choice(kind).variant,
            local.style.bookDetails.choice(kind).variant,
            remote.style.bookDetails.choice(kind).variant,
          ),
          'placement': _field(
            base.style.bookDetails.choice(kind).placement,
            local.style.bookDetails.choice(kind).placement,
            remote.style.bookDetails.choice(kind).placement,
          ),
          'tone': _field(
            base.style.bookDetails.choice(kind).tone,
            local.style.bookDetails.choice(kind).tone,
            remote.style.bookDetails.choice(kind).tone,
          ),
        },
    }),
    paperIndex: _field(
      base.style.paperIndex,
      local.style.paperIndex,
      remote.style.paperIndex,
    ),
    penIndex: _field(
      base.style.penIndex,
      local.style.penIndex,
      remote.style.penIndex,
    ),
    fontIndex: fontStyle.fontIndex,
    useDevelopmentTypeface: fontStyle.useDevelopmentTypeface,
    guides: _field(base.style.guides, local.style.guides, remote.style.guides),
    penMotion: _field(
      base.style.penMotion,
      local.style.penMotion,
      remote.style.penMotion,
    ),
    pageMotion: _field(
      base.style.pageMotion,
      local.style.pageMotion,
      remote.style.pageMotion,
    ),
    pageSound: _field(
      base.style.pageSound,
      local.style.pageSound,
      remote.style.pageSound,
    ),
    favoriteBookIds: allFavorites
        .where(
          (id) => _field(
            base.style.favoriteBookIds.contains(id),
            local.style.favoriteBookIds.contains(id),
            remote.style.favoriteBookIds.contains(id),
          ),
        )
        .toList(),
  );
  var active = _field(
    base.activePageId,
    local.activePageId,
    remote.activePageId,
  );
  if (!normalized.any((p) => p.id == active)) {
    active = normalized.firstOrNull?.id;
  }
  final result = Library(
    books: books.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
    records: records.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
    pages: normalized,
    activePageId: active,
    writing:
        active != null && _field(base.writing, local.writing, remote.writing),
    style: style,
    sync: local.sync,
  );
  result.validate();
  return MergeResult(result, copies);
}
