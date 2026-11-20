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
    this.registeredAt,
    this.reflection,
    this.photoId,
    this.photoRegion,
    this.isFullPage = false,
    this.writingRange,
    this.photoLines = const [],
  });

  final String id, text, citation;

  bool get canTranscribe => text.trim().isNotEmpty;

  static Uri? webLink(String value) {
    final link = Uri.tryParse(value.trim());
    return link != null &&
            (link.scheme == 'https' || link.scheme == 'http') &&
            link.host.isNotEmpty &&
            !RegExp(r'\s').hasMatch(value.trim())
        ? link
        : null;
  }

  final int? registeredAt;
  final OriginalReflection? reflection;
  final String? photoId;
  final List<double>? photoRegion;
  final bool isFullPage;
  final PencilMark? writingRange;
  final List<OriginalPhotoLine> photoLines;

  RegisteredOriginal withDetails({
    required OriginalReflection? reflection,
    required PencilMark? writingRange,
    String? photoId,
    bool? isFullPage,
    List<double>? photoRegion,
    bool clearPhotoRegion = false,
    List<OriginalPhotoLine>? photoLines,
    int? registeredAt,
  }) => RegisteredOriginal(
    id,
    text,
    citation: citation,
    registeredAt: registeredAt ?? this.registeredAt,
    reflection: reflection,
    photoId: photoId ?? this.photoId,
    photoRegion: clearPhotoRegion ? null : photoRegion ?? this.photoRegion,
    isFullPage: isFullPage ?? this.isFullPage,
    writingRange: writingRange,
    photoLines: photoLines ?? this.photoLines,
  );

  RegisteredOriginal withReflection(OriginalReflection? value) =>
      withDetails(reflection: value, writingRange: writingRange);

  RegisteredOriginal edited(String text, String citation, {String? newId}) {
    final change = text == this.text
        ? null
        : _TextChange.between(this.text, text);
    final note = reflection;
    final mark = note?.mark;
    final previousRange = writingRange;
    final range = previousRange == null
        ? null
        : change?.updatedRange(previousRange) ?? previousRange;
    return RegisteredOriginal(
      newId ?? id,
      text,
      citation: citation,
      registeredAt: registeredAt,
      reflection: note == null || mark == null || change == null
          ? note
          : OriginalReflection(note.text, mark: change.unchangedRange(mark)),
      photoId: photoId,
      photoRegion: photoRegion,
      isFullPage: isFullPage,
      writingRange: range != null && validOriginalRange(text, range)
          ? range
          : null,
      photoLines: change == null
          ? photoLines
          : [
              for (final line in photoLines)
                if (change.unchangedRange(line.range) case final range?
                    when validOriginalRange(text, range))
                  OriginalPhotoLine(
                    range,
                    line.left,
                    line.top,
                    line.right,
                    line.bottom,
                  ),
            ],
    );
  }

  Json toJson() => {
    'id': id,
    'text': text,
    'citation': citation,
    if (registeredAt != null) 'registeredAt': registeredAt,
    if (reflection != null) 'reflection': reflection!.toJson(),
    if (photoId != null) 'photoId': photoId,
    if (photoRegion != null) 'photoRegion': photoRegion,
    if (isFullPage) 'isFullPage': true,
    if (writingRange != null) 'writingRange': writingRange!.toJson(),
    if (photoLines.isNotEmpty)
      'photoLines': photoLines.map((line) => line.toJson()).toList(),
  };

  factory RegisteredOriginal.fromJson(Json j) => RegisteredOriginal(
    j['id'] as String,
    j['text'] as String,
    citation: j['citation'] as String,
    registeredAt: j['registeredAt'] as int?,
    reflection: j['reflection'] == null
        ? null
        : OriginalReflection.fromJson(j['reflection'] as Json),
    photoId: j['photoId'] as String?,
    photoRegion: (j['photoRegion'] as List?)
        ?.map((value) => (value as num).toDouble())
        .toList(),
    isFullPage: j['isFullPage'] as bool? ?? false,
    writingRange: j['writingRange'] == null
        ? null
        : PencilMark.fromJson(j['writingRange'] as Json),
    photoLines: [
      for (final line in (j['photoLines'] as List?) ?? const [])
        OriginalPhotoLine.fromJson(line as List),
    ],
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
            (value.canTranscribe ||
                value.photoId != null ||
                webLink(value.citation) != null) &&
            value.text.length <= 50000 &&
            value.citation.length <= 500 &&
            (value.registeredAt == null || value.registeredAt! > 0) &&
            (value.photoId == null || _photoId.hasMatch(value.photoId!)) &&
            (value.photoRegion == null ||
                (value.photoId != null &&
                    validPhotoRegion(value.photoRegion!))) &&
            (value.writingRange == null ||
                (value.isFullPage &&
                    validOriginalRange(value.text, value.writingRange!))) &&
            (value.photoLines.isEmpty ||
                (value.isFullPage &&
                    value.photoId != null &&
                    OriginalPhotoLine.validList(
                      value.text,
                      value.photoLines,
                    ))) &&
            (value.reflection?.isValidFor(value.text) ?? true),
      );
}

