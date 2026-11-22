import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';

const allowed = new Set([
  '/assets/audio/dsp/voice_worker.mjs',
  '/assets/audio/dsp/signalsmith_factory.mjs',
]);
const server = createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (!allowed.has(req.url)) { res.writeHead(404).end(); return; }
  try { res.end(await readFile(new URL(`..${req.url}`, import.meta.url))); }
  catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
try {
  const base = `http://127.0.0.1:${server.address().port}/`;
  const child = spawn('flutter', ['test', '--no-pub', '--platform', 'chrome',
    `--dart-define=VOICE_TEST_ASSET_BASE=${base}`,
    'test/narration_voice_profile_test.dart'], {stdio:'inherit'});
  process.exitCode = await new Promise(resolve => child.on('exit', resolve));
} finally { server.close(); }
