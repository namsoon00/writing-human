import '../data/model.dart';
import '../data/original_removals.dart';
import 'photo_lines.dart';
import 'transcription_comparison.dart';

/// A stable, selected copy: later catalog edits cannot change a written passage.
RegisteredOriginal originalSnapshot(RegisteredOriginal original) =>
    RegisteredOriginal(
      original.id,
      original.text.substring(
        original.writingRange?.start ?? 0,
        original.writingRange?.end,
      ),
      citation: original.citation,
      photoId: original.photoId,
      photoRegion: originalPhotoPreviewRegion(original),
    );

RegisteredOriginal? passageOriginal(PagePassage passage) =>
    passage.original ??
    (passage.source.trim().isEmpty && passage.citation.trim().isEmpty
        ? null
        : RegisteredOriginal(
            legacyOriginalId(passage.source, passage.citation),
            passage.source,
            citation: passage.citation,
          ));

/// Interpret old page-wide references without changing stored records on read.
List<PagePassage> pageOriginals(
  WritingPage page,
  List<RegisteredOriginal> originals,
) {
  final passages = [...page.passages];
  if (!passages.any((item) => item.attached)) {
    final guide = originals
        .where((item) => item.id == page.guidedOriginalId)
        .firstOrNull;
    if (guide != null && !passages.any((p) => p.start == 0)) {
      final snapshot = originalSnapshot(guide);
      passages.insert(
        0,
        PagePassage(
          id: 'guide-${page.id}',
          start: 0,
          source: snapshot.text,
          citation: snapshot.citation,
          original: RegisteredOriginal.validList([snapshot]) ? snapshot : null,
          attached: true,
          referenceOnly: page.referenceOnly,
        ),
      );
    }
    final slip = page.originalSlip;
    if (slip != null &&
        !passages.any(
          (p) => p.original?.id == slip.id && p.source == slip.text,
        )) {
      passages.insert(
        0,
        PagePassage(
          id: 'slip-${page.id}',
          start: 0,
          source: slip.text,
          citation: slip.citation,
          original: slip,
          attached: true,
          referenceOnly: true,
        ),
      );
    }
  }
  final ordered = passages.indexed.toList()
    ..sort((a, b) {
      final start = a.$2.start.compareTo(b.$2.start);
      return start == 0 ? a.$1.compareTo(b.$1) : start;
    });
  return ordered.map((item) => item.$2).toList();
}

PagePassage? passageAt(List<PagePassage> passages, int offset) {
  PagePassage? active;
  for (final passage in passages) {
    if (passage.following && passage.start == offset) continue;
    if (passage.start <= offset &&
        (active == null || passage.start >= active.start)) {
      active = passage;
    }
  }
  return active;
}

int passageEnd(List<PagePassage> passages, PagePassage passage, int length) {
  final index = passages.indexWhere((p) => p.id == passage.id);
  return index < 0 || index == passages.length - 1
      ? length
      : passages[index + 1].start;
}

PagePassage? continuedOriginal(
  WritingPage page,
  List<RegisteredOriginal> originals,
  String id,
) {
  final links = pageOriginals(page, originals);
  final caret = page.extent.clamp(0, page.text.length);
  final active = passageAt(links, caret);
  final original = active == null ? null : passageOriginal(active);
  if (active == null || original == null) return null;
  final written = page.text.substring(active.start, caret);
  final consumed = active.referenceOnly || !original.canTranscribe
      ? 0
      : TranscriptionComparison(
          original,
          sourceOffset: active.sourceOffset,
        ).sourceOffsetFor(written);
  final offset = active.sourceOffset + consumed;
  if (!active.referenceOnly &&
      original.canTranscribe &&
      offset >= original.text.trimLeft().length) {
    return null;
  }
  return PagePassage(
    id: id,
    start: 0,
    source: original.text,
    citation: original.citation,
    original: RegisteredOriginal.validList([original]) ? original : null,
    attached: true,
    sourceOffset: offset,
    continued: true,
    referenceOnly: active.referenceOnly,
  );
}

/// An inserted source must not adopt text that was already after the caret.
PagePassage resumeAfterInsertion(
  WritingPage page,
  List<PagePassage> links,
  String id,
) {
  final caret = page.extent.clamp(0, page.text.length);
  final active = passageAt(links, caret);
  final original = active == null ? null : passageOriginal(active);
  if (active == null || original == null) {
    return PagePassage(id: id, start: caret, attached: true, following: true);
  }
  final consumed = active.referenceOnly || !original.canTranscribe
      ? 0
      : TranscriptionComparison(
          original,
          sourceOffset: active.sourceOffset,
        ).sourceOffsetFor(page.text.substring(active.start, caret));
  return PagePassage.fromJson({
    ...active.toJson(),
    'id': id,
    'start': caret,
    'attached': true,
    'following': true,
    'continued': true,
    'sourceOffset': (active.sourceOffset + consumed).clamp(
      0,
      active.source.length,
    ),
  });
}
