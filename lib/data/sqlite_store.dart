import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'model.dart';
import 'store.dart';

Future<LibraryStore> openStore() async => SqliteLibraryStore.open(
  path.join(await getDatabasesPath(), 'writing-human-v1.db'),
);

class SqliteLibraryStore implements LibraryStore {
  SqliteLibraryStore._(this.db);
  final Database db;
  static Future<SqliteLibraryStore> open(
    String file, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE records ADD COLUMN source TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE app_state ADD COLUMN settings TEXT NOT NULL DEFAULT '{}'",
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              "ALTER TABLE app_state ADD COLUMN sync_state TEXT NOT NULL DEFAULT '{}'",
            );
          }
          if (oldVersion < 4) {
            await db.execute(
              "ALTER TABLE books ADD COLUMN owner TEXT NOT NULL DEFAULT ''",
            );
            await db.execute('ALTER TABLE pages ADD COLUMN written_on TEXT');
            await db.execute(
              "ALTER TABLE pages ADD COLUMN pencil_marks TEXT NOT NULL DEFAULT '[]'",
            );
          }
        },
        onCreate: (db, version) async {
          await db.execute(
            "CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL, owner TEXT NOT NULL DEFAULT '')",
          );
          await db.execute(
            "CREATE TABLE records (id TEXT PRIMARY KEY, book_id TEXT REFERENCES books(id), title TEXT NOT NULL, source TEXT NOT NULL DEFAULT '')",
          );
          await db.execute(
            "CREATE TABLE pages (id TEXT PRIMARY KEY, record_id TEXT NOT NULL REFERENCES records(id), number INTEGER NOT NULL, text TEXT NOT NULL, selection_base INTEGER NOT NULL, selection_extent INTEGER NOT NULL, scroll REAL NOT NULL, written_on TEXT, pencil_marks TEXT NOT NULL DEFAULT '[]', UNIQUE(record_id, number))",
          );
          await db.execute(
            "CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK(id = 1), active_page_id TEXT REFERENCES pages(id), writing INTEGER NOT NULL, settings TEXT NOT NULL DEFAULT '{}', sync_state TEXT NOT NULL DEFAULT '{}')",
          );
        },
      ),
    );
    return SqliteLibraryStore._(db);
  }

  @override
  Future<Library> load() async {
    final books = await db.query('books', orderBy: 'rowid');
    final records = await db.query('records', orderBy: 'rowid');
    final pages = await db.query('pages', orderBy: 'record_id, number');
    final state = (await db.query('app_state')).firstOrNull;
    final library = Library(
      books: books
          .map(
            (j) => Book(
              id: j['id'] as String,
              title: j['title'] as String,
              author: j['author'] as String,
              owner: j['owner'] as String,
            ),
          )
          .toList(),
      records: records
          .map(
            (j) => WritingRecord(
              id: j['id'] as String,
              bookId: j['book_id'] as String?,
              title: j['title'] as String,
              source: j['source'] as String,
            ),
          )
          .toList(),
      pages: pages
          .map(
            (j) => WritingPage(
              id: j['id'] as String,
              recordId: j['record_id'] as String,
              number: j['number'] as int,
              text: j['text'] as String,
              base: j['selection_base'] as int,
              extent: j['selection_extent'] as int,
              scroll: (j['scroll'] as num).toDouble(),
              writtenOn: j['written_on'] as String?,
              pencilMarks: (jsonDecode(j['pencil_marks'] as String) as List)
                  .map((m) => PencilMark.fromJson(m as Json))
                  .toList(),
            ),
          )
          .toList(),
      sync: SyncMetadata.fromJson(
        jsonDecode(state?['sync_state'] as String? ?? '{}') as Json,
      ),
      activePageId: state?['active_page_id'] as String?,
      writing: state?['writing'] == 1,
      style: WritingStyle.fromJson(
        jsonDecode(state?['settings'] as String? ?? '{}') as Json,
      ),
    );
    library.validate();
    return library;
  }

  @override
  Future<void> save(Library library) async {
    library.validate();
    await db.transaction((txn) async {
      // Update existing parents in place: REPLACE would delete referenced rows.
      Future<void> upsert(String table, Map<String, Object?> row) async {
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
      }

      for (final b in library.books) {
        await upsert('books', b.toJson());
      }
      for (final r in library.records) {
        await upsert('records', {
          'id': r.id,
          'book_id': r.bookId,
          'title': r.title,
          'source': r.source,
        });
      }
      // Free positive page numbers atomically before deterministic offline merges
      // reassign them. The transaction never exposes these temporary values.
      await txn.execute('UPDATE pages SET number = -number');
      for (final p in library.pages) {
        await upsert('pages', {
          'id': p.id,
          'record_id': p.recordId,
          'number': p.number,
          'text': p.text,
          'selection_base': p.base,
          'selection_extent': p.extent,
          'scroll': p.scroll,
          'written_on': p.writtenOn,
          'pencil_marks': jsonEncode(
            p.pencilMarks.map((m) => m.toJson()).toList(),
          ),
        });
      }
      await upsert('app_state', {
        'id': 1,
        'active_page_id': library.activePageId,
        'writing': library.writing ? 1 : 0,
        'settings': jsonEncode(library.style.toJson()),
        'sync_state': jsonEncode(library.sync.toJson()),
      });
    });
  }

  @override
  Future<void> close() => db.close();
}
