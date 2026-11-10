import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {mkdtempSync, rmSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import worker, {validLibrary} from './index.mjs';

class SQLiteD1 {
  constructor(file) { this.db = new DatabaseSync(file); }
  prepare(sql) { return {bind: (...args) => ({first: async () => this.db.prepare(sql).get(...args) ?? null})}; }
  close() { this.db.close(); }
}
const origin = 'https://writing-human.test';
const empty = () => ({version: 1, books: [], records: [], pages: [], activePageId: null, writing: false, style: {paperIndex: 0, penIndex: 0, fontIndex: 1, guides: false, favoriteBookIds: []}});
const request = (user, method='GET', data, path='/api/sync/library', originHeader=origin) => new Request(origin+path, {method, headers: {...(user ? {'oai-authenticated-user-id': user} : {}), origin: originHeader, 'content-type': 'application/json', 'x-writing-human-sync': '1', 'x-writing-human-account': user ?? ''}, ...(data ? {body: JSON.stringify(data)} : {})});

test('Bookplate, date and pencil marks remain optional and reject malformed values', () => {
  const library = empty();
  library.books = [{id:'b',title:'책',author:'',owner:'필명'}];
  library.records = [{id:'r',bookId:'b',title:'필사',source:''}];
  library.pages = [{id:'p',recordId:'r',number:1,text:'한글 문장',base:0,extent:2,scroll:0,writtenOn:'2026-11-10',pencilMarks:[{start:0,end:2}]}];
  assert.equal(validLibrary(library), true);
  library.pages[0].pencilMarks[0].end = 999;
  assert.equal(validLibrary(library), false);
  library.pages[0].pencilMarks = [];
  library.pages[0].writtenOn = '2026-02-30';
  assert.equal(validLibrary(library), false);
  delete library.pages[0].writtenOn; delete library.pages[0].pencilMarks;
  delete library.books[0].owner;
  assert.equal(validLibrary(library), true);
});

test('Development typeface flag is optional and validated without changing legacy indices', () => {
  const library = empty();
  assert.equal(validLibrary(library), true);
  library.style.useDevelopmentTypeface = true;
  assert.equal(validLibrary(library), true);
  library.style.useDevelopmentTypeface = 'true';
  assert.equal(validLibrary(library), false);
  library.style.useDevelopmentTypeface = false;
  assert.equal(validLibrary(library), true);
});

test('Independent book details accept legacy defaults and validate every separate choice', () => {
  const library = empty();
  for (const bookDetails of [{}, {ribbon:{enabled:false,variant:1,tone:2},dateStamp:{enabled:true,variant:2,tone:3}}]) {
    library.style.bookDetails = bookDetails;
    assert.equal(validLibrary(library), true);
  }
  for (const bookDetails of [null, [], {ribbon:{enabled:'yes'}}, {pencil:{variant:3}}, {binding:{tone:-1}}, {dateStamp:{tone:1.5}}, {unknown:{}}]) {
    library.style.bookDetails = bookDetails;
    assert.equal(validLibrary(library), false);
  }
});

test('Account isolation, compare-and-swap, malformed writes and real file reopen', async () => {
  const dir=mkdtempSync(join(tmpdir(),'writing-human-server-')), file=join(dir,'cloud.db');
  let db = new SQLiteD1(file);
  try {
    db.db.exec('CREATE TABLE sync_libraries (user_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
    const env = {DB: db};
    assert.equal((await worker.fetch(request(null),env)).status,401);
    assert.equal((await worker.fetch(request('a','PUT',{baseRevision:0,library:empty()},undefined,'https://evil.test'),env)).status,403);
    assert.equal((await worker.fetch(request('a','PUT',{baseRevision:0,library:{...empty(),sync:{token:'secret'}}}),env)).status,400);
    assert.equal((await worker.fetch(request('a','PUT',{baseRevision:0,library:empty()}),env)).status,200);
    let cloud = await (await worker.fetch(request('a'),env)).json();
    assert.equal(cloud.revision,1);
    assert.equal((await (await worker.fetch(request('b'),env)).json()).revision,0);
    const one = empty(); one.books = [{id:'book',title:'동기화된 책',author:'나',owner:'필명'}];
    one.records = [{id:'record',bookId:'book',title:'필사',source:''}];
    one.pages = [{id:'page',recordId:'record',number:1,text:'한글 문장',base:0,extent:2,scroll:0,writtenOn:'2026-11-10',pencilMarks:[{start:0,end:2}]}];
    one.style.bookDetails = {ribbon:{enabled:true,variant:1,tone:2},pencil:{enabled:false,variant:2,tone:3}};
    assert.equal((await worker.fetch(request('a','PUT',{baseRevision:1,library:one}),env)).status,200);
    const stale=await worker.fetch(request('a','PUT',{baseRevision:1,library:empty()}),env);
    assert.equal(stale.status,409);
    assert.equal((await stale.json()).library.books[0].title,'동기화된 책');
    const switched = request('b','PUT',{baseRevision:0,library:one});
    switched.headers.set('x-writing-human-account','a');
    assert.equal((await worker.fetch(switched,env)).status,412);
    assert.equal((await (await worker.fetch(request('b'),env)).json()).revision,0);
    const invalid=empty(); invalid.records=[{id:'bad',bookId:'missing',title:'기록',source:''}];
    assert.equal((await worker.fetch(request('a','PUT',{baseRevision:2,library:invalid}),env)).status,400);
    db.close(); db=new SQLiteD1(file);
    cloud=await (await worker.fetch(request('a'),{DB:db})).json();
    assert.equal(cloud.revision,2); assert.equal(cloud.library.books[0].title,'동기화된 책');
    assert.equal(cloud.library.books[0].owner,'필명');
    assert.equal(cloud.library.pages[0].writtenOn,'2026-11-10');
    assert.deepEqual(cloud.library.pages[0].pencilMarks,[{start:0,end:2}]);
    assert.deepEqual(cloud.library.style.bookDetails,one.style.bookDetails);
    assert.equal((await (await worker.fetch(request('b'),{DB:db})).json()).library,null);
  } finally { db.close(); rmSync(dir,{recursive:true,force:true}); }
});

test('Two simultaneous clients cannot both overwrite the same revision', async()=>{
  const db=new SQLiteD1(':memory:');
  db.db.exec('CREATE TABLE sync_libraries (user_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
  try {
    await worker.fetch(request('a','PUT',{baseRevision:0,library:empty()}),{DB:db});
    const results=await Promise.all([worker.fetch(request('a','PUT',{baseRevision:1,library:empty()}),{DB:db}),worker.fetch(request('a','PUT',{baseRevision:1,library:empty()}),{DB:db})]);
    assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
  } finally { db.close(); }
});
