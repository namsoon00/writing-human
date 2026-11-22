import 'model.dart';
import '../source/page_originals.dart';

/// Catalog citations start with the work title, followed by author and link.
/// A bare URL is provenance, not a writing title.
String originalWritingTitle(RegisteredOriginal original) {
  final first = original.citation.trim().split('\n').first.trim();
  final title = first.split(' · ').first.trim();
  final pageOnly = RegExp(
    r'^(?:[0-9]+(?:\s*[-–~]\s*[0-9]+)?\s*쪽|pp?\.\s*[0-9]+(?:\s*[-–~]\s*[0-9]+)?)$',
  ).hasMatch(title);
  return title.isEmpty || pageOnly || RegisteredOriginal.webLink(title) != null
      ? ''
      : title;
}

bool isAutomaticWritingTitle(String title) =>
    title.trim().isEmpty || RegExp(r'^필사(?: [0-9]+)?$').hasMatch(title.trim());

String writingTitle(WritingRecord record, List<WritingPage> pages) {
  if (record.titleIsManual || !isAutomaticWritingTitle(record.title)) {
    return record.title;
  }
  for (final page in pages) {
    for (final passage in pageOriginals(page, record.originals)) {
      final original = passageOriginal(passage);
      if (original == null) continue;
      final title = originalWritingTitle(original);
      if (title.isNotEmpty) return title;
    }
  }
  for (final page in pages) {
    final text = page.text.trim();
    if (text.isNotEmpty) return text.split('\n').first.trim();
  }
  return '제목 없는 글';
}
