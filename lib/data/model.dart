import 'dart:convert';
import 'book_detail_style.dart';
export 'book_detail_style.dart';

typedef Json = Map<String, dynamic>;

class OriginalReflection {
  const OriginalReflection(this.text, {this.mark});

  final String text;
  final PencilMark? mark;

  Json toJson() => {'text': text, if (mark != null) 'mark': mark!.toJson()};

  factory OriginalReflection.fromJson(Json json) => OriginalReflection(
    json['text'] as String,
    mark: json['mark'] == null
        ? null
        : PencilMark.fromJson(json['mark'] as Json),
  );

  bool isValidFor(String original) {
    final range = mark;
    return text.trim().isNotEmpty &&
        (range == null ||
            (range.start >= 0 &&
                range.end > range.start &&
                range.end <= original.length));
  }
}

class RegisteredOriginal {
  const RegisteredOriginal(
    this.id,
    this.text, {
    this.citation = '',
    this.reflection,
  });

  final String id, text, citation;
  final OriginalReflection? reflection;

  RegisteredOriginal withReflection(OriginalReflection? value) =>
      RegisteredOriginal(id, text, citation: citation, reflection: value);

  Json toJson() => {
    'id': id,
    'text': text,
    'citation': citation,
    if (reflection != null) 'reflection': reflection!.toJson(),
  };

  factory RegisteredOriginal.fromJson(Json j) => RegisteredOriginal(
    j['id'] as String,
    j['text'] as String,
    citation: j['citation'] as String,
    reflection: j['reflection'] == null
        ? null
        : OriginalReflection.fromJson(j['reflection'] as Json),
  );

  static List<RegisteredOriginal> read(Object? value) => [
    for (final item in (value as List?) ?? const [])
      RegisteredOriginal.fromJson(item as Json),
  ];

  static bool validList(List<RegisteredOriginal> values) =>
      values.map((value) => value.id).toSet().length == values.length &&
      values.every(
        (value) =>
            value.id.isNotEmpty &&
            value.id.length <= 250 &&
            value.text.trim().isNotEmpty &&
            value.text.length <= 50000 &&
            value.citation.length <= 500 &&
            (value.reflection?.isValidFor(value.text) ?? true),
      );
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.author = '',
    this.owner = '',
    this.indexLabel = '',
    this.coverIndex,
    this.paperIndex,
    this.originals = const [],
  });
  final String id, title, author, owner, indexLabel;
  final int? coverIndex, paperIndex;
  final List<RegisteredOriginal> originals;
  Book copy({
    String? title,
    String? owner,
    String? indexLabel,
    int? coverIndex,
    int? paperIndex,
    bool useDefaultPaper = false,
    List<RegisteredOriginal>? originals,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author,
    owner: owner ?? this.owner,
    indexLabel: indexLabel ?? this.indexLabel,
    coverIndex: coverIndex ?? this.coverIndex,
    paperIndex: useDefaultPaper ? null : paperIndex ?? this.paperIndex,
    originals: originals ?? this.originals,
  );
  Json toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'owner': owner,
    'indexLabel': indexLabel,
    if (coverIndex != null) 'coverIndex': coverIndex,
    if (paperIndex != null) 'paperIndex': paperIndex,
    if (originals.isNotEmpty)
      'originals': originals.map((o) => o.toJson()).toList(),
  };
  factory Book.fromJson(Json j) {
    if (j.containsKey('indexLabel') && j['indexLabel'] is! String) {
      throw const FormatException('책의 색인 이름을 확인할 수 없습니다.');
    }
    final cover = j['coverIndex'] as int?;
    final paper = j['paperIndex'] as int?;
    if ((cover != null && (cover < 0 || cover > 2)) ||
        (paper != null && (paper < 0 || paper > 3))) {
      throw const FormatException('알 수 없는 책 재질 설정입니다.');
    }
    return Book(
      id: j['id'] as String,
      title: j['title'] as String,
      author: j['author'] as String,
      owner: j['owner'] as String? ?? '',
      indexLabel: j['indexLabel'] as String? ?? '',
      coverIndex: cover,
      paperIndex: paper,
      originals: RegisteredOriginal.read(j['originals']),
    );
  }
}

/// UTF-16 offsets, matching Flutter's selection. These never alter input values.
class PencilMark {
  const PencilMark(this.start, this.end);
  final int start, end;
  Json toJson() => {'start': start, 'end': end};
  factory PencilMark.fromJson(Json j) =>
      PencilMark(j['start'] as int, j['end'] as int);

