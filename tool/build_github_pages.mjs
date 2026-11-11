import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {readFileSync, writeFileSync} from 'node:fs';
import {prepareOcr} from './prepare_ocr.mjs';

await prepareOcr();

// A separate output prevents the static preview from replacing the Sites Worker.
const repository = process.env.GITHUB_REPOSITORY?.split('/')[1];
const defaultBase = repository
  ? repository.endsWith('.github.io') ? '/' : `/${repository}/`
  : '/writing-human/';
const base = process.argv[2] ?? defaultBase;
if (!/^\/(?:[A-Za-z0-9_.-]+\/)*$/.test(base) || base.includes('/../')) {
  throw new Error('Provide a base path such as /writing-human/ or /.');
}
const output = 'build/github-pages';
const result = spawnSync('flutter', [
  'build', 'web', '--release', '--no-wasm-dry-run',
  '--no-web-resources-cdn', '--base-href', base,
  '--dart-define=WRITING_HUMAN_LOCAL_ONLY=true', '--output', output,
], {stdio: 'inherit'});
if (result.status !== 0) process.exit(result.status ?? 1);
const html = readFileSync(`${output}/index.html`, 'utf8');
if (!html.includes(`<base href="${base}">`)) {
  throw new Error('The generated index has an unexpected base path.');
}
const version = bytes => createHash('sha256').update(bytes).digest('hex').slice(0, 16);
const appVersion = version(readFileSync(`${output}/main.dart.js`));
const bootstrapPath = `${output}/flutter_bootstrap.js`;
const bootstrap = readFileSync(bootstrapPath, 'utf8');
const appEntry = '"mainJsPath":"main.dart.js"';
const loaderEntry = 'src="flutter_bootstrap.js"';
if (!bootstrap.includes(appEntry) || !html.includes(loaderEntry)) {
  throw new Error('The generated Flutter loader has an unexpected entry path.');
}
const loader = bootstrap.replace(appEntry, `"mainJsPath":"main.dart.js?v=${appVersion}"`);
writeFileSync(bootstrapPath, loader);
writeFileSync(`${output}/index.html`, html.replace(loaderEntry, `src="flutter_bootstrap.js?v=${version(loader)}"`));
writeFileSync(`${output}/.nojekyll`, '');
console.log(`GitHub Pages build ready at ${output}, base ${base}, local storage only.`);
