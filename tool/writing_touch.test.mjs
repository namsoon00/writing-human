import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const html = await readFile(new URL('../web/index.html', import.meta.url), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
const bridge = scripts.map((match) => match[1]).find((script) =>
  script.includes('writing-page-body'),
);
assert.ok(bridge);

function simulate({x = 100, move = 0, duration = 80, control, composing = false,
  isTrusted = true, canceled = false, replaceEditor = false} = {}) {
  const handlers = new Map();
  vm.runInNewContext(bridge, {
    CSS: {supports: () => true},
    document: {addEventListener: (name, callback) => handlers.set(name, callback)},
  });
  const result = {focused: false, prevented: false};
  const editor = {
    focus(options) {
      assert.equal(options.preventScroll, true);
      result.focused = true;
    },
    getBoundingClientRect: () => ({left: 38, right: 352, top: 100, bottom: 600}),
  };
  let currentEditor = editor;
  const view = {localName: 'flutter-view', querySelector: () => currentEditor};
  const path = [control ?? {localName: 'flt-glass-pane'}, view];
  const touch = (delta) => ({clientX: x + delta, clientY: 180, identifier: 1});
  handlers.get('touchstart')({composedPath: () => path, touches: [touch(0)], timeStamp: 0});
  if (composing) {
    handlers.get('compositionstart')({composedPath: () => [{matches: () => true}]});
  }
  if (move) handlers.get('touchmove')({touches: [touch(move)]});
  if (canceled) handlers.get('touchcancel')();
  if (replaceEditor) currentEditor = {...editor};
  handlers.get('touchend')({
    composedPath: () => path,
    changedTouches: [touch(move)],
    touches: [],
    timeStamp: duration,
    isTrusted,
    cancelable: true,
    preventDefault() { result.prevented = true; },
  });
  return result;
}

test('a short tap on a nested Flutter surface opens the body input', () => {
  assert.deepEqual(simulate({move: 12}), {focused: true, prevented: true});
});

test('paper margins and other controls keep their own tap behavior', () => {
  const control = {localName: 'flt-semantics', closest: () => null};
  for (const input of [{x: 15}, {x: 370}, {control}]) {
    assert.deepEqual(simulate(input), {focused: false, prevented: false});
  }
});

test('swipes, long presses and composing input do not refocus the body', () => {
  for (const input of [{move: 30}, {duration: 550}, {composing: true}]) {
    assert.deepEqual(simulate(input), {focused: false, prevented: true});
  }
});

test('canceled or untrusted touches and replaced inputs are ignored', () => {
  for (const input of [{canceled: true}, {isTrusted: false}, {replaceEditor: true}]) {
    assert.deepEqual(simulate(input), {focused: false, prevented: false});
  }
});