  static List<PencilMark> normalize(Iterable<PencilMark> values) {
    final sorted = values.toList()..sort((a, b) => a.start.compareTo(b.start));
    final result = <PencilMark>[];
    for (final mark in sorted) {
      if (mark.end <= mark.start) continue;
      if (result.isNotEmpty && mark.start <= result.last.end) {
        final previous = result.removeLast();
        result.add(
          PencilMark(
            previous.start,
            mark.end > previous.end ? mark.end : previous.end,
          ),
        );
      } else {
        result.add(mark);
      }
    }
    return result;
  }

  /// Preserve unaffected characters; freshly replaced text is left unmarked.
  static List<PencilMark> afterEdit(
    String before,
    String after,
    List<PencilMark> marks,
  ) {
    if (before == after || marks.isEmpty) return marks;
    var prefix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldEnd = before.length, newEnd = after.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        before.codeUnitAt(oldEnd - 1) == after.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    // Keep emoji surrogate pairs together even when two emoji share a prefix.
    bool splitsPair(String value, int offset) =>
        offset > 0 &&
        offset < value.length &&
        value.codeUnitAt(offset - 1) >= 0xd800 &&
        value.codeUnitAt(offset - 1) <= 0xdbff &&
        value.codeUnitAt(offset) >= 0xdc00 &&
        value.codeUnitAt(offset) <= 0xdfff;
    if (splitsPair(before, prefix) || splitsPair(after, prefix)) prefix--;
    if (splitsPair(before, oldEnd) || splitsPair(after, newEnd)) {
      oldEnd++;
      newEnd++;
    }
    final delta = newEnd - oldEnd;
    return normalize([
      for (final mark in marks) ...[
        if (mark.start < prefix)
          PencilMark(mark.start, mark.end < prefix ? mark.end : prefix),
        if (mark.end > oldEnd)
          PencilMark(
            (mark.start > oldEnd ? mark.start : oldEnd) + delta,
            mark.end + delta,
          ),
      ],
    ]);
  }
}

class WritingRecord {
  const WritingRecord({
    required this.id,
    this.bookId,
    required this.title,
    this.source = '',
    this.sourceParagraph = 0,
    this.originals = const [],
  });
  final String id, title, source;
  final String? bookId;
  final int sourceParagraph;
  final List<RegisteredOriginal> originals;

  WritingRecord copy({
    String? bookId,
    String? source,
    int? sourceParagraph,
    List<RegisteredOriginal>? originals,
  }) => WritingRecord(
    id: id,
    bookId: bookId ?? this.bookId,
    title: title,
    source: source ?? this.source,
    sourceParagraph: sourceParagraph ?? this.sourceParagraph,
    originals: originals ?? this.originals,
  );
  Json toJson() => {
    'id': id,
    'bookId': bookId,
    'title': title,
    'source': source,
    if (sourceParagraph != 0) 'sourceParagraph': sourceParagraph,
    if (originals.isNotEmpty)
      'originals': originals.map((o) => o.toJson()).toList(),
  };
  factory WritingRecord.fromJson(Json j) => WritingRecord(
    id: j['id'] as String,
    bookId: j['bookId'] as String?,
    title: j['title'] as String,
    source: j['source'] as String? ?? '',
    sourceParagraph: j['sourceParagraph'] as int? ?? 0,
    originals: RegisteredOriginal.read(j['originals']),
  );
}

/// A transcription that starts at a UTF-16 offset on the physical page.
class PagePassage {
  const PagePassage({
    required this.id,
    required this.start,
    this.source = '',
    this.citation = '',
    this.paragraph = 0,
    this.sourceOffset = 0,
    this.continued = false,
  });

  final String id, source, citation;
  final int start, paragraph, sourceOffset;
  final bool continued;

  PagePassage copy({
    int? start,
    String? source,
    String? citation,
    int? paragraph,
    int? sourceOffset,
    bool? continued,
  }) => PagePassage(
    id: id,
    start: start ?? this.start,
    source: source ?? this.source,
    citation: citation ?? this.citation,
    paragraph: paragraph ?? this.paragraph,
    sourceOffset: sourceOffset ?? this.sourceOffset,
    continued: continued ?? this.continued,
  );

  Json toJson() => {
    'id': id,
    'start': start,
    'source': source,
    'citation': citation,
    'paragraph': paragraph,
    'sourceOffset': sourceOffset,
    if (continued) 'continued': true,
  };

  factory PagePassage.fromJson(Json j) => PagePassage(
    id: j['id'] as String,
    start: j['start'] as int,
    source: j['source'] as String,
    citation: j['citation'] as String,
    paragraph: j['paragraph'] as int,
    sourceOffset: j['sourceOffset'] as int,
    continued: j['continued'] as bool? ?? false,
  );