bool validPhotoRegion(List<double> values) =>
    values.length == 4 &&
    values.every((value) => value >= 0 && value <= 1) &&
    values[0] < values[2] &&
    values[1] < values[3];

final _photoId = RegExp(r'^[a-f0-9]{64}$');

bool validOriginalPhotoId(String id) => _photoId.hasMatch(id);

bool validOriginalRange(String text, PencilMark range) {
  bool atCharacterBoundary(int index) =>
      index == text.length || (text.codeUnitAt(index) & 0xfc00) != 0xdc00;
  return range.start >= 0 &&
      range.end > range.start &&
      range.end <= text.length &&
      atCharacterBoundary(range.start) &&
      atCharacterBoundary(range.end) &&
      text.substring(range.start, range.end).trim().isNotEmpty;
}

/// Text offsets and the rectangle of a line in the oriented original photo.
class OriginalPhotoLine {
  const OriginalPhotoLine(
    this.range,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );

  static const coordinateScale = 10000;
  static const limit = 500;
  final PencilMark range;
  final int left, top, right, bottom;

  List<int> toJson() => [range.start, range.end, left, top, right, bottom];

  factory OriginalPhotoLine.fromJson(List<dynamic> value) {
    if (value.length != 6) throw const FormatException('Invalid photo line');
    return OriginalPhotoLine(
      PencilMark(value[0] as int, value[1] as int),
      value[2] as int,
      value[3] as int,
      value[4] as int,
      value[5] as int,
    );
  }

