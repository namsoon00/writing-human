const MAX_BYTES = 2 * 1024 * 1024;
const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'private, no-store', 'vary': 'Cookie', 'x-content-type-options': 'nosniff' };
const json = (value, status = 200) => new Response(JSON.stringify(value), {status, headers});
const error = (code, status) => json({error: code}, status);
const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const id = v => typeof v === 'string' && v.length > 0 && v.length <= 250;
const text = (v, max = MAX_BYTES) => typeof v === 'string' && v.length <= max;
const integer = v => Number.isSafeInteger(v);
const photoId = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const writingRange = (range, original) => object(range) &&
  integer(range.start) && integer(range.end) && range.start >= 0 &&
  range.end > range.start && range.end <= original.length &&
  (original.charCodeAt(range.start) & 0xfc00) !== 0xdc00 &&
  (original.charCodeAt(range.end) & 0xfc00) !== 0xdc00 &&
  original.slice(range.start, range.end).trim().length > 0;

const validPhotoLines = (lines, original) => {
  if (!Array.isArray(lines) || lines.length > 500) return false;
  let previousEnd = 0;
  for (const row of lines) {
    if (!Array.isArray(row) || row.length !== 6 || !row.every(integer)) return false;
    const [start, end, left, top, right, bottom] = row;
    if (start < previousEnd || !writingRange({start, end}, original) ||
        left < 0 || top < 0 || right > 10000 || bottom > 10000 ||
        left >= right || top >= bottom) return false;
    previousEnd = end;
  }
  return true;
};

const reflection = (value, original) => object(value) && text(value.text) &&
  value.text.trim().length > 0 &&
  (!('mark' in value) || (object(value.mark) && integer(value.mark.start) &&
    integer(value.mark.end) && value.mark.start >= 0 &&
    value.mark.end > value.mark.start && value.mark.end <= original.length));

const originals = values => Array.isArray(values) &&
  new Set(values.map(value => value?.id)).size === values.length &&
  values.every(value => object(value) && id(value.id) && text(value.text, 50000) &&
    value.text.trim().length > 0 && text(value.citation, 500) &&
    (!('photoId' in value) || photoId(value.photoId)) &&
    (!('isFullPage' in value) || typeof value.isFullPage === 'boolean') &&
    (!('writingRange' in value) ||
      (value.isFullPage === true && writingRange(value.writingRange, value.text))) &&
    (!('photoLines' in value) || (value.isFullPage === true && photoId(value.photoId) &&
      validPhotoLines(value.photoLines, value.text))) &&
    (!('reflection' in value) || reflection(value.reflection, value.text)));

function validBookDetails(details) {
    const kinds = ['ribbon', 'bookplate', 'sourceSlip', 'pencil', 'ornament', 'binding', 'dateStamp', 'indexTab', 'recordDivider', 'pressedFlower'];
    return object(details) && !Object.entries(details).some(([kind, choice]) =>
      !kinds.includes(kind) || !object(choice) || Object.keys(choice).some(k => !['enabled', 'variant', 'tone', 'placement'].includes(k)) ||
      ('enabled' in choice && typeof choice.enabled !== 'boolean') ||
      ('variant' in choice && (!integer(choice.variant) || choice.variant < 0 || choice.variant > 2)) ||
      ('placement' in choice && (!integer(choice.placement) || choice.placement < 0 || choice.placement > 2)) ||
      ('tone' in choice && (!integer(choice.tone) || choice.tone < 0 || choice.tone > 3)));
}