  static List<PagePassage> afterEdit(
    String before,
    String after,
    List<PagePassage> passages,
  ) {
    if (passages.isEmpty || before == after) return passages;
    var prefix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldEnd = before.length;
    var newEnd = after.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        before.codeUnitAt(oldEnd - 1) == after.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    return [
      for (final entry in passages)
        entry.start <= prefix
            ? entry
            : entry.copy(
                start: entry.start < oldEnd
                    ? prefix
                    : entry.start + newEnd - oldEnd,
              ),
    ];
  }
}

class WritingPage {
  const WritingPage({
    required this.id,
    required this.recordId,
    required this.number,
    this.text = '',
    this.base = 0,
    this.extent = 0,
    this.scroll = 0,
    this.writtenOn,
    this.pencilMarks = const [],
    this.passages = const [],
  });
  final String id, recordId, text;
  final int number, base, extent;
  final double scroll;
  final String? writtenOn;
  final List<PencilMark> pencilMarks;
  final List<PagePassage> passages;

  PagePassage? passageAt(int offset) {
    PagePassage? active;
    for (final entry in passages) {
      if (entry.start <= offset &&
          (active == null || entry.start >= active.start)) {
        active = entry;
      }
    }
    return active;
  }

  WritingPage withDetails({
    String? writtenOn,
    List<PencilMark>? pencilMarks,
    List<PagePassage>? passages,
  }) => WritingPage(
    id: id,
    recordId: recordId,
    number: number,
    text: text,
    base: base,
    extent: extent,
    scroll: scroll,
    writtenOn: writtenOn ?? this.writtenOn,
    pencilMarks: pencilMarks ?? this.pencilMarks,
    passages: passages ?? this.passages,
  );
  WritingPage edited({
    required String text,
    required int base,
    required int extent,
    required double scroll,
  }) => WritingPage(
    id: id,
    recordId: recordId,
    number: number,
    text: text,
    base: base,
    extent: extent,
    scroll: scroll,
    writtenOn: writtenOn,
    pencilMarks: PencilMark.afterEdit(this.text, text, pencilMarks),
    passages: PagePassage.afterEdit(this.text, text, passages),
  );
  Json toJson() => {
    'id': id,
    'recordId': recordId,
    'number': number,
    'text': text,
    'base': base,
    'extent': extent,
    'scroll': scroll,
    if (writtenOn != null) 'writtenOn': writtenOn,
    'pencilMarks': pencilMarks.map((m) => m.toJson()).toList(),
    if (passages.isNotEmpty)
      'passages': passages.map((entry) => entry.toJson()).toList(),
  };
  factory WritingPage.fromJson(Json j) => WritingPage(
    id: j['id'] as String,
    recordId: j['recordId'] as String,
    number: j['number'] as int,
    text: j['text'] as String,
    base: j['base'] as int,
    extent: j['extent'] as int,
    scroll: (j['scroll'] as num).toDouble(),
    writtenOn: j['writtenOn'] as String?,
    passages: (j['passages'] as List? ?? [])
        .map((entry) => PagePassage.fromJson(entry as Json))
        .toList(),
    pencilMarks: (j['pencilMarks'] as List? ?? [])
        .map((m) => PencilMark.fromJson(m as Json))
        .toList(),
  );
}

