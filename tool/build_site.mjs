import {spawnSync} from 'node:child_process';
import {cpSync, mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {prepareOcr} from './prepare_ocr.mjs';

await prepareOcr();

const r = spawnSync('flutter', ['build', 'web', '--release', '--no-wasm-dry-run', '--no-web-resources-cdn', '--output', 'build/web'], {stdio: 'inherit'});
if (r.status !== 0) process.exit(r.status ?? 1);
rmSync('dist', {recursive: true, force: true});
mkdirSync('dist/server', {recursive: true});
cpSync('build/web', 'dist/client', {recursive: true});
cpSync('server/index.mjs', 'dist/server/index.js');
const hosting = JSON.parse(readFileSync('.openai/hosting.json', 'utf8'));
if (hosting.static || hosting.d1 !== 'DB') throw new Error('Sync requires the DB Worker manifest.');
mkdirSync('dist/.openai', {recursive: true});
writeFileSync('dist/.openai/hosting.json', JSON.stringify(hosting, null, 2));
writeFileSync('dist/server/wrangler.json', JSON.stringify({
  name: 'writing-human-sync', main: './index.js', compatibility_date: '2026-11-09',
  assets: {directory: '../client', binding: 'ASSETS', run_worker_first: ['/api/*']},
  d1_databases: [{binding: 'DB', database_name: 'writing-human-local', database_id: '00000000-0000-4000-8000-000000000000'}],
}, null, 2));
console.log('Built Flutter assets + account-scoped sync Worker.');
