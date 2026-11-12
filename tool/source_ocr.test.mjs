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

test('photo bridge loads same-origin assets lazily and returns normalized positions', async () => {
  const {window, state} = environment(async (image, _, output) => {
    assert.deepEqual([...new Uint8Array(await image.arrayBuffer())], [1, 2, 3]);
    assert.equal(output.blocks, true);
    return {data: {text: '첫 문단', blocks: [{paragraphs: [{
      text: ' 첫 문단 ',
      lines: [{
        text: '첫 문단', confidence: 93, bbox: {x0: 20, y0: 40, x1: 80, y1: 60},
        words: [{text: '첫', confidence: 92, bbox: {x0: 20, y0: 40, x1: 36, y1: 60}}],
      }],
    }, {text: '둘째 문단'}]}]}};
  });
  assert.deepEqual(state.scripts, []);
  const paragraphs = await window.writingHumanScanPhoto(new Uint8Array([1, 2, 3]), 100, 200, false);
  assert.equal(paragraphs[0][0].text, '첫 문단');
  assert.deepEqual(Array.from(paragraphs[0][0].bounds), [0.2, 0.2, 0.8, 0.3]);
  assert.equal(paragraphs[0][0].words[0].confidence, .92);
  assert.equal(paragraphs[1][0].text, '둘째 문단');
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
  const result = window.writingHumanScanPhoto(new Uint8Array([1]), 100, 100, true);
  await new Promise(resolve => setImmediate(resolve));
  window.writingHumanCancelOcr();
  await assert.rejects(result, /Cancelled/);
  assert.deepEqual(state.modes, ['6']);
  assert.equal(state.terminated, 1);
});

test('a recurring gutter is re-read as two columns without losing heading or footer', async () => {
  const box = (x0, y0, x1, y1) => ({x0, y0, x1, y1});
  const line = (text, y, words = []) => ({text, bbox: box(4, y, 96, y + 5), words});
  const row = (y) => line('두 단이 붙은 문장', y, [
    {text: '첫', bbox: box(4, y, 14, y + 5)},
    {text: '문장', bbox: box(16, y, 32, y + 5)},
    {text: '둘째', bbox: box(65, y, 80, y + 5)},
    {text: '문장', bbox: box(84, y, 96, y + 5)},
  ]);
  const rectangles = [];
  const {window} = environment(async (_, options) => {
    const rectangle = options.rectangle;
    if (rectangle) rectangles.push(rectangle);
    const lines = rectangle
      ? [line(rectangle.left === 0 ? '왼쪽 단' : '오른쪽 단', 20)]
      : [line('제목', 5), row(20), row(38), line('12', 94)];
    return {data: {text: '인식 결과', blocks: [{paragraphs: [{lines}]}]}};
  });
  const result = await window.writingHumanScanPhoto(new Uint8Array([1]), 100, 100, false);
  assert.deepEqual(rectangles.map(r => r.left), [0, 49]);
  assert.deepEqual(Array.from(result, paragraph => paragraph[0].text), ['제목', '왼쪽 단', '오른쪽 단', '12']);
});
