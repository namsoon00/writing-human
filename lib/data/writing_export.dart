import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'model.dart';

List<WritingPage> _orderedPages(Library library, String recordId) =>
    library.pages.where((p) => p.recordId == recordId).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

Uint8List exportRecordText(Library library, WritingRecord record) =>
    utf8.encode(
      [
        record.title,
        ..._orderedPages(library, record.id).map((p) => p.text),
      ].join('\n\n'),
    );

Future<Uint8List> exportBookPdf(Library library, Book book) async {
  final fonts = await (
    rootBundle.load('assets/fonts/WritingHumanDevelopment-Regular.ttf'),
    rootBundle.load('assets/fonts/NanumMyeongjo-Regular.ttf'),
    rootBundle.load('assets/fonts/NanumGothic-Regular.ttf'),
  ).wait;
  return compute(_buildPdf, (
    book: book,
    fonts: fonts,
    entries: [
      for (final record in library.records.where((r) => r.bookId == book.id))
        (
          title: record.title,
          pages: _orderedPages(library, record.id).map((p) => p.text).toList(),
        ),
    ],
  ));
}

Future<Uint8List> _buildPdf(
  ({
    Book book,
    (ByteData, ByteData, ByteData) fonts,
    List<({String title, List<String> pages})> entries,
  })
  input,
) async {
  final document = pw.Document(
    title: input.book.title,
    author: input.book.author,
  );
  final font = pw.Font.ttf(input.fonts.$1);
  final fallback = [pw.Font.ttf(input.fonts.$2), pw.Font.ttf(input.fonts.$3)];
  final ink = PdfColor.fromHex('#302c27');
  final muted = PdfColor.fromHex('#655d52');
  pw.TextStyle style(double size, PdfColor color) => pw.TextStyle(
    font: font,
    fontFallback: fallback,
    fontSize: size,
    color: color,
    lineSpacing: 6,
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(58, 62, 58, 50),
      maxPages: 10000,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('${context.pageNumber}', style: style(10, muted)),
      ),
      build: (_) => [
        pw.Text(
          input.book.title,
          style: style(28, ink),
          overflow: pw.TextOverflow.span,
        ),
        if (input.book.author.isNotEmpty)
          pw.Text(
            input.book.author,
            style: style(12, muted),
            overflow: pw.TextOverflow.span,
          ),
        pw.SizedBox(height: 26),
        for (final entry in input.entries) ...[
          pw.NewPage(freeSpace: 80),
          pw.Text(
            entry.title,
            style: style(15, muted),
            overflow: pw.TextOverflow.span,
          ),
          pw.SizedBox(height: 12),
          for (final body in entry.pages) ...[
            pw.Text(
              body,
              style: style(13, ink),
              overflow: pw.TextOverflow.span,
            ),
            pw.SizedBox(height: 14),
          ],
          pw.SizedBox(height: 12),
        ],
      ],
    ),
  );
  return document.save();
}