class WritingStyle {
  const WritingStyle({
    this.paperIndex = 0,
    this.penIndex = 0,
    this.fontIndex = 0,
    this.useDevelopmentTypeface = true,
    this.guides = false,
    this.penMotion = true,
    this.pageMotion = true,
    this.pageSound = false,
    this.favoriteBookIds = const [],
    this.bookDetails = const BookDetailsStyle(),
  });
  final int paperIndex, penIndex, fontIndex;
  final bool guides, penMotion, useDevelopmentTypeface;
  final bool pageMotion, pageSound;
  final List<String> favoriteBookIds;
  final BookDetailsStyle bookDetails;
  WritingStyle copy({
    int? paperIndex,
    int? penIndex,
    int? fontIndex,
    bool? useDevelopmentTypeface,
    bool? guides,
    bool? penMotion,
    bool? pageMotion,
    bool? pageSound,
    List<String>? favoriteBookIds,
    BookDetailsStyle? bookDetails,
  }) => WritingStyle(
    paperIndex: paperIndex ?? this.paperIndex,
    penIndex: penIndex ?? this.penIndex,
    fontIndex: fontIndex ?? this.fontIndex,
    useDevelopmentTypeface:
        useDevelopmentTypeface ?? this.useDevelopmentTypeface,
    guides: guides ?? this.guides,
    penMotion: penMotion ?? this.penMotion,
    pageMotion: pageMotion ?? this.pageMotion,
    pageSound: pageSound ?? this.pageSound,
    favoriteBookIds: favoriteBookIds ?? this.favoriteBookIds,
    bookDetails: bookDetails ?? this.bookDetails,
  );
  Json toJson() => {
    'paperIndex': paperIndex,
    'penIndex': penIndex,
    'fontIndex': fontIndex,
    'useDevelopmentTypeface': useDevelopmentTypeface,
    'typefaceDefaultsVersion': 1,
    'guides': guides,
    'penMotion': penMotion,
    'pageMotion': pageMotion,
    'pageSound': pageSound,
    'favoriteBookIds': favoriteBookIds,
    'bookDetails': bookDetails.toJson(),
  };
  factory WritingStyle.fromJson(Json j) {
    final defaultsVersion = j['typefaceDefaultsVersion'];
    if (defaultsVersion != null &&
        (defaultsVersion is! int ||
            defaultsVersion < 0 ||
            defaultsVersion > 1)) {
      throw const FormatException('알 수 없는 기본 글꼴 설정 버전입니다.');
    }
    final savedTypeface = j['useDevelopmentTypeface'] as bool?;
    if (j.containsKey('bookDetails') && j['bookDetails'] is! Json) {
      throw const FormatException('책의 디테일 설정을 확인할 수 없습니다.');
    }
    final style = WritingStyle(
      paperIndex: j['paperIndex'] as int? ?? 0,
      penIndex: j['penIndex'] as int? ?? 0,
      fontIndex: j['fontIndex'] as int? ?? 1,
      // Apply the requested app-wide font once to existing settings. Later
      // explicit alternatives carry version 1 and survive save/reopen/sync.
      useDevelopmentTypeface: defaultsVersion == 1
          ? savedTypeface ?? true
          : true,
      guides: j['guides'] as bool? ?? false,
      penMotion: j['penMotion'] as bool? ?? true,
      pageMotion: j['pageMotion'] as bool? ?? true,
      pageSound: j['pageSound'] as bool? ?? false,
      favoriteBookIds: List<String>.from(j['favoriteBookIds'] as List? ?? []),
      bookDetails: BookDetailsStyle.fromJson(j['bookDetails'] as Json? ?? {}),
    );
    if (style.paperIndex < 0 ||
        style.paperIndex > 3 ||
        style.penIndex < 0 ||
        style.penIndex > 2 ||
        style.fontIndex < 0 ||
        style.fontIndex > 2) {
      throw const FormatException('알 수 없는 쓰기 도구 설정입니다.');
    }
    return style;
  }
}

class SyncMetadata {
  const SyncMetadata({
    this.accountId,
    this.revision = 0,
    this.baseline,
    this.lastSyncedAt,
    this.legacyImported = false,
    this.positionDirty = true,
  });
  final String? accountId, lastSyncedAt;
  final int revision;
  final Json? baseline;
  final bool legacyImported, positionDirty;
  SyncMetadata copy({bool? positionDirty}) => SyncMetadata(
    accountId: accountId,
    revision: revision,
    baseline: baseline,
    lastSyncedAt: lastSyncedAt,
    legacyImported: legacyImported,
    positionDirty: positionDirty ?? this.positionDirty,
  );
  Json toJson() => {
    'accountId': accountId,
    'revision': revision,
    'baseline': baseline,
    'lastSyncedAt': lastSyncedAt,
    'legacyImported': legacyImported,
    'positionDirty': positionDirty,
  };
  factory SyncMetadata.fromJson(Json j) {
    final value = SyncMetadata(
      accountId: j['accountId'] as String?,
      revision: j['revision'] as int? ?? 0,
      baseline: j['baseline'] as Json?,
      lastSyncedAt: j['lastSyncedAt'] as String?,
      legacyImported: j['legacyImported'] as bool? ?? false,
      positionDirty: j['positionDirty'] as bool? ?? true,
    );
    if (value.revision < 0 || (value.baseline?.containsKey('sync') ?? false)) {
      throw const FormatException('동기화 정보를 확인할 수 없습니다.');
    }
    return value;
  }
}

