import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {mkdir, readFile, rm, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {gzipSync} from 'node:zlib';

const modelRevision = '87416418657359cb625c412a48b6e1d6d41c29bd';
const modelRoot = `https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/${modelRevision}`;
const downloads = [
  ['tesseract.tgz', 'https://registry.npmjs.org/tesseract.js/-/tesseract.js-6.0.1.tgz', 'sha512', 'base64', '/sPvMvrCtgxnNRCjbTYbr7BRu0yfWDsMZQ2a/T5aN/L1t8wUQN6tTWv6p6FwzpoEBA0jrN2UD2SX4QQFRdoDbA=='],
  ['core.tgz', 'https://registry.npmjs.org/tesseract.js-core/-/tesseract.js-core-6.0.0.tgz', 'sha512', 'base64', '1Qncm/9oKM7xgrQXZXNB+NRh19qiXGhxlrR8EwFbK5SaUbPZnS5OMtP/ghtqfd23hsr1ZvZbZjeuAGcMxd/ooA=='],
  ['kor.traineddata', `${modelRoot}/kor.traineddata`, 'sha256', 'hex', '6b85e11d9bbf07863b97b3523b1b112844c43e713df8b66418a081fd1060b3b2'],
  ['model-LICENSE', `${modelRoot}/LICENSE`, 'sha256', 'hex', 'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30'],
];

export async function prepareOcr() {
  const cache = 'build/ocr-inputs';
  const output = 'web/vendor/ocr';
  await Promise.all([mkdir(cache, {recursive: true}), mkdir(output, {recursive: true})]);
  await Promise.all(downloads.map(async ([name, url, hash, encoding, expected]) => {
    const path = `${cache}/${name}`;
    const matches = bytes => createHash(hash).update(bytes).digest(encoding) === expected;
    const cached = await readFile(path).catch(() => null);
    if (cached && matches(cached)) return;
    const response = await fetch(url, {signal: AbortSignal.timeout(90_000)});
    if (!response.ok) throw new Error(`OCR asset download failed: ${name} (${response.status})`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (!matches(bytes)) throw new Error(`OCR asset integrity mismatch: ${name}`);
    await writeFile(path, bytes);
  }));
  const extract = (archive, member) => execFileSync('tar', ['-xOf', `${cache}/${archive}`, `package/${member}`], {maxBuffer: 16 * 1024 * 1024});
  const members = [
    ['tesseract.tgz', 'dist/tesseract.min.js', 'tesseract.min.js'],
    ['tesseract.tgz', 'dist/worker.min.js', 'worker.min.js'],
    ['tesseract.tgz', 'LICENSE.md', 'Tesseract-LICENSE.md'],
    ['tesseract.tgz', 'dist/tesseract.min.js.LICENSE.txt', 'tesseract.min.js.LICENSE.txt'],
    ['tesseract.tgz', 'dist/worker.min.js.LICENSE.txt', 'worker.min.js.LICENSE.txt'],
    ['core.tgz', 'LICENSE', 'Core-LICENSE'],
    ...['tesseract-core', 'tesseract-core-simd', 'tesseract-core-lstm', 'tesseract-core-simd-lstm'].map(core => ['core.tgz', `${core}.wasm.js`, `${core}.wasm.js`]),
  ];
  for (const [archive, member, target] of members) await writeFile(`${output}/${target}`, extract(archive, member));
  await writeFile(`${output}/kor.traineddata.gz`, gzipSync(await readFile(`${cache}/kor.traineddata`)));
  await rm(`${output}/eng.traineddata.gz`, {force: true});
  await writeFile(`${output}/Models-LICENSE`, await readFile(`${cache}/model-LICENSE`));
  console.log('Prepared pinned, same-origin Korean OCR assets.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  await prepareOcr();
}
