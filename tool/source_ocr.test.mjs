import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const bridge = await readFile(new URL('../web/source_ocr.js', import.meta.url), 'utf8');

function environment(recognize) {
  const window = {};
  const state = {scripts: [], options: null, terminated: 0, modes: []};
  const document = {
    baseURI: 'https://example.test/writing-human/',
    createElement: () => ({}),
    head: {appendChild(script) {
      state.scripts.push(script.src);
      window.Tesseract = {async createWorker(languages, oem, options) {
        state.options = {languages: Array.from(languages), oem, ...options};
        return {recognize, async setParameters(options) { state.modes.push(options.tessedit_pageseg_mode); }, async terminate() { state.terminated++; }};
      }};
      script.onload();
    }},
  };
  vm.runInNewContext(bridge, {window, document, URL, Blob});
  return {window, state};
}

test('photo bridge loads same-origin assets lazily and returns individual paragraphs', async () => {
  const {window, state} = environment(async (image, _, output) => {
    assert.deepEqual([...new Uint8Array(await image.arrayBuffer())], [1, 2, 3]);
    assert.equal(output.blocks, true);
    return {data: {text: 'fallback', blocks: [{paragraphs: [{text: ' 첫 문단 '}, {text: '둘째 문단'}]}]}};
  });
  assert.deepEqual(state.scripts, []);
  const paragraphs = await window.writingHumanRecognizePhoto(new Uint8Array([1, 2, 3]));
  assert.deepEqual(Array.from(paragraphs), ['첫 문단', '둘째 문단']);
  const base = 'https://example.test/writing-human/vendor/ocr/';
  assert.deepEqual(state.scripts, [`${base}tesseract.min.js`]);
  assert.equal(state.options.workerPath, `${base}worker.min.js`);
  assert.equal(state.options.corePath, base);
  assert.equal(state.options.langPath, base.slice(0, -1));
  assert.deepEqual(state.options.languages, ['kor']);
  assert.deepEqual(state.modes, ['4']);
  assert.equal(state.terminated, 1);
});

test('closing a photo review cancels pending recognition and terminates its worker', async () => {
  const {window, state} = environment(() => new Promise(() => {}));
  const result = window.writingHumanRecognizePhoto(new Uint8Array([1]));
  await new Promise(resolve => setImmediate(resolve));
  window.writingHumanCancelOcr();
  await assert.rejects(result, /Cancelled/);
  assert.equal(state.terminated, 1);
});