class Library {
  const Library({
    this.books = const [],
    this.records = const [],
    this.pages = const [],
    this.activePageId,
    this.writing = false,
    this.style = const WritingStyle(),
    this.sync = const SyncMetadata(),
    this.lastBackupAt,
  });
  final List<Book> books;
  final List<WritingRecord> records;
  final List<WritingPage> pages;
  final String? activePageId;
  final bool writing;
  final WritingStyle style;
  final SyncMetadata sync;
  final DateTime? lastBackupAt;
  WritingPage? get activePage =>
      pages.where((p) => p.id == activePageId).firstOrNull;
  WritingRecord? get activeRecord =>
      records.where((r) => r.id == activePage?.recordId).firstOrNull;
  Book? get activeBook =>
      books.where((b) => b.id == activeRecord?.bookId).firstOrNull;
  Library copy({
    List<Book>? books,
    List<WritingRecord>? records,
    List<WritingPage>? pages,
    String? activePageId,
    bool? writing,
    WritingStyle? style,
    SyncMetadata? sync,
    DateTime? lastBackupAt,
    bool clearActive = false,
  }) => Library(
    books: books ?? this.books,
    records: records ?? this.records,
    pages: pages ?? this.pages,
    activePageId: clearActive ? null : activePageId ?? this.activePageId,
    writing: writing ?? this.writing,
    style: style ?? this.style,
    sync: sync ?? this.sync,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );
  Json toJson() => {
    'version': 1,
    'sync': sync.toJson(),
    if (lastBackupAt != null) 'lastBackupAt': lastBackupAt!.toIso8601String(),
    'style': style.toJson(),
    'books': books.map((b) => b.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'pages': pages.map((p) => p.toJson()).toList(),
    'activePageId': activePageId,
    'writing': writing,
  };
  Json toCloudJson() => toJson()
    ..remove('sync')
    ..remove('lastBackupAt');
  String encode() => jsonEncode(toJson());
  factory Library.decode(String raw) {
    final j = jsonDecode(raw) as Json;
    if (j['version'] != 1) {
      throw const FormatException('지원하지 않는 저장 버전입니다.');
    }
    final result = Library(
      books: (j['books'] as List).map((v) => Book.fromJson(v as Json)).toList(),
      records: (j['records'] as List)
          .map((v) => WritingRecord.fromJson(v as Json))
          .toList(),
      pages: (j['pages'] as List)
          .map((v) => WritingPage.fromJson(v as Json))
          .toList(),
      activePageId: j['activePageId'] as String?,
      writing: j['writing'] as bool,
      style: WritingStyle.fromJson(j['style'] as Json? ?? {}),
      sync: SyncMetadata.fromJson(j['sync'] as Json? ?? {}),
      lastBackupAt: DateTime.tryParse(j['lastBackupAt'] as String? ?? ''),
    );
    result.validate();
    return result;
  }
  void validate() {
    style.bookDetails.validate();
    final bookIds = books.map((b) => b.id).toSet();
    final recordIds = records.map((r) => r.id).toSet();
    final pageIds = pages.map((p) => p.id).toSet();
    final numbers = pages.map((p) => '${p.recordId}::${p.number}').toSet();
    if (bookIds.length != books.length ||
        recordIds.length != records.length ||
        pageIds.length != pages.length ||
        numbers.length != pages.length ||
        books.any(
          (b) =>
              b.owner.length > 80 ||
              b.indexLabel.length > 80 ||
              !RegisteredOriginal.validList(b.originals),
        ) ||
        records.any(
          (r) =>
              r.sourceParagraph < 0 ||
              !RegisteredOriginal.validList(r.originals) ||
              (r.bookId != null && !bookIds.contains(r.bookId)),
        ) ||
        pages.any(
          (p) =>
              !recordIds.contains(p.recordId) ||
              p.number < 1 ||
              !p.scroll.isFinite ||
              p.scroll < 0 ||
              (p.writtenOn != null &&
                  (DateTime.tryParse(p.writtenOn!) == null ||
                      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p.writtenOn!) ||
                      DateTime.parse(
                            p.writtenOn!,
                          ).toIso8601String().substring(0, 10) !=
                          p.writtenOn)) ||
              p.passages.map((entry) => entry.id).toSet().length !=
                  p.passages.length ||
              p.passages.any(
                (entry) =>
                    entry.id.isEmpty ||
                    entry.id.length > 250 ||
                    entry.start < 0 ||
                    entry.start > p.text.length ||
                    entry.citation.length > 500 ||
                    entry.paragraph < 0 ||
                    entry.sourceOffset < 0 ||
                    entry.sourceOffset > entry.source.length,
              ) ||
              p.pencilMarks.any(
                (m) => m.start < 0 || m.end <= m.start || m.end > p.text.length,
              ),
        ) ||
        (activePageId != null && !pageIds.contains(activePageId)) ||
        (writing && activePage == null)) {
      throw const FormatException('저장된 기록의 구조를 확인할 수 없습니다.');
    }
  }
}
