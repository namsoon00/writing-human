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

test('the semantic input host is anchored to the Flutter view', () => {
  assert.match(html, /flutter-view > flt-semantics-host\s*\{\s*top:\s*0;\s*left:\s*0;\s*\}/);
});

function simulate({x = 100, move = 0, duration = 80, control, composing = false,
  isTrusted = true, canceled = false, replaceEditor = false,
  search = false, alreadyFocused = false, disabled = false,
  keyboardVisible = false, blurDuringTap = false, cancelable = true} = {}) {
  const handlers = new Map();
  vm.runInNewContext(bridge, {
    matchMedia: () => ({matches: true}),
    CSS: {supports: () => false},
    window: {
      innerHeight: 844,
      visualViewport: {height: keyboardVisible ? 510 : 844, scale: 1},
    },
    document: {
      documentElement: {classList: {add() {}}},
      addEventListener: (name, callback) => handlers.set(name, callback),
    },
  });
  const result = {focused: false, prevented: false};
  let editorFocused = alreadyFocused;
  const editor = {
    localName: search ? 'input' : 'textarea',
    disabled,
    matches(selector) {
      assert.equal(selector, ':focus');
      return editorFocused;
    },
    focus(options) {
      assert.equal(options.preventScroll, true);
      result.focused = true;
    },
    getBoundingClientRect: () => ({left: 38, right: 352, top: 100, bottom: 600}),
  };
  let currentEditor = editor;
  const field = {querySelector: () => currentEditor};
  const behind = {
    querySelector: () => ({
      ...editor,
      getBoundingClientRect: () => ({left: 0, right: 0, top: 0, bottom: 0}),
    }),
  };
  const view = {
    localName: 'flutter-view',
    querySelectorAll(selector) {
      assert.match(selector, /writing-page-body/);
      assert.match(selector, /paper-search-input/);
      return search ? [behind, field] : [field];
    },
  };
  const path = [control ?? {localName: 'flt-glass-pane'}, view];
  const touch = (delta) => ({clientX: x + delta, clientY: 180, identifier: 1});
  handlers.get('touchstart')({composedPath: () => path, touches: [touch(0)], timeStamp: 0});
  if (composing) {
    handlers.get('compositionstart')({composedPath: () => [{matches: () => true}]});
  }
  if (move) handlers.get('touchmove')({touches: [touch(move)]});
  if (canceled) handlers.get('touchcancel')();
  if (replaceEditor) currentEditor = {...editor};
  if (blurDuringTap) editorFocused = false;
  handlers.get('touchend')({
    composedPath: () => path,
    changedTouches: [touch(move)],
    touches: [],
    timeStamp: duration,
    isTrusted,
    cancelable,
    preventDefault() { result.prevented = true; },
  });
  return result;
}

test('a short tap on a nested Flutter surface opens the body input', () => {
  assert.deepEqual(simulate({move: 12}), {focused: true, prevented: true});
});

test('paper margins and other controls keep their own tap behavior', () => {
  const control = {localName: 'flt-semantics', closest: () => null};
  for (const input of [
    {x: 15}, {x: 370}, {control},
    {control: {localName: 'input'}},
    {control: {localName: 'textarea'}},
    {control: {isContentEditable: true}},
  ]) {
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

test('short taps request the keyboard even when the input kept its focus', () => {
  for (const search of [false, true]) {
    assert.deepEqual(simulate({search}), {focused: true, prevented: true});
    assert.deepEqual(
      simulate({search, alreadyFocused: true}),
      {focused: true, prevented: true},
    );
    assert.deepEqual(
      simulate({search, alreadyFocused: true, cancelable: false}),
      {focused: true, prevented: false},
    );
    assert.deepEqual(
      simulate({search, alreadyFocused: true, composing: true}),
      {focused: false, prevented: true},
    );
  }
});

test('empty body selection notifications cannot masquerade as deletions', () => {
  const handlers = new Map();
  const document = {
    documentElement: {classList: {add() {}}},
    addEventListener: (name, callback) => handlers.set(name, callback),
  };
  vm.runInNewContext(bridge, {
    matchMedia: () => ({matches: true}),
    CSS: {supports: () => false},
    document,
  });

  const selectionChange = handlers.get('selectionchange');
  for (const [body, value, blocked] of [
    [true, '', true],
    [true, '필사한 글', false],
    [false, '', false],
  ]) {
    document.activeElement = {matches: () => body, value};
    let stopped = false;
    selectionChange({stopImmediatePropagation() { stopped = true; }});
    assert.equal(stopped, blocked);
  }
  assert.equal(handlers.has('input'), false);
});

test('an open keyboard, an intentional blur and disabled fields keep their behavior', () => {
  assert.deepEqual(
    simulate({search: true, alreadyFocused: true, keyboardVisible: true}),
    {focused: false, prevented: true},
  );
  assert.deepEqual(
    simulate({alreadyFocused: true, blurDuringTap: true}),
    {focused: false, prevented: true},
  );
  assert.deepEqual(
    simulate({search: true, disabled: true}),
    {focused: false, prevented: false},
  );
});