export function validLibrary(l) {
  if (!object(l) || l.version !== 1 || 'sync' in l || !Array.isArray(l.books) || !Array.isArray(l.records) || !Array.isArray(l.pages) || l.books.length > 10000 || l.records.length > 20000 || l.pages.length > 30000 || typeof l.writing !== 'boolean') return false;
  const books = new Set(), records = new Map(), pages = new Map(), numbers = new Set();
  for (const b of l.books) {
    if (!object(b) || !id(b.id) || books.has(b.id) || !text(b.title, 500) || !text(b.author, 500)) return false;
    if ('owner' in b && !text(b.owner, 80)) return false;
    if ('indexLabel' in b && !text(b.indexLabel, 80)) return false;
    if ('coverIndex' in b && (!integer(b.coverIndex) || b.coverIndex < 0 || b.coverIndex > 2)) return false;
    if ('paperIndex' in b && (!integer(b.paperIndex) || b.paperIndex < 0 || b.paperIndex > 3)) return false;
    if ('detailOverrides' in b && !validBookDetails(b.detailOverrides)) return false;
    if ('originals' in b && !originals(b.originals)) return false;
    books.add(b.id);
  }
  for (const r of l.records) {
    if (!object(r) || !id(r.id) || records.has(r.id) || (r.bookId !== null && !books.has(r.bookId)) || !text(r.title, 500) || !text(r.source)) return false;
    if ('sourceParagraph' in r && (!integer(r.sourceParagraph) || r.sourceParagraph < 0)) return false;
    if ('originals' in r && !originals(r.originals)) return false;
    records.set(r.id, r.bookId);
  }
  for (const p of l.pages) {
    const n = JSON.stringify([p?.recordId, p?.number]);
    if (!object(p) || !id(p.id) || pages.has(p.id) || !records.has(p.recordId) || !integer(p.number) || p.number < 1 || numbers.has(n) || !text(p.text) || !integer(p.base) || !integer(p.extent) || p.base < -1 || p.extent < -1 || p.base > p.text.length || p.extent > p.text.length || typeof p.scroll !== 'number' || !Number.isFinite(p.scroll) || p.scroll < 0) return false;
    if ('writtenOn' in p && (typeof p.writtenOn !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(p.writtenOn) || !Number.isFinite(Date.parse(p.writtenOn)) || new Date(p.writtenOn).toISOString().slice(0, 10) !== p.writtenOn)) return false;
    if ('pencilMarks' in p && (!Array.isArray(p.pencilMarks) || p.pencilMarks.length > p.text.length || p.pencilMarks.some(m => !object(m) || !integer(m.start) || !integer(m.end) || m.start < 0 || m.end <= m.start || m.end > p.text.length))) return false;
    if ('passages' in p && (!Array.isArray(p.passages) ||
      new Set(p.passages.map(entry => entry?.id)).size !== p.passages.length ||
      p.passages.some(entry => !object(entry) || !id(entry.id) ||
        !integer(entry.start) || entry.start < 0 || entry.start > p.text.length ||
        !text(entry.source) || !text(entry.citation, 500) ||
        ('continued' in entry && typeof entry.continued !== 'boolean') ||
        !integer(entry.paragraph) || entry.paragraph < 0 ||
        !integer(entry.sourceOffset) || entry.sourceOffset < 0 || entry.sourceOffset > entry.source.length))) return false;
    pages.set(p.id, records.get(p.recordId)); numbers.add(n);
  }
  if ((l.activePageId !== null && !pages.has(l.activePageId)) || (l.writing && l.activePageId === null)) return false;
  if ('bookPositions' in l && (!object(l.bookPositions) ||
    Object.entries(l.bookPositions).some(([book, page]) =>
      !books.has(book) || !id(page) || pages.get(page) !== book))) return false;
  const s = l.style;
  if (!object(s) || !integer(s.paperIndex) || s.paperIndex < 0 || s.paperIndex > 3 || !integer(s.penIndex) || s.penIndex < 0 || s.penIndex > 2 || !integer(s.fontIndex) || s.fontIndex < 0 || s.fontIndex > 2 || typeof s.guides !== 'boolean' || !Array.isArray(s.favoriteBookIds) || s.favoriteBookIds.some(v => !id(v))) return false;
  if ('useDevelopmentTypeface' in s && typeof s.useDevelopmentTypeface !== 'boolean') return false;
  if (['pageMotion', 'pageSound'].some(k => k in s && typeof s[k] !== 'boolean')) return false;
  if ('bookDetails' in s && !validBookDetails(s.bookDetails)) return false;
  // Do not let clients smuggle extra secrets or alternate identities into storage.
  const keys = ['version', 'books', 'records', 'pages', 'activePageId', 'bookPositions', 'writing', 'style'];
  return Object.keys(l).every(k => keys.includes(k));
}

