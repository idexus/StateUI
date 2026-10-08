// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The driver's functions in a browser's page (Sources/CWebTesting/CWebTesting.h), for the conformance suite that
// run-in-browser.mjs runs: the page goes on a frame while the program waits, the controller beside the browser is asked
// for what the page cannot do itself - the user's own input, a file - and a script runs on an element. What only
// Node's page answers (page.mjs) is no function here.

const encoder = new TextEncoder();

// The controller's answers awaited, by number.
const waiting = new Map();
let asked = 0;

/** Hands the controller `message`, and answers what it answers. */
function controller(message) {
  const number = ++asked;
  return new Promise((done) => {
    waiting.set(number, done);
    globalThis.stateuiDriver(JSON.stringify({ number, message }));
  });
}

/** What the controller answers the message of `number`: its words, or null for none. */
globalThis.stateuiAnswered = (number, words) => {
  waiting.get(number)?.(words);
  waiting.delete(number);
};

// What the driver's scripts share: a CSS colour as its channels, an element's box in the window, the words a live
// region was told.
const painter = document.createElement("canvas").getContext("2d", { willReadFrequently: true });
globalThis.stateui = {
  /** `css` as "red,green,blue,alpha", each 0-255; null for none. */
  channels(css) {
    if (!css || css === "none") return null;
    const numbers = css.match(/^rgba?\(([^)]*)\)$/)?.[1].split(/[\s,/]+/).filter(Boolean).map(Number);
    if (numbers && numbers.length >= 3) {
      const alpha = numbers.length > 3 ? numbers[3] : 1;
      return [numbers[0], numbers[1], numbers[2], Math.round(alpha * 255)].map(Math.round).join(",");
    }
    painter.clearRect(0, 0, 1, 1);
    painter.fillStyle = css;
    painter.fillRect(0, 0, 1, 1);
    return [...painter.getImageData(0, 0, 1, 1).data].join(",");
  },
  /** Where `element` stands in the window: x, y, width, height. */
  box(element) {
    const box = element.getBoundingClientRect();
    return [box.x, box.y, box.width, box.height];
  },
  /** What the page told assistive technology to say, in order, since it started. */
  announced: [],
  /** The relay shows no file dialog and launches nothing on a page a test drives: it holds the dialog here for the
   *  test to answer from its own files, by name, and records what it would launch. */
  holdsFiles: true,
  files: new Map(),
  fileDialog: null,
  launched: [],
};
new MutationObserver(() => {
  const region = document.getElementById("stateui-announcer");
  if (!region || stateui.watching === region) return;
  stateui.watching = region;
  new MutationObserver(() => {
    if (region.textContent) stateui.announced.push(region.textContent);
  }).observe(region, { childList: true, characterData: true, subtree: true });
}).observe(document.body, { childList: true });

/** The program ended, with its code: the controller ends the run with it. */
export function exited(code) {
  globalThis.stateuiDriver(JSON.stringify({ exit: code }));
}

/** The driver's functions, over `page` - the relay's elements and the module's memory. */
export function driver(page) {
  stateui.numberOf = page.numberOf;
  let read = new Uint8Array(0);
  const answer = (text) => (read = encoder.encode(text)).length;
  // A frame of the page's: its tasks, its rendering and what its observers say of it, then what that queued.
  const frame = () => new Promise((done) => requestAnimationFrame(() => setTimeout(done, 0)));
  const functions = {
    copy_read: (into) => page.bytes(into, read.length).set(read),
    pause: new WebAssembly.Suspending(frame),
    // The controller's answer, its length; -1 for none.
    ask: new WebAssembly.Suspending(async (pointer, length) => {
      const words = await controller(JSON.parse(page.text(pointer, length)));
      return words === null || words === undefined ? -1 : answer(String(words));
    }),
    // The script's value after "=": words as they are, a list its entries a NUL apart, anything else as JavaScript
    // writes it; nothing for none, and why after "!" where it threw.
    evaluate: (element, pointer, length) => {
      let value;
      try {
        value = new Function("e", `return (${page.text(pointer, length)});`)(page.element(element));
      } catch (error) {
        return answer(`!${error?.name ?? "Error"}: ${error?.message ?? error}`);
      }
      if (value === null || value === undefined) return answer("");
      return answer("=" + (Array.isArray(value) ? value.join("\0") : String(value)));
    },
  };
  return {
    stateui_web_testing: new Proxy(functions, {
      get: (all, name) => all[name] ?? (() => { throw new Error(`${String(name)}: Node's page alone answers it`); }),
    }),
  };
}
