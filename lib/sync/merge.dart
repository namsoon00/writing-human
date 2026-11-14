import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/model.dart';

bool sameData(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
String _hash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString().substring(0, 32);
T _field<T>(T? base, T local, T remote) =>
    sameData(local, base) ? remote : local;
Json? _recordContent(WritingRecord? record) => record?.toJson()
  ?..remove('sourceParagraph')
  ..remove('originals');

List<RegisteredOriginal> _mergeOriginals(
  List<RegisteredOriginal> base,
  List<RegisteredOriginal> local,
  List<RegisteredOriginal> remote,
) {
  final before = {for (final entry in base) entry.id: entry};
  final merged = {for (final entry in remote) entry.id: entry};
  for (final entry in local) {
    final incoming = merged[entry.id];
    if (incoming == null ||
        incoming.text != entry.text ||
        incoming.citation != entry.citation) {
      merged[entry.id] = entry;
      continue;
    }
    final left = entry.reflection;
    final right = incoming.reflection;
    final old = before[entry.id]?.reflection;
    final reflection = switch ((left, right)) {
      (null, _) => right,
      (_, null) => left,
      (final a?, _) when sameData(a.toJson(), old?.toJson()) => right,
      (_, final b?) when sameData(b.toJson(), old?.toJson()) => left,
      (final a?, final b?) when a.text == b.text => OriginalReflection(
        a.text,
        mark: a.mark ?? b.mark,
      ),
      (final a?, final b?) => _mergeReflections(a, b),
    };
    final range = switch ((entry.isFullPage, incoming.isFullPage)) {
      (false, _) => incoming.writingRange,
      (_, false) => entry.writingRange,
      _
          when sameData(
            entry.writingRange?.toJson(),
            before[entry.id]?.writingRange?.toJson(),
          ) =>
        incoming.writingRange,
      _ => entry.writingRange,
    };
    merged[entry.id] = entry.withDetails(
      reflection: reflection,
      photoId: incoming.photoId ?? entry.photoId,
      isFullPage: entry.isFullPage || incoming.isFullPage,
      writingRange: range,
      photoLines: incoming.photoLines.isEmpty
          ? entry.photoLines
          : incoming.photoLines,
    );
  }
  return merged.values.toList();
}

OriginalReflection _mergeReflections(
  OriginalReflection left,
  OriginalReflection right,
) {
  bool contains(String whole, String part) =>
      '\n\n$whole\n\n'.contains('\n\n$part\n\n');
  if (contains(left.text, right.text)) return left;
  if (contains(right.text, left.text)) return right;
  final (first, second) = left.text.compareTo(right.text) <= 0
      ? (left, right)
      : (right, left);
  return OriginalReflection(
    '${first.text}\n\n${second.text}',
    mark: first.mark ?? second.mark,
  );
}

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

List<PagePassage> _mergePassages(
  WritingPage? base,
  WritingPage local,
  WritingPage remote,
  String text,
) {
  Map<String, PagePassage> aligned(WritingPage page) => {
    for (final entry in PagePassage.afterEdit(page.text, text, page.passages))
      entry.id: entry,
  };
  final before = base == null ? <String, PagePassage>{} : aligned(base);
  final left = aligned(local);
  final right = aligned(remote);
  return [
    for (final id in {...left.keys, ...right.keys})
      if (left[id] == null)
        right[id]!
      else if (right[id] == null ||
          !sameData(left[id]!.toJson(), before[id]?.toJson()))
        left[id]!
      else
        right[id]!,
  ];
}

BookDetailChoice _mergeDetailChoice(
  BookDetailChoice base,
  BookDetailChoice local,
  BookDetailChoice remote,
) => BookDetailChoice(
  enabled: _field(base.enabled, local.enabled, remote.enabled),
  variant: _field(base.variant, local.variant, remote.variant),
  tone: _field(base.tone, local.tone, remote.tone),
  placement: _field(base.placement, local.placement, remote.placement),
);

Map<BookDetailKind, BookDetailChoice> _mergeDetailOverrides(
  Map<BookDetailKind, BookDetailChoice> base,
  Map<BookDetailKind, BookDetailChoice> local,
  Map<BookDetailKind, BookDetailChoice> remote,
  BookDetailsStyle defaults,
) {
  final result = <BookDetailKind, BookDetailChoice>{};
  for (final kind in {...base.keys, ...local.keys, ...remote.keys}) {
    final before = base[kind], left = local[kind], right = remote[kind];
    final choice = left == null || right == null
        ? (sameData(before?.toJson(), left?.toJson()) ? right : left)
        : _mergeDetailChoice(before ?? defaults.choice(kind), left, right);
    if (choice != null) result[kind] = choice;
  }
  return Map.unmodifiable(result);
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
        coverIndex: _field(old.coverIndex, b.coverIndex, r.coverIndex),
        paperIndex: _field(old.paperIndex, b.paperIndex, r.paperIndex),
        detailOverrides: _mergeDetailOverrides(
          old.detailOverrides,
          b.detailOverrides,
          r.detailOverrides,
          base.style.bookDetails,
        ),
        originals: _mergeOriginals(old.originals, b.originals, r.originals),
      );
    } else if (r == null ||
        old == null ||
        !sameData(b.toJson(), old.toJson())) {
      books[b.id] = r == null
          ? b
          : b.copy(
              detailOverrides: _mergeDetailOverrides(
                const {},
                b.detailOverrides,
                r.detailOverrides,
                base.style.bookDetails,
              ),
              originals: _mergeOriginals(
                old?.originals ?? const [],
                b.originals,
                r.originals,
              ),
            );
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
      _recordContent(r),
      sourcePages
          .map(
            (p) => {
              'id': p.id,
              'number': p.number,
              'text': p.text,
              'pencilMarks': p.pencilMarks.map((m) => m.toJson()).toList(),
              'writtenOn': p.writtenOn,
              if (p.guidedOriginalId != null)
                'guidedOriginalId': p.guidedOriginalId,
              if (p.passages.isNotEmpty)
                'passages': p.passages.map((entry) => entry.toJson()).toList(),
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
      sourceParagraph: r.sourceParagraph,
      originals: r.originals,
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
        passages: p.passages,
        guidedOriginalId: p.guidedOriginalId,
      );
    }
    copies++;
  }

  for (final l in local.records) {
    final r = records[l.id], b = baseRecords[l.id];
    if (r == null) {
      records[l.id] = l;
      continue;
    }
    final localChanged = !sameData(_recordContent(l), _recordContent(b));
    if (!sameData(_recordContent(l), _recordContent(r)) &&
        localChanged &&
        !sameData(_recordContent(r), _recordContent(b))) {
      keepRemote(r, remote.pages.where((p) => p.recordId == r.id).toList(), '');
    }
    final winner = localChanged ? l : r;
    records[l.id] = WritingRecord(
      id: winner.id,
      bookId: winner.bookId,
      title: winner.title,
      source: winner.source,
      originals: _mergeOriginals(
        b?.originals ?? const [],
        l.originals,
        r.originals,
      ),
      sourceParagraph: l.source == r.source
          ? _field(
              b?.source == winner.source ? b?.sourceParagraph : null,
              l.sourceParagraph,
              r.sourceParagraph,
            )
          : winner.sourceParagraph,
    );
  }

  for (final l in local.pages) {
    final r = pages[l.id], b = basePages[l.id];
    if (r == null) {
      pages[l.id] = l;
      continue;
    }
    final guide = _field(
      b?.guidedOriginalId,
      l.guidedOriginalId,
      r.guidedOriginalId,
    );
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
        passages: _mergePassages(b, l, r, l.text),
        guidedOriginalId: guide,
        clearGuide: guide == null,
      );
    } else if (b != null && l.text == b.text) {
      pages[l.id] = r.withDetails(
        writtenOn: b.writtenOn ?? l.writtenOn ?? r.writtenOn,
        pencilMarks: _mergeMarks(b, l, r, r.text),
        passages: _mergePassages(b, l, r, r.text),
        guidedOriginalId: guide,
        clearGuide: guide == null,
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
              passages: _mergePassages(b, l, r, l.text),
              guidedOriginalId: guide,
              clearGuide: guide == null,
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
        passages: p.passages,
        guidedOriginalId: p.guidedOriginalId,
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
        kind.name: _mergeDetailChoice(
          base.style.bookDetails.choice(kind),
          local.style.bookDetails.choice(kind),
          remote.style.bookDetails.choice(kind),
        ).toJson(),
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
    writingSound: _field(
      base.style.writingSound,
      local.style.writingSound,
      remote.style.writingSound,
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
  final merged = Library(
    books: books.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
    records: records.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
    pages: normalized,
    activePageId: active,
    writing:
        active != null && _field(base.writing, local.writing, remote.writing),
    style: style,
    sync: local.sync,
    lastBackupAt: local.lastBackupAt,
  );
  final positions = <String, String>{};
  final localPositions = merged.validBookPositions(local.bookPositions);
  final remotePositions = merged.validBookPositions(remote.bookPositions);
  for (final book in merged.books) {
    final previous = base.bookPositions[book.id];
    final here = localPositions[book.id];
    final there = remotePositions[book.id];
    final position = here == null || here == previous ? there ?? here : here;
    if (position != null) positions[book.id] = position;
  }
  final result = merged.copy(
    bookPositions: merged.validBookPositions(positions),
  );
  result.validate();
  return MergeResult(result, copies);
}