async function body(request) {
  if (Number(request.headers.get('content-length')) > MAX_BYTES) throw new RangeError();
  const reader = request.body?.getReader();
  if (!reader) throw new SyntaxError();
  const chunks = []; let size = 0;
  try {
    while (true) {
      const {value, done} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) { await reader.cancel(); throw new RangeError(); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes));
}

async function read(db, userId) {
  const row = await db.prepare('SELECT revision, payload, updated_at FROM sync_libraries WHERE user_id = ?').bind(userId).first();
  return row ? {revision: row.revision, library: JSON.parse(row.payload), updatedAt: row.updated_at} : {revision: 0, library: null, updatedAt: null};
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/sync/')) {
      return env.ASSETS ? env.ASSETS.fetch(request) : new Response('Not found', {status: 404});
    }
    // Owner-private Sites gate protects this non-personal readiness check,
    // including service callers. It never reads any writing record.
    if (url.pathname === '/api/sync/health' && request.method === 'GET') {
      try {
        const schema = await env.DB?.prepare("SELECT 1 AS ready FROM sqlite_master WHERE type = 'table' AND name = 'sync_libraries'").first();
        return schema ? json({ready: true, origin: url.origin}) : error('storage_unavailable', 503);
      } catch (_) { return error('storage_unavailable', 503); }
    }
    // These headers are injected by Sites, never read from JSON/query parameters.
    const userId = request.headers.get('oai-authenticated-user-id');
    if (!userId) return error('sign_in_required', 401);
    if (url.pathname === '/api/sync/session' && request.method === 'GET') {
      return json({userId, email: request.headers.get('oai-authenticated-user-email') ?? ''});
    }
    if (url.pathname !== '/api/sync/library') return error('not_found', 404);
    if (request.headers.get('x-writing-human-account') !== userId) return error('account_changed', 412);
    if (!env.DB) return error('storage_unavailable', 503);
    try {
      if (request.method === 'GET') return json(await read(env.DB, userId));
      if (request.method !== 'PUT') return error('method_not_allowed', 405);
      const origin = request.headers.get('origin');
      if (origin !== url.origin || request.headers.get('sec-fetch-site') === 'cross-site' || request.headers.get('x-writing-human-sync') !== '1' || !request.headers.get('content-type')?.startsWith('application/json')) return error('invalid_origin', 403);
      let data;
      try { data = await body(request); }
      catch (e) { return error(e instanceof RangeError ? 'too_large' : 'invalid_json', e instanceof RangeError ? 413 : 400); }
      if (!object(data) || !integer(data.baseRevision) || data.baseRevision < 0 || Object.keys(data).some(k => !['baseRevision', 'library'].includes(k)) || !validLibrary(data.library)) return error('invalid_library', 400);
      const payload = JSON.stringify(data.library), now = new Date().toISOString();
      const statement = data.baseRevision === 0
        ? env.DB.prepare('INSERT INTO sync_libraries (user_id, revision, payload, updated_at) VALUES (?, 1, ?, ?) ON CONFLICT(user_id) DO NOTHING RETURNING revision, updated_at').bind(userId, payload, now)
        : env.DB.prepare('UPDATE sync_libraries SET revision = revision + 1, payload = ?, updated_at = ? WHERE user_id = ? AND revision = ? RETURNING revision, updated_at').bind(payload, now, userId, data.baseRevision);
      const row = await statement.first();
      if (!row) return json({error: 'revision_conflict', ...await read(env.DB, userId)}, 409);
      return json({revision: row.revision, library: data.library, updatedAt: row.updated_at});
    } catch (_) {
      // Do not echo SQL, tokens, personal notes, or database exception text.
      return error('storage_unavailable', 503);
    }
  },
};