  static bool validList(String text, List<OriginalPhotoLine> lines) {
    if (lines.length > limit) return false;
    var end = 0;
    for (final line in lines) {
      if (line.range.start < end ||
          !validOriginalRange(text, line.range) ||
          line.left < 0 ||
          line.top < 0 ||
          line.right > coordinateScale ||
          line.bottom > coordinateScale ||
          line.left >= line.right ||
          line.top >= line.bottom) {
        return false;
      }
      end = line.range.end;
    }
    return true;
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.author = '',
    this.owner = '',
    this.coverIndex,
    this.paperIndex,
    this.detailOverrides = const {},
    this.originals = const [],
  });
  final String id, title, author, owner;
  final int? coverIndex, paperIndex;
  final Map<BookDetailKind, BookDetailChoice> detailOverrides;
  final List<RegisteredOriginal> originals;
  Book copy({
    String? title,
    String? owner,
    int? coverIndex,
    int? paperIndex,
    bool useDefaultPaper = false,
    Map<BookDetailKind, BookDetailChoice>? detailOverrides,
    List<RegisteredOriginal>? originals,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author,
    owner: owner ?? this.owner,
    coverIndex: coverIndex ?? this.coverIndex,
    paperIndex: useDefaultPaper ? null : paperIndex ?? this.paperIndex,
    detailOverrides: detailOverrides ?? this.detailOverrides,
    originals: originals ?? this.originals,
  );
  Json toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'owner': owner,
    if (coverIndex != null) 'coverIndex': coverIndex,
    if (paperIndex != null) 'paperIndex': paperIndex,
    if (detailOverrides.isNotEmpty)
      'detailOverrides': {
        for (final kind in BookDetailKind.values)
          if (detailOverrides.containsKey(kind))
            kind.name: detailOverrides[kind]!.toJson(),
      },
    if (originals.isNotEmpty)
      'originals': originals.map((o) => o.toJson()).toList(),
  };
  factory Book.fromJson(Json j) {
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
      coverIndex: cover,
      paperIndex: paper,
      detailOverrides: j.containsKey('detailOverrides')
          ? readDetailOverrides(j['detailOverrides'])
          : const {},
      originals: RegisteredOriginal.read(j['originals']),
    );
  }

  static Map<BookDetailKind, BookDetailChoice> readDetailOverrides(
    Object? value,
  ) {
    if (value is! Json) {
      throw const FormatException('책 꾸밈 설정을 확인할 수 없습니다.');
    }
    final details = BookDetailsStyle.fromJson(value);
    return Map.unmodifiable({
      for (final kind in BookDetailKind.values)
        if (value.containsKey(kind.name)) kind: details.choice(kind),
    });
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
    final change = _TextChange.between(before, after);
    final prefix = change.start, oldEnd = change.oldEnd, delta = change.delta;
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

class _TextChange {
  const _TextChange(this.start, this.oldEnd, this.newEnd);

  final int start, oldEnd, newEnd;
  int get delta => newEnd - oldEnd;

  factory _TextChange.between(String before, String after) {
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
    return _TextChange(prefix, oldEnd, newEnd);
  }

  PencilMark? unchangedRange(PencilMark range) {
    if (range.end <= start) return range;
    if (range.start >= oldEnd) {
      return PencilMark(range.start + delta, range.end + delta);
    }
    return null;
  }

  PencilMark updatedRange(PencilMark range) {
    final unchanged = unchangedRange(range);
    if (unchanged != null) return unchanged;
    return PencilMark(
      range.start <= start ? range.start : start,
      range.end >= oldEnd ? range.end + delta : newEnd,
    );
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
    this.guidedOriginalId,
    this.referenceOnly = false,
    this.originalCitations = const [],
    this.originalSlip,
  });
  final String id, recordId, text;
  final int number, base, extent;
  final double scroll;
  final String? writtenOn;
  final List<PencilMark> pencilMarks;
  final List<PagePassage> passages;
  final String? guidedOriginalId;
  final bool referenceOnly;
  final List<String> originalCitations;
  final RegisteredOriginal? originalSlip;

  WritingPage rememberOriginalCitation(String citation) =>
      citation.trim().isEmpty || originalCitations.contains(citation)
      ? this
      : withDetails(originalCitations: [...originalCitations, citation]);

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
    String? guidedOriginalId,
    bool clearGuide = false,
    bool? referenceOnly,
    List<String>? originalCitations,
    RegisteredOriginal? originalSlip,
    bool clearOriginalSlip = false,
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
    guidedOriginalId: clearGuide
        ? null
        : guidedOriginalId ?? this.guidedOriginalId,
    referenceOnly: !clearGuide && (referenceOnly ?? this.referenceOnly),
    originalCitations: originalCitations ?? this.originalCitations,
    originalSlip: clearOriginalSlip ? null : originalSlip ?? this.originalSlip,
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
    guidedOriginalId: guidedOriginalId,
    referenceOnly: referenceOnly,
    originalCitations: originalCitations,
    originalSlip: originalSlip,
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
    if (guidedOriginalId != null) 'guidedOriginalId': guidedOriginalId,
    if (referenceOnly) 'referenceOnly': true,
    if (originalCitations.isNotEmpty) 'originalCitations': originalCitations,
    if (originalSlip != null) 'originalSlip': originalSlip!.toJson(),
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
    guidedOriginalId: j['guidedOriginalId'] as String?,
    referenceOnly: j['referenceOnly'] as bool? ?? false,
    originalCitations: List<String>.from(j['originalCitations'] as List? ?? []),
    originalSlip: j['originalSlip'] == null
        ? null
        : RegisteredOriginal.fromJson(j['originalSlip'] as Json),
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
    this.fontSize = 20,
    this.useDevelopmentTypeface = true,
    this.guides = false,
    this.penMotion = true,
    this.writingSound = false,
    this.pageMotion = true,
    this.pageSound = false,
    this.favoriteBookIds = const [],
    this.bookDetails = const BookDetailsStyle(),
  });
  final int paperIndex, penIndex, fontIndex;
  final double fontSize;
  static const minFontSize = 16.0;
  static const maxFontSize = 30.0;
  final bool guides, penMotion, useDevelopmentTypeface;
  final bool pageMotion, pageSound, writingSound;
  final List<String> favoriteBookIds;
  final BookDetailsStyle bookDetails;
  WritingStyle copy({
    int? paperIndex,
    int? penIndex,
    int? fontIndex,
    double? fontSize,
    bool? useDevelopmentTypeface,
    bool? guides,
    bool? penMotion,
    bool? writingSound,
    bool? pageMotion,
    bool? pageSound,
    List<String>? favoriteBookIds,
    BookDetailsStyle? bookDetails,
  }) => WritingStyle(
    paperIndex: paperIndex ?? this.paperIndex,
    penIndex: penIndex ?? this.penIndex,
    fontIndex: fontIndex ?? this.fontIndex,
    fontSize: fontSize ?? this.fontSize,
    useDevelopmentTypeface:
        useDevelopmentTypeface ?? this.useDevelopmentTypeface,
    guides: guides ?? this.guides,
    penMotion: penMotion ?? this.penMotion,
    writingSound: writingSound ?? this.writingSound,
    pageMotion: pageMotion ?? this.pageMotion,
    pageSound: pageSound ?? this.pageSound,
    favoriteBookIds: favoriteBookIds ?? this.favoriteBookIds,
    bookDetails: bookDetails ?? this.bookDetails,
  );
  Json toJson() => {
    'paperIndex': paperIndex,
    'penIndex': penIndex,
    'fontIndex': fontIndex,
    'fontSize': fontSize,
    'useDevelopmentTypeface': useDevelopmentTypeface,
    'typefaceDefaultsVersion': 1,
    'guides': guides,
    'penMotion': penMotion,
    'writingSound': writingSound,
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
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 20,
      // Apply the requested app-wide font once to existing settings. Later
      // explicit alternatives carry version 1 and survive save/reopen/sync.
      useDevelopmentTypeface: defaultsVersion == 1
          ? savedTypeface ?? true
          : true,
      guides: j['guides'] as bool? ?? false,
      penMotion: j['penMotion'] as bool? ?? true,
      writingSound: j['writingSound'] as bool? ?? false,
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
        style.fontIndex > 2 ||
        !style.fontSize.isFinite ||
        style.fontSize < minFontSize ||
        style.fontSize > maxFontSize) {
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

typedef OriginalRemoval = ({String ownerId, String originalId, bool book});

List<OriginalRemoval> readOriginalRemovals(Object? values) => [
  for (final value in (values as List? ?? const []))
    if (value case [final bool book, final String owner, final String original])
      (ownerId: owner, originalId: original, book: book)
    else
      throw const FormatException('잘못된 원문 삭제 기록'),
];

List<List<Object>> originalRemovalsJson(List<OriginalRemoval> values) => [
  for (final item in values) [item.book, item.ownerId, item.originalId],
];

class Library {
  const Library({
    this.books = const [],
    this.records = const [],
    this.pages = const [],
    this.trashedPages = const [],
    this.purgedPageIds = const [],
    this.originalRemovals = const [],
    this.activePageId,
    this.bookPositions = const {},
    this.writing = false,
    this.style = const WritingStyle(),
    this.sync = const SyncMetadata(),
    this.lastBackupAt,
  });
  final List<Book> books;
  final List<WritingRecord> records;
  final List<WritingPage> pages, trashedPages;
  final List<String> purgedPageIds;
  final List<OriginalRemoval> originalRemovals;
  final String? activePageId;
  final Map<String, String> bookPositions;
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
  List<WritingPage> volumePages({String? bookId, String? recordId}) {
    final recordIds = bookId == null
        ? [?recordId]
        : records.where((record) => record.bookId == bookId).map((r) => r.id);
    final byRecord = {for (final id in recordIds) id: <WritingPage>[]};
    for (final page in pages) {
      byRecord[page.recordId]?.add(page);
    }
    return [
      for (final group in byRecord.values)
        ...(group..sort((a, b) => a.number.compareTo(b.number))),
    ];
  }

  Library copy({
    List<Book>? books,
    List<WritingRecord>? records,
    List<WritingPage>? pages,
    List<WritingPage>? trashedPages,
    List<String>? purgedPageIds,
    List<OriginalRemoval>? originalRemovals,
    String? activePageId,
    Map<String, String>? bookPositions,
    bool? writing,
    WritingStyle? style,
    SyncMetadata? sync,
    DateTime? lastBackupAt,
    bool clearActive = false,
  }) => Library(
    books: books ?? this.books,
    records: records ?? this.records,
    pages: pages ?? this.pages,
    trashedPages: trashedPages ?? this.trashedPages,
    purgedPageIds: purgedPageIds ?? this.purgedPageIds,
    originalRemovals: originalRemovals ?? this.originalRemovals,
    activePageId: clearActive ? null : activePageId ?? this.activePageId,
    bookPositions: bookPositions ?? this.bookPositions,
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
    if (trashedPages.isNotEmpty)
      'trashedPages': trashedPages.map((page) => page.toJson()).toList(),
    if (purgedPageIds.isNotEmpty) 'purgedPageIds': purgedPageIds,
    if (originalRemovals.isNotEmpty)
      'originalRemovals': originalRemovalsJson(originalRemovals),
    'activePageId': activePageId,
    if (bookPositions.isNotEmpty) 'bookPositions': bookPositions,
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
      trashedPages: (j['trashedPages'] as List? ?? [])
          .map((page) => WritingPage.fromJson(page as Json))
          .toList(),
      purgedPageIds: List<String>.from(j['purgedPageIds'] as List? ?? []),
      originalRemovals: readOriginalRemovals(j['originalRemovals']),
      activePageId: j['activePageId'] as String?,
      bookPositions: Map<String, String>.from(
        j['bookPositions'] as Json? ?? {},
      ),
      writing: j['writing'] as bool,
      style: WritingStyle.fromJson(j['style'] as Json? ?? {}),
      sync: SyncMetadata.fromJson(j['sync'] as Json? ?? {}),
      lastBackupAt: DateTime.tryParse(j['lastBackupAt'] as String? ?? ''),
    );
    result.validate();
    return result;
  }
  Map<String, String> validBookPositions(Map<String, String> positions) {
    if (positions.isEmpty) return const {};
    final bookIds = books.map((book) => book.id).toSet();
    final recordBooks = {
      for (final record in records) record.id: record.bookId,
    };
    final pageBooks = {
      for (final page in pages) page.id: recordBooks[page.recordId],
    };
    return {
      for (final entry in positions.entries)
        if (bookIds.contains(entry.key) && pageBooks[entry.value] == entry.key)
          entry.key: entry.value,
    };
  }

  Library rememberActiveBookPosition() {
    final bookId = activeRecord?.bookId;
    if (bookId == null || bookPositions[bookId] == activePageId) return this;
    return copy(bookPositions: {...bookPositions, bookId: activePageId!});
  }

  void validate() {
    style.bookDetails.validate();
    if (!style.fontSize.isFinite ||
        style.fontSize < WritingStyle.minFontSize ||
        style.fontSize > WritingStyle.maxFontSize) {
      throw const FormatException('알 수 없는 글자 크기입니다.');
    }
    for (final book in books) {
      for (final choice in book.detailOverrides.values) {
        choice.validate();
      }
    }
    final bookIds = books.map((b) => b.id).toSet();
    final recordIds = records.map((r) => r.id).toSet();
    final pageIds = pages.map((p) => p.id).toSet();
    final allPages = [...pages, ...trashedPages];
    final allIds = allPages.map((page) => page.id).toSet();
    final purged = purgedPageIds.toSet();
    final numbers = allPages.map((p) => '${p.recordId}::${p.number}').toSet();
    if (bookIds.length != books.length ||
        recordIds.length != records.length ||
        allIds.length != allPages.length ||
        numbers.length != allPages.length ||
        purged.length != purgedPageIds.length ||
        originalRemovals.toSet().length != originalRemovals.length ||
        originalRemovals.any(
          (entry) => entry.originalId.isEmpty || entry.originalId.length > 250,
        ) ||
        purged.any(
          (id) => id.isEmpty || id.length > 250 || allIds.contains(id),
        ) ||
        books.any(
          (b) =>
              b.owner.length > 80 || !RegisteredOriginal.validList(b.originals),
        ) ||
        records.any(
          (r) =>
              r.sourceParagraph < 0 ||
              !RegisteredOriginal.validList(r.originals) ||
              (r.bookId != null && !bookIds.contains(r.bookId)),
        ) ||
        allPages.any(
          (p) =>
              !recordIds.contains(p.recordId) ||
              p.number < 1 ||
              (p.originalSlip != null &&
                  !RegisteredOriginal.validList([p.originalSlip!])) ||
              p.originalCitations.any(
                (item) => item.trim().isEmpty || item.length > 500,
              ) ||
              (p.guidedOriginalId != null &&
                  (p.guidedOriginalId!.isEmpty ||
                      p.guidedOriginalId!.length > 250)) ||
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
        validBookPositions(bookPositions).length != bookPositions.length ||
        (activePageId != null && !pageIds.contains(activePageId)) ||
        (writing && activePage == null)) {
      throw const FormatException('저장된 기록의 구조를 확인할 수 없습니다.');
    }
  }
}
