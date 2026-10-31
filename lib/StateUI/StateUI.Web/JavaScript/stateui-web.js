// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Web host's relay: the functions the page hands the application's WebAssembly module, which the Swift host
// calls (Sources/CStateUIWeb/CStateUIWeb.h), and the system interface - WASI - a Swift program asks of its machine.
// It keeps the DOM elements Swift makes under numbers and calls Swift back through the two functions Swift hands
// it; it decides nothing of StateUI's.
// Design: docs/design/platforms/web/runtime.md#the-relay

const decoder = new TextDecoder();
const encoder = new TextEncoder();

// WASI's error numbers the page answers with, its kinds of file, and the descriptor of the page's one directory.
const EBADF = 8, ENOENT = 44, ENOSYS = 52, ESPIPE = 70;
const CHARACTERS = 2, DIRECTORY = 3;
const ROOT = 3;

/**
 * The module's bytes as they come, `bar` - where the page has one - filled as far as they have of the length the
 * server says, where it says one of the bytes themselves, else showing no share until all are in; full from then
 * on, while the browser compiles them.
 */
async function received(response, bar) {
  const reader = response.body?.getReader?.();
  if (!reader) return response.arrayBuffer();
  const whole = response.headers.get("content-encoding") ? 0 : Number(response.headers.get("content-length")) || 0;
  if (whole === 0) bar?.removeAttribute("value");
  const parts = [];
  let length = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    parts.push(value);
    length += value.length;
    if (bar && whole > 0) bar.value = Math.min(1, length / whole);
  }
  if (bar) bar.value = 1;
  const bytes = new Uint8Array(length);
  let at = 0;
  for (const part of parts) {
    bytes.set(part, at);
    at += part.length;
  }
  return bytes;
}

// The numbers the relay shares with Swift: each object below mirrors the Swift enum its marker names, case for case
// and number for number (RelayVocabularyTests), and the relay switches over its names, never over a bare number.
// Swift: WebCanvasStroke.Operation
const operations = { save: 0, restore: 1, translate: 2, rotate: 3, scale: 4, beginPath: 5, move: 6, line: 7, cubic: 8,
  quadratic: 9, close: 10, fill: 11, stroke: 12, text: 13 };
// Swift: TextEdge
const edges = { left: 0, center: 1, right: 2 };
// Swift: TextAlignment
const alignments = { start: 0, center: 1, end: 2 };
// Swift: WebHearing
const hearings = { enter: 0, within: 1, steps: 2, itemTap: 3, closed: 4, dismiss: 5, key: 6, shortcut: 7, activate: 8, press: 9 };
// Swift: WebPress.Pointer
const pointers = { mouse: 0, pen: 1, touch: 2 };
// Swift: WebRelay.FrameSource
const frameSources = { address: 0, document: 1 };
// Swift: WebRelay.FrameStep
const frameSteps = { back: 0, forward: 1, reload: 2 };
// Swift: ColorScheme
const schemes = { system: 0, light: 1, dark: 2 };

/**
 * Writes `words` in the room at (`x`, `y`) `w` by `h` on `g` at `size`, its lines `height` apart, wrapped at its width:
 * across it from `anchor` at the `edge` Swift placed them at, down it as `down` says, cut to the room.
 */
function write(g, words, x, y, w, h, size, height, edge, anchor, down) {
  g.font = `${size}px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`;
  g.textBaseline = "top";
  const lines = [];
  for (const paragraph of words.split("\n")) {
    let line = "";
    for (const word of paragraph.split(" ")) {
      const tried = line ? `${line} ${word}` : word;
      if (line && g.measureText(tried).width > w) {
        lines.push(line);
        line = word;
      } else {
        line = tried;
      }
    }
    lines.push(line);
  }
  const top = down === alignments.center ? y + (h - lines.length * height) / 2
    : down === alignments.end ? y + h - lines.length * height : y;
  g.save();
  g.beginPath();
  g.rect(x, y, w, h);
  g.clip();
  g.textAlign = edge === edges.center ? "center" : edge === edges.right ? "right" : "left";
  lines.forEach((line, index) => g.fillText(line, anchor, top + index * height + (height - size) / 2));
  g.restore();
}

/**
 * What the page spends, second by second, with `?STATEUI_PROBE=1` in its address: the frames the browser drew and how far
 * apart, the time in Swift a frame and an event - of it, in the calls to the page - and the reads of the layout.
 * Written over the page and to the console.
 * Design: docs/design/platforms/web/runtime.md#probes
 */
function probing() {
  const zero = { drawn: 0, over: 0, longest: 0, frames: 0, swift: 0, most: 0, page: 0, calls: 0, events: 0,
    heard: 0, heardMost: 0, reads: 0 };
  let second = { ...zero }, inside = null, shown = null, stages = [];
  let last = 0;
  const drawn = (now) => {
    if (last > 0) {
      second.drawn++;
      if (now - last > 25) second.over++;
      second.longest = Math.max(second.longest, now - last);
    }
    last = now;
    requestAnimationFrame(drawn);
  };
  requestAnimationFrame(drawn);
  // Every read of the layout on the page - a box, a size, a place, a style computed - whoever reads it.
  const counted = (owner, names) => {
    for (const name of names) {
      const was = Object.getOwnPropertyDescriptor(owner, name);
      const read = was?.get ? { get() { second.reads++; return was.get.call(this); } }
        : { value(...given) { second.reads++; return was.value.apply(this, given); } };
      if (was?.get || typeof was?.value === "function") Object.defineProperty(owner, name, { ...was, ...read });
    }
  };
  counted(Element.prototype, ["getBoundingClientRect", "getClientRects", "clientWidth", "clientHeight", "scrollLeft",
    "scrollTop"]);
  counted(HTMLElement.prototype, ["offsetWidth", "offsetHeight", "offsetLeft", "offsetTop", "offsetParent"]);
  counted(SVGGraphicsElement.prototype, ["getBBox"]);
  counted(Object.hasOwn(globalThis, "getComputedStyle") ? globalThis : Window.prototype, ["getComputedStyle"]);
  setInterval(() => {
    const frames = Math.max(second.frames, 1), events = Math.max(second.events, 1);
    const lines = [
      `${second.drawn} frames drawn, ${second.over} over 25 ms, longest ${second.longest.toFixed(0)} ms`,
      `${second.frames} frames in Swift: ${(second.swift / frames).toFixed(1)} ms each, most ${second.most.toFixed(1)}`,
      `  in the page ${(second.page / frames).toFixed(1)} ms, ${Math.round(second.calls / frames)} calls a frame`,
      `${second.events} events: ${(second.heard / events).toFixed(1)} ms each, most ${second.heardMost.toFixed(1)}`,
      `${second.reads} reads of the layout`,
      ...stages,
    ];
    console.log("StateUI probe:", lines.join(" · "));
    if (!shown && document.body) {
      shown = document.createElement("div");
      shown.style.cssText = "position:fixed;left:8px;bottom:calc(env(safe-area-inset-bottom) + 8px);z-index:2147483647;"
        + "pointer-events:none;white-space:pre;font:11px/1.35 ui-monospace,Menlo,monospace;color:#fff;"
        + "background:rgba(0,0,0,0.72);padding:6px 8px;border-radius:8px";
      document.body.append(shown);
    }
    if (shown) shown.textContent = lines.join("\n");
    second = { ...zero };
  }, 1000);
  return {
    // A call into Swift - a frame or an event - timed whole; one inside another counts in the outer.
    into(kind, run) {
      if (inside) return run();
      inside = kind;
      const start = performance.now();
      try {
        return run();
      } finally {
        const spent = performance.now() - start;
        inside = null;
        if (kind === "frame") {
          second.frames++;
          second.swift += spent;
          second.most = Math.max(second.most, spent);
        } else {
          second.events++;
          second.heard += spent;
          second.heardMost = Math.max(second.heardMost, spent);
        }
      }
    },
    // The runtime's own line of its stages, `StateUI stages: …`, shown with the next second's: true where it is one.
    stages(line) {
      if (!line.startsWith("StateUI stages:")) return false;
      stages = ["Swift's stages a second:", ...line.slice(16).split(" · ").map((stage) => `  ${stage.trim()}`)];
      console.log(line);
      return true;
    },
    // A call from Swift to the page.
    relay(name, run) {
      if (inside !== "frame") return run();
      const start = performance.now();
      try {
        return run();
      } finally {
        second.page += performance.now() - start;
        second.calls++;
      }
    },
  };
}

/** The program ended, with its code. */
class Exit {
  constructor(code) { this.code = code; }
  get message() { return `the program ended with code ${this.code}`; }
}

/**
 * Loads the module at `url`, hands it the relay and the system interface, and runs its `main`. A driver hands
 * `imports` more modules, made from the page - `element(number)` and `numberOf(element)` of the relay's
 * elements, `text(pointer, length)` and `bytes(pointer, length)` of the module's memory - the program `args`
 * after its name, and hears the program's end in `exited(code)`. A driver whose imports wait for the browser -
 * `WebAssembly.Suspending` ones - says `suspends`: the program's `main` then runs as a promise, which each of them
 * sets aside while the page goes on.
 */
export async function start(url, { imports, args = [], exited, suspends = false } = {}) {
  const name = url.split("/").pop().split(/[.?]/)[0];
  const argv = [name, ...args];
  let memory, table, heard, frame, wake;
  let read = new Uint8Array(0);
  const probe = /[?&]STATEUI_PROBE=1(&|$)/.test(globalThis.location?.search ?? "") ? probing() : null;

  const bytes = (pointer, length) => new Uint8Array(memory.buffer, pointer, length);
  const text = (pointer, length) => decoder.decode(bytes(pointer, length));
  const data = () => new DataView(memory.buffer);

  // The DOM elements Swift made, by number, from 1; a number let go of is no element's again - what still names it,
  // an act that waited, reaches nothing - and its entry goes, so the table holds the elements standing alone.
  const elements = {};
  let made = 0;
  // What each window hears of the history by, under its listener's number: let go of as the window closes.
  // What the relay hung for each listener - on the page, or on an element - which `forget` takes off.
  const hung = new Map();
  const letGo = (listener, off) => {
    if (!hung.has(listener)) hung.set(listener, []);
    hung.get(listener).push(off);
  };
  const hang = (listener, target, type, handler, options) => {
    target.addEventListener(type, handler, options);
    letGo(listener, () => target.removeEventListener(type, handler, options));
  };
  // The listeners told as the screen's density turns - a window moved to another screen, the page zoomed: one query
  // of the density standing now, asked again after each turn.
  const densities = new Set();
  let density = null;
  const followDensity = () => {
    density = matchMedia(`(resolution: ${globalThis.devicePixelRatio || 1}dppx)`);
    density.addEventListener("change", () => {
      followDensity();
      for (const listener of [...densities]) heard(listener);
    }, { once: true });
  };
  const keep = (node) => {
    const number = ++made;
    elements[number] = node;
    return number;
  };
  let body = 0;

  // Apple's platforms take a shortcut with Command, the others with Control.
  const apple = /Mac|iPhone|iPad|iPod/.test(navigator.platform ?? navigator.userAgent ?? "");
  // The keys writing no character a shortcut names, by StateUI's numbers, as Swift names them (`name_keys`).
  let keyNumbers = {};
  // What a key writes as the user's layout has it, and the letter or digit of its place, each a code point - none
  // for neither - which Swift weighs (`WebKeys.character`).
  const keyCharacters = (key) => [
    [...key.key].length === 1 ? key.key.codePointAt(0) : 0,
    (/^Key([A-Z])$/.exec(key.code)?.[1] ?? /^Digit(\d)$/.exec(key.code)?.[1] ?? "").codePointAt(0) ?? 0,
  ];
  const dark = matchMedia("(prefers-color-scheme: dark)");
  const still = matchMedia("(prefers-reduced-motion: reduce)");
  const contrast = matchMedia("(prefers-contrast: more)");

  // The field the user last typed into, which an Edit menu's own entries act on: the menu took the focus to open.
  let typedLast = null;
  document.addEventListener?.("focusin", (event) => {
    const typed = 'input, textarea, [contenteditable]:not([contenteditable="false"])';
    if (event.target?.matches?.(typed)) typedLast = event.target;
  });

  // The keyboard in a strip of tabs and in a menu: the arrows go from one to the next - across a strip, as its words
  // run - Home and End to the first and the last; a tab is chosen as the keyboard reaches it, and the arrow towards a
  // submenu opens it.
  document.addEventListener?.("keydown", (key) => {
    const within = key.target?.closest?.('[role="tablist"], [role="menu"]');
    if (!within || key.altKey || key.ctrlKey || key.metaKey) return;
    const menu = within.getAttribute("role") === "menu";
    const rtl = getComputedStyle(within).direction === "rtl";
    const entry = ':is([role="menuitem"], [role="menuitemcheckbox"])';
    const items = [...within.children].filter((c) => c.matches(menu ? `${entry}:not(:disabled)` : '[role="tab"]'));
    const at = items.indexOf(key.target.closest(menu ? entry : '[role="tab"]'));
    const [back, on] = menu ? ["ArrowUp", "ArrowDown"] : rtl ? ["ArrowRight", "ArrowLeft"] : ["ArrowLeft", "ArrowRight"];
    if (menu && key.key === (rtl ? "ArrowLeft" : "ArrowRight") && key.target.getAttribute("aria-haspopup") === "menu") {
      key.preventDefault();
      key.target.click();
      const inner = [...within.querySelectorAll(":scope > .stateui-menu")].find((m) => m.matches(":popover-open"));
      inner?.querySelector(':is([role="menuitem"], [role="menuitemcheckbox"]):not(:disabled)')?.focus();
      return;
    }
    const next = key.key === on ? at + 1 : key.key === back ? (at < 0 ? items.length - 1 : at - 1)
      : key.key === "Home" ? 0 : key.key === "End" ? items.length - 1 : null;
    if (next === null || items.length === 0) return;
    key.preventDefault();
    const reached = items[(next + items.length) % items.length];
    reached.focus();
    if (!menu) reached.click();
  });

  // A button pressed leaves the keyboard with the field typed in.
  document.addEventListener?.("mousedown", (down) => {
    const held = document.activeElement;
    if (down.target?.closest?.("button") && held?.matches?.("input, textarea, [contenteditable]")) down.preventDefault();
  }, true);

  // What the event being heard carries, as Swift reads it: its clicks, where the pointer is in the listening element,
  // the pointer's number, where it is on the page, its kind and its button, a wheel's turn and whether a key turned it
  // into a pinch, a pinch's scale, the listening element's width and height, and whether a click on a label passes to
  // its control; and the event itself, which a pointer is captured by.
  let event = [0, 0, 0];
  let happening = null;
  // A web view hears the user over its frame's own document where it is of the page's site: the pointer, a click and
  // the wheel there, told where they are in the view, heard again after every load. Coming and going it hears itself.
  const framesForward = new Set(["pointerdown", "pointermove", "pointerup", "pointercancel", "click", "wheel"]);

  // Whether a held finger is opening a menu now. Its lift comes beside the menu - the finger went down before the
  // menu stood - which the browser's light dismiss would take for a touch beside it and close the menu at once: so
  // such a menu closes by the page's own light dismiss, on a press beside it or Escape, and is the browser's again
  // once closed.
  let heldOpen = false;
  // The fragment of the page's address as its history last moved, and whether that move moved it - a link into the
  // page, not the way back: decided once a move, before any listener of the page's history hears it.
  let fragment = location.hash;
  let fragmentMoved = false;
  globalThis.addEventListener?.("popstate", () => {
    fragmentMoved = location.hash !== fragment;
    fragment = location.hash;
  });
  const standsPastItsFinger = (menu) => {
    menu.popover = "manual";
    const beside = (down) => { if (!menu.contains(down.target)) menu.hidePopover(); };
    const escape = (key) => { if (key.key === "Escape") menu.hidePopover(); };
    document.addEventListener("pointerdown", beside, true);
    document.addEventListener("keydown", escape, true);
    menu.addEventListener("toggle", function gone(toggle) {
      if (toggle.newState !== "closed") return;
      document.removeEventListener("pointerdown", beside, true);
      document.removeEventListener("keydown", escape, true);
      menu.removeEventListener("toggle", gone);
      menu.popover = "auto";
    });
  };
  // `handler` hears `named` over the frame's own document of the web view `node`, once for each `key`, each event
  // told where it is on the page.
  const forwardFromFrame = (node, named, key, handler, options) => {
    const frame = node.querySelector(":scope > iframe");
    if (!frame) return;
    const listen = () => {
      let inner;
      try { inner = frame.contentDocument; } catch { return; }
      if (!inner) return;
      inner.stateuiHeard ??= new Set();
      const keyed = `${named} ${key}`;
      if (inner.stateuiHeard.has(keyed)) return;
      inner.stateuiHeard.add(keyed);
      inner.addEventListener(named, (happened) => {
        const box = frame.getBoundingClientRect();
        const told = new Proxy(happened, {
          get: (event, name) => name === "clientX" ? event.clientX + box.left
            : name === "clientY" ? event.clientY + box.top
            : typeof event[name] === "function" ? event[name].bind(event) : event[name],
        });
        handler(told);
      }, options);
    };
    frame.addEventListener("load", listen);
    listen();
  };

  // A click on a label beside its control, which the browser clicks the control for next.
  const passesToControl = (happened) => {
    const label = happened?.type === "click" ? happened.target?.closest?.("label") : null;
    const control = label?.control;
    return !!control && !control.disabled && !control.contains(happened.target);
  };
  // A wheel's turn in pixels, whatever the browser measured it in: lines of sixteen, or pages of the element.
  const pixels = (happened, delta, page) =>
    happened?.deltaMode === 1 ? delta * 16 : happened?.deltaMode === 2 ? delta * (page ?? 0) : delta;
  const hearing = (listener, element) => (happened) => {
    const box = element.getBoundingClientRect?.() ?? { left: 0, top: 0 };
    event = [happened?.detail ?? 0, (happened?.clientX ?? 0) - box.left, (happened?.clientY ?? 0) - box.top,
      happened?.pointerId ?? 0, happened?.clientX ?? 0, happened?.clientY ?? 0, pointers[happened?.pointerType] ?? pointers.mouse,
      happened?.button ?? 0, happened?.deltaY ?? 0, happened?.ctrlKey ? 1 : 0, happened?.scale ?? 1,
      box.width ?? 0, box.height ?? 0, passesToControl(happened) ? 1 : 0,
      pixels(happened, happened?.deltaX ?? 0, box.width), pixels(happened, happened?.deltaY ?? 0, box.height),
      happened?.timeStamp ?? 0, happened?.deltaMode ?? 0, happened?.deltaX ?? 0, happened?.rotation ?? 0,
      happened?.altKey ? 1 : 0, happened?.isComposing ? 1 : 0];
    happening = happened;
    try {
      heard(listener);
    } finally {
      happening = null;
    }
  };
  const resized = typeof ResizeObserver === "undefined" ? null
    : new ResizeObserver((entries) => { for (const entry of entries) entry.target.stateuiResized?.(); });
  const doubles = (into, values) => new Float64Array(memory.buffer, into, values.length).set(values);

  // The application's own scripts: what they answer the application, and what they tell it.
  const scripts = (globalThis.StateUI ??= { acts: {}, told: new Map(), tell(name, words) { this.told.set(name, String(words ?? "")); this.heard?.(name); } });
  const hearers = new Map();
  let answer = "";
  scripts.heard = (name) => {
    for (const listener of hearers.get(name) ?? []) {
      answer = scripts.told.get(name) ?? "";
      heard(listener);
    }
  };

  // The files the user opens and saves, each kept under a number of its own - a `File`, or the handle of one the
  // browser saved - and what a file's act tells its listener: event 1 kept, 0 broken, the words `file_words` reads.
  // A page a test drives (`stateui.holdsFiles`) shows no dialog and launches nothing: the test answers from files
  // of its own, as the user would choose them, and reads what was launched.
  const files = [null];
  let fileAnswer = "";
  let requestAnswer = { words: "", body: new Uint8Array(0) };
  // What stops each request under way, by the listener waiting for it.
  const requestsUnderWay = new Map();
  let dragWords = "";
  const settle = (listener, kept, words) => { fileAnswer = words; event = [kept ? 1 : 0]; heard(listener); };
  const chosen = (list) => list.map((file) => `${files.push(file) - 1}\u001F${file.name}`).join("\u001F");
  const testing = () => (globalThis.stateui?.holdsFiles ? globalThis.stateui : null);
  const fileOf = async (kept) => (kept?.getFile ? await kept.getFile() : kept);
  const typeOf = (name) => ({ txt: "text/plain", md: "text/markdown", html: "text/html", htm: "text/html",
    csv: "text/csv", json: "application/json", xml: "application/xml", pdf: "application/pdf", png: "image/png",
    jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", svg: "image/svg+xml" })[name.split(".").pop().toLowerCase()] ?? "";
  // The address of a file handed to the browser - saved, or opened in a window: the relay holds the last one alone,
  // which the browser may still be reading, and lets the one before go.
  let handed = null;
  const handOver = (file) => {
    if (handed) URL.revokeObjectURL(handed);
    return (handed = URL.createObjectURL(file));
  };
  // A window opened now, while the user's press lets the page open one, and sent to the file once it is read.
  const openWindow = (address) => {
    const opened = window.open("", "_blank");
    if (!opened) return false;
    opened.opener = null;
    Promise.resolve(address).then((where) => { opened.location.href = where; });
    return true;
  };

  const relay = {
    start: (heardIndex, frameIndex) => {
      heard = table.get(heardIndex);
      frame = table.get(frameIndex);
      if (probe) {
        const [hear, draw] = [heard, frame];
        heard = (listener) => probe.into("event", () => hear(listener));
        frame = (time) => probe.into("frame", () => draw(time));
      }
    },
    body: () => body || (body = keep(document.body)),
    name_keys: (numbers, count, words, length) => {
      const list = new Float64Array(memory.buffer, numbers, count).slice();
      keyNumbers = Object.fromEntries(text(words, length).split("\u0000").map((name, at) => [name, list[at]]));
    },
    create: (tag, length) => keep(document.createElement(text(tag, length))),
    create_vector: (tag, length) => keep(document.createElementNS("http://www.w3.org/2000/svg", text(tag, length))),
    read_shape_bounds: (element, into) => {
      let box = { x: 0, y: 0, width: 0, height: 0 };
      try { box = elements[element]?.getBBox?.() ?? box; } catch {}
      doubles(into, [box.x, box.y, box.width, box.height]);
    },
    // A number let go of is no element's again: what reaches it does nothing.
    release: (element) => {
      const node = elements[element];
      if (!node) return;
      resized?.unobserve(node);
      node.stateuiNearness?.unobserve(node);
      node.stateuiDocuments?.forEach((address) => URL.revokeObjectURL(address));
      node.remove();
      delete elements[element];
    },
    // The element holding the keyboard stays where it stands, as moving it would take the keyboard from it: what
    // stands between its index and it moves past it instead.
    insert: (parent, child, index) => {
      const into = elements[parent], node = elements[child];
      if (!into || !node) return;
      const at = into.children[index] ?? null;
      if (at === node) return;
      const holder = document.activeElement;
      if (at && holder && node.parentNode === into && node.contains(holder)
        && at.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) {
        const after = node.nextSibling;
        for (let each = at; each !== node;) {
          const next = each.nextSibling;
          into.insertBefore(each, after);
          each = next;
        }
        return;
      }
      into.insertBefore(node, at);
    },
    detach: (element) => elements[element]?.remove(),
    set_text: (element, pointer, length) => { if (elements[element]) elements[element].textContent = text(pointer, length); },
    set_attribute: (element, name, nameLength, value, valueLength) =>
      elements[element]?.setAttribute(text(name, nameLength), text(value, valueLength)),
    remove_attribute: (element, name, length) => elements[element]?.removeAttribute(text(name, length)),
    set_style: (element, name, nameLength, value, valueLength) => {
      if (!elements[element]) return;
      const style = elements[element].style, property = text(name, nameLength);
      valueLength > 0 ? style.setProperty(property, text(value, valueLength)) : style.removeProperty(property);
    },
    // Writing the same words again would move the user's caret to their end.
    set_value: (element, pointer, length) => {
      const field = elements[element], value = text(pointer, length);
      if (field && field.value !== value) field.value = value;
    },
    set_flag: (element, name, length, on) => { if (elements[element]) elements[element][text(name, length)] = on !== 0; },
    read_flag: (element, name, length) => (elements[element]?.[text(name, length)] ? 1 : 0),
    set_number: (element, name, length, value) => { if (elements[element]) elements[element][text(name, length)] = value; },
    read_number: (element, name, length) => Number(elements[element]?.[text(name, length)] ?? NaN),
    select: (element, start, length) => elements[element]?.setSelectionRange?.(start, start + length),
    read_value: (element) => (read = encoder.encode(elements[element]?.value ?? "")).length,
    copy_read: (into) => bytes(into, read.length).set(read),
    // What the relay hears for the host, read from one DOM event or more: `kind` a `WebHearing`.
    hear: (element, kind, listener) => {
      const node = elements[element];
      if (!node) return;
      if (kind === hearings.enter) {
        // An Enter that commits an input method's words is the method's: Safari tells it as the key of number 229.
        hang(listener, node, "keydown", (key) => {
          if (key.key === "Enter" && !key.isComposing && key.keyCode !== 229) heard(listener);
        });
      } else if (kind === hearings.within) {
        // The keyboard coming into the element or anything in it, or leaving it all: the event's one number 1 or 0.
        let within = node.contains(document.activeElement);
        const tell = (now) => {
          if (now === within) return;
          within = now;
          event = [now ? 1 : 0];
          heard(listener);
        };
        hang(listener, node, "focusin", () => tell(true));
        hang(listener, node, "focusout", (left) => tell(node.contains(left.relatedTarget)));
      } else if (kind === hearings.steps) {
        // A step up or down from the keyboard's arrows, its direction the event's one number.
        hang(listener, node, "keydown", (key) => {
          const by = key.key === "ArrowUp" ? 1 : key.key === "ArrowDown" ? -1 : 0;
          if (by === 0) return;
          key.preventDefault();
          event = [by];
          heard(listener);
        });
      } else if (kind === hearings.itemTap) {
        // A click on an item, but for one on a control inside it, which is the control's.
        hang(listener, node, "click", (click) => {
          const inner = click.target?.closest?.("button, input, select, textarea, a, label, [data-taps]");
          if (!inner || inner === node || !node.contains(inner)) hearing(listener, node)(click);
        });
      } else if (kind === hearings.press) {
        // A press on the element, the pointer the element's until it lets go: its phase - begun, moved, let go,
        // taken away - where it stands from the element's corner, the element's size, and whether a finger presses.
        // One begun on a control of another element inside - a button, a field, a view hearing its own taps - is
        // that control's; one on the element's own parts is the element's.
        let pressing = null;
        const tell = (phase, happened) => {
          const box = node.getBoundingClientRect();
          event = [phase, (happened.clientX ?? 0) - box.left, (happened.clientY ?? 0) - box.top, box.width, box.height,
            happened.pointerType === "touch" ? 1 : 0];
          heard(listener);
        };
        // A web view's own document of the page's site holds the press too.
        const on = (named, handler) => {
          hang(listener, node, named, handler);
          if (node.classList?.contains("stateui-frame")) forwardFromFrame(node, named, `press ${listener}`, handler);
        };
        // A scroll of what holds the element takes the press, as a browser scrolling a list under a finger may tell
        // no cancel of it - iOS's WebKit tells none.
        let downAt = null;
        const scrolled = (scroll) => {
          if (pressing === null || !scroll.target?.contains?.(node)) return;
          pressing = null;
          document.removeEventListener?.("scroll", scrolled, true);
          tell(3, downAt);
        };
        const done = () => {
          pressing = null;
          document.removeEventListener?.("scroll", scrolled, true);
        };
        on("pointerdown", (down) => {
          if (pressing !== null || (down.pointerType === "mouse" && down.button !== 0)) return;
          const inner = down.target?.closest?.("[data-control], [data-taps]");
          if (inner && inner !== node && node.contains(inner)) return;
          pressing = down.pointerId;
          downAt = down;
          document.addEventListener?.("scroll", scrolled, true);
          // A pointer the browser no longer holds cannot be captured: the press is told all the same.
          try { node.setPointerCapture?.(down.pointerId); } catch {}
          tell(0, down);
        });
        on("pointermove", (moved) => { if (moved.pointerId === pressing) tell(1, moved); });
        on("pointerup", (up) => {
          if (up.pointerId !== pressing) return;
          done();
          tell(2, up);
        });
        for (const named of ["pointercancel", "lostpointercapture"]) {
          on(named, (lost) => {
            if (lost.pointerId !== pressing) return;
            done();
            tell(3, lost);
          });
        }
      } else if (kind === hearings.closed) {
        // A popover the browser took down - a click beside it, Escape - or the program did.
        hang(listener, node, "toggle", (toggle) => { if (toggle.newState === "closed") heard(listener); });
      } else if (kind === hearings.dismiss) {
        // A modal dialog the user asked to close - Escape - closes only as the tree says.
        hang(listener, node, "cancel", (cancel) => { cancel.preventDefault(); heard(listener); });
      } else if (kind === hearings.key) {
        // A key going down before the element holding the keyboard has it, told as a shortcut's is: a view taking it
        // takes it there.
        hang(listener, node, "keydown", (key) => {
          // A menu standing over the page holds the keyboard: its keys are the menu's own, not the page's.
          if (key.target?.closest?.(".stateui-menu")) return;
          const named = keyNumbers[key.key] ?? 0;
          const [written, physical] = named === 0 ? keyCharacters(key) : [0, 0];
          if (named === 0 && written === 0 && physical === 0) return;
          event = [named, written, ((apple ? key.metaKey : key.ctrlKey) ? 1 : 0) | (key.shiftKey ? 2 : 0) | (key.altKey ? 4 : 0),
            physical];
          happening = key;
          try {
            heard(listener);
          } finally {
            happening = null;
          }
          // Taken, the key reaches nothing else: not the element holding the keyboard, not a shortcut.
          if (key.defaultPrevented) key.stopPropagation();
        }, true);
      } else if (kind === hearings.shortcut) {
        // A key pressed for a shortcut: the number of a key writing no character, or none; the character a letter's
        // or a digit's key writes, whatever is held; the keys held - the platform's own 1, Shift 2, Alt 4; and 1
        // where a field the user types into holds the keyboard.
        hang(listener, node, "keydown", (key) => {
          const named = keyNumbers[key.key] ?? 0;
          const [written, physical] = named === 0 ? keyCharacters(key) : [0, 0];
          if (named === 0 && written === 0 && physical === 0) return;
          const typing = key.target?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"])');
          event = [named, written, ((apple ? key.metaKey : key.ctrlKey) ? 1 : 0) | (key.shiftKey ? 2 : 0) | (key.altKey ? 4 : 0),
            typing ? 1 : 0, physical];
          happening = key;
          try {
            heard(listener);
          } finally {
            happening = null;
          }
        });
      } else if (kind === hearings.activate) {
        hang(listener, node, "keydown", (key) => {
          if ((key.key === "Enter" || key.key === " ") && key.target === node) { key.preventDefault(); heard(listener); }
        });
      }
    },
    // The DOM event `name` on the element. A wheel, a touch's move, a drag's start and Safari's gestures may be taken
    // from the page - a pinch on a trackpad zooms it, a touch a layout took pans it, a picture under it is dragged away
    // else.
    listen: (element, name, length, listener) => {
      const named = text(name, length), node = elements[element];
      if (!node) return;
      // Those whose default a listener may take: a scroll, a pinch, a drag, a link's following.
      const takes = named === "wheel" || named === "touchmove" || named === "dragstart" || named === "click"
        || named.startsWith("gesture");
      hang(listener, node, named, hearing(listener, node), { passive: !takes });
      if (node.classList?.contains("stateui-frame") && framesForward.has(named)) {
        forwardFromFrame(node, named, listener, hearing(listener, node), { passive: !takes });
      }
    },
    event_number: (index) => event[index] ?? 0,
    // The words the event being heard carries in its `detail` - a custom element's own.
    event_words: () => (read = encoder.encode(String(happening?.detail ?? ""))).length,
    // One watch a scroller for the elements in it coming near its view - within half its size - or going away: all
    // a frame saw in one call, how many and then each one's number and whether it came near.
    watch_nearness: (element, root, listener) => {
      const node = elements[element], scroller = elements[root];
      if (!node || !scroller || typeof IntersectionObserver === "undefined") return;
      scroller.stateuiNear ??= new IntersectionObserver((entries) => {
        const told = entries.flatMap((entry) => [entry.target.stateuiNumber, entry.isIntersecting ? 1 : 0]);
        event = [entries.length, ...told];
        heard(scroller.stateuiNearListener);
      }, { root: scroller, rootMargin: "50%" });
      scroller.stateuiNearListener = listener;
      node.stateuiNumber = element;
      node.stateuiNearness = scroller.stateuiNear;
      scroller.stateuiNear.observe(node);
    },
    // A popover over everything: under or beside the element `anchor` - beside for `side` - else at (x, y) in the
    // window, kept in the window whole.
    show_popover: (element, anchor, x, y, side) => {
      const menu = elements[element];
      if (!menu?.showPopover) return;
      if (heldOpen && !menu.matches(":popover-open")) standsPastItsFinger(menu);
      if (!menu.matches(":popover-open")) menu.showPopover();
      const box = menu.getBoundingClientRect(), around = elements[anchor]?.getBoundingClientRect?.();
      const rtl = getComputedStyle(menu).direction === "rtl";
      let left = x, top = y;
      if (around && side) {
        left = rtl ? around.left - box.width - 4 : around.right + 4;
        top = around.top - 6;
        if (left + box.width > innerWidth - 8 || left < 8) left = rtl ? around.right + 4 : around.left - box.width - 4;
      } else if (around) {
        left = rtl ? around.right - box.width : around.left;
        top = around.bottom + 6;
        if (left + box.width > innerWidth - 8) left = around.right - box.width;
        if (top + box.height > innerHeight - 8) top = around.top - box.height - 6;
      }
      menu.style.left = `${Math.max(8, Math.min(left, innerWidth - box.width - 8))}px`;
      menu.style.top = `${Math.max(8, Math.min(top, innerHeight - box.height - 8))}px`;
    },
    hide_popover: (element) => { try { elements[element]?.hidePopover?.(); } catch {} },
    // The user holds the element down - a finger, a pen or the mouse's main button - `hold` milliseconds no farther
    // than its reach from where it pressed: `fingerReach` for a finger, `reach` for the others. The held press's click
    // is the hold's: no tap of the element or of what holds it.
    listen_hold: (element, hold, fingerReach, reach, listener) => {
      const node = elements[element];
      if (!node) return;
      node.stateuiHold = hold;
      node.setAttribute("data-holds", "");
      let waiting = null, pressed = null, held = false;
      const stop = () => { clearTimeout(waiting); waiting = null; };
      // A web view's own document of the page's site holds the press too.
      const on = (named, handler, options) => {
        hang(listener, node, named, handler, options);
        if (node.classList?.contains("stateui-frame")) forwardFromFrame(node, named, `hold ${listener}`, handler, options);
      };
      on("pointerdown", (down) => {
        if (down.pointerType === "mouse" && down.button !== 0) return;
        stop();
        held = false;
        pressed = down;
        waiting = setTimeout(() => {
          waiting = null;
          held = true;
          hearing(listener, node)(down);
        }, node.stateuiHold);
      });
      on("pointermove", (moved) => {
        if (!waiting || moved.pointerId !== pressed?.pointerId) return;
        const far = pressed.pointerType === "touch" ? fingerReach : reach;
        if (Math.hypot(moved.clientX - pressed.clientX, moved.clientY - pressed.clientY) > far) stop();
      });
      on("pointerup", stop);
      on("pointercancel", stop);
      on("click", (clicked) => {
        if (!held) return;
        held = false;
        clicked.stopImmediatePropagation();
        clicked.preventDefault();
      }, { capture: true });
    },
    hold_time: (element, hold) => { if (elements[element]) elements[element].stateuiHold = hold; },
    // The user asks for the element's menu: its context menu, or a finger held `hold` milliseconds no farther than
    // `reach` from where it pressed.
    listen_menu: (element, hold, reach, listener) => {
      const node = elements[element];
      if (!node) return;
      // The hold is the menu's: no word of the view chosen by it, no callout of the browser's.
      node.setAttribute("data-holds-menu", "");
      hang(listener, node, "contextmenu", (asked) => { asked.preventDefault(); hearing(listener, node)(asked); });
      let held = null, pressed = null;
      hang(listener, node, "pointerdown", (down) => {
        if (down.pointerType !== "touch") return;
        clearTimeout(held);
        pressed = down;
        held = setTimeout(() => {
          heldOpen = true;
          try { hearing(listener, node)(down); } finally { heldOpen = false; }
        }, hold);
      });
      hang(listener, node, "pointerup", () => clearTimeout(held));
      hang(listener, node, "pointercancel", () => clearTimeout(held));
      hang(listener, node, "pointermove", (moved) => {
        if (moved.pointerId !== pressed?.pointerId) return;
        if (Math.hypot(moved.clientX - pressed.clientX, moved.clientY - pressed.clientY) > reach) clearTimeout(held);
      });
    },
    // A frame shows an address, or a document written in place at an address of the page's own made for it - of the
    // page's own site, so it can be reached, and a step in the frame's history as any page shown is: the browser
    // takes a `srcdoc` written again in place of the one before. The frame holds each such address while its
    // history may lead back to it, and lets them go with itself.
    frame_show: (element, kind, words, length) => {
      const frame = elements[element];
      if (!frame) return 0;
      frame.removeAttribute("srcdoc");
      if (kind === frameSources.address) {
        frame.src = text(words, length);
        return 0;
      }
      const address = URL.createObjectURL(new Blob([text(words, length)], { type: "text/html" }));
      (frame.stateuiDocuments ??= []).push(address);
      frame.src = address;
      return (read = encoder.encode(address)).length;
    },
    // What the page can know of a frame's document: 1 it is of the page's own site, 2 it can go back, 4 forward.
    frame_state: (element) => {
      try {
        const inside = elements[element]?.contentWindow;
        if (!inside?.document) return 0;
        return 1 | (inside.navigation?.canGoBack ? 2 : 0) | (inside.navigation?.canGoForward ? 4 : 0);
      } catch {
        return 0;
      }
    },
    // The frame's document's address, where it is of the page's own site.
    frame_address: (element) => {
      try { return (read = encoder.encode(elements[element]?.contentWindow?.location?.href ?? "")).length; } catch { return 0; }
    },
    // A step of the frame's own - back, forward, the page again - where its document is of the page's site.
    frame_step: (element, step) => {
      try {
        const inside = elements[element].contentWindow;
        if (!inside.document) return 0;
        if (step === frameSteps.back) inside.history.back();
        else if (step === frameSteps.forward) inside.history.forward();
        else inside.location.reload();
        return 1;
      } catch {
        return 0;
      }
    },
    // A script run in the frame's document, its value as JSON; -1 where the document is of another site.
    frame_evaluate: (element, script, length) => {
      try {
        const inside = elements[element].contentWindow;
        if (!inside.document) return -1;
        const value = inside.eval(text(script, length));
        return (read = encoder.encode(JSON.stringify(value) ?? "")).length;
      } catch {
        return -1;
      }
    },
    // One entry of the page's own in the browser's history, which the browser's way back takes away.
    push_history: () => {
      history.pushState({ stateui: true }, "");
      fragment = location.hash;
    },
    // Back over the page's own entry alone - never off the site from one the page did not put there: 1 where it went.
    back_history: () => (history.state?.stateui ? (history.back(), 1) : 0),
    // The browser's history moved: the way back, unless the fragment moved with it - a link into the page
    // (`listen_links`), whose entry is no page of the host's.
    listen_history: (listener) => hang(listener, window, "popstate", () => { if (!fragmentMoved) heard(listener); }),
    // Takes off what the relay hung for `listener`.
    forget: (listener) => {
      for (const off of hung.get(listener) ?? []) off();
      hung.delete(listener);
    },
    page_state: () => (document.visibilityState === "visible" ? 1 : 0) | (document.hasFocus() ? 2 : 0),
    listen_page: (changed, leaving) => {
      for (const name of ["focus", "blur"]) hang(changed, window, name, () => heard(changed));
      hang(changed, document, "visibilitychange", () => heard(changed));
      // A page the browser keeps to come back to (`persisted`) is hidden, not gone, and stands again as it shows.
      hang(leaving, window, "pagehide", (left) => heard(left.persisted ? changed : leaving));
      hang(changed, window, "pageshow", (shown) => { if (shown.persisted) heard(changed); });
      // What the page stands as when it starts, told once, after its window is made.
      setTimeout(() => heard(changed), 0);
    },
    // A link into the application: the page's address where it carries a fragment - as the page starts, after its
    // window is made, and each time the fragment changes; `page_link` is that address, read as `copy_read` reads.
    listen_links: (listener) => {
      hang(listener, window, "hashchange", () => heard(listener));
      setTimeout(() => heard(listener), 0);
    },
    page_link: () => (read = encoder.encode(location.hash.length > 1 ? location.href : "")).length,
    // An act of the application's scripts, its promise's words told to `listener` - event 1 kept, 0 broken.
    call_script: (name, length, words, wordsLength, listener) => {
      const named = text(name, length), given = text(words, wordsLength);
      Promise.resolve()
        .then(() => {
          const act = scripts.acts[named];
          if (typeof act !== "function") throw new Error(`the page's scripts answer no act named ${named}`);
          return act(given);
        })
        .then((value) => { answer = value === undefined || value === null ? "" : String(value); event = [1]; heard(listener); },
          (error) => { answer = String(error?.message ?? error); event = [0]; heard(listener); });
    },
    script_words: () => (read = encoder.encode(answer)).length,
    listen_script: (name, length, listener) => {
      const named = text(name, length);
      if (!hearers.has(named)) hearers.set(named, []);
      hearers.get(named).push(listener);
      if (scripts.told.has(named)) setTimeout(() => { answer = scripts.told.get(named); heard(listener); }, 0);
    },
    call_method: (element, name, length) => {
      try { elements[element]?.[text(name, length)]?.(); } catch (error) { console.error(error); }
    },
    show_modal: (element) => { const dialog = elements[element]; if (dialog && !dialog.open) dialog.showModal?.(); },
    close_modal: (element) => elements[element]?.close?.(),
    scroll_into_view: (element, anchor) => {
      const place = ["start", "center", "end", "nearest"][anchor] ?? "nearest";
      elements[element]?.scrollIntoView?.({ block: place, inline: place });
    },
    // The pointer the event being heard is of goes on telling the element, wherever it moves, until it lets go.
    capture_pointer: (element) => {
      if (happening?.pointerId === undefined) return;
      try { elements[element]?.setPointerCapture?.(happening.pointerId); } catch {}
    },
    // The event being heard does what the page would do with it no more: scroll, zoom, select.
    take_event: () => happening?.preventDefault?.(),
    apple: () => (apple ? 1 : 0),
    is_laid_out: (element) => {
      const node = elements[element];
      return node?.isConnected && node.getClientRects().length > 0 ? 1 : 0;
    },
    // Whether a bar's buttons and title stand over one another or beyond its edges, as the user would see them crowd.
    crowded: (element) => {
      const bar = elements[element];
      if (!bar?.isConnected || !bar.querySelectorAll || typeof getComputedStyle !== "function") return 0;
      const box = bar.getBoundingClientRect();
      const parts = [...bar.querySelectorAll("button, .stateui-bar-title")]
        .filter((part) => !part.parentElement.closest("button") && !part.closest("[hidden]")
          && getComputedStyle(part).visibility !== "hidden")
        .map((part) => part.getBoundingClientRect()).filter((r) => r.width > 0)
        .sort((a, b) => a.left - b.left);
      return parts.some((r, i) => r.left < box.left - 0.5 || r.right > box.right + 0.5
        || (i > 0 && r.left < parts[i - 1].right - 0.5)) ? 1 : 0;
    },
    // From where it stood to its place, on the sidebar's slide (`--stateui-slide`): a bar's button moving between
    // the bar's parts as the sidebar comes or goes.
    slide_from: (element, dx, dy) => {
      const node = elements[element];
      if (!node?.animate || still.matches || (dx === 0 && dy === 0)) return;
      const [time, ...curve] = getComputedStyle(node).getPropertyValue("--stateui-slide").trim().split(" ");
      const duration = time?.endsWith("ms") ? parseFloat(time) : parseFloat(time) * 1000;
      node.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: "none" }],
        { duration: duration || 320, easing: curve.join(" ") || "ease" });
    },
    // Out of the flow of its parent, as the style sheet stands it: placed over its siblings, not beside them.
    stands_over: (element) => {
      const node = elements[element];
      return node && getComputedStyle(node).position === "absolute" ? 1 : 0;
    },
    observe_size: (element, listener) => {
      const node = elements[element];
      if (!node) return;
      node.stateuiResized = () => heard(listener);
      resized?.observe(node);
    },
    read_box: (element, into) => {
      const box = elements[element]?.getBoundingClientRect?.() ?? { x: 0, y: 0, width: 0, height: 0 };
      doubles(into, [box.x, box.y, box.width, box.height]);
    },
    read_size: (element, into) => doubles(into, [elements[element]?.offsetWidth ?? 0, elements[element]?.offsetHeight ?? 0]),
    // The room a view's words take as they stand: their lines' extent, with its padding and border around them.
    read_natural: (element, into) => {
      const node = elements[element];
      if (!node) return doubles(into, [0, 0]);
      const range = document.createRange();
      range.selectNodeContents(node);
      const words = range.getBoundingClientRect(), style = getComputedStyle(node);
      const sum = (sides) => sides.reduce((total, side) => total + (parseFloat(style[side]) || 0), 0);
      doubles(into, [
        words.width + sum(["paddingLeft", "paddingRight", "borderLeftWidth", "borderRightWidth"]),
        words.height + sum(["paddingTop", "paddingBottom", "borderTopWidth", "borderBottomWidth"])]);
    },
    // A child's place in its layout from the layout's own layout, never its drawing: a transform moves no place. Its
    // size is the browser's own to a fraction of a pixel - words given a whole pixel less break onto a second line.
    read_places: (pairs, count, into) => {
      if (count === 0) return;
      const list = new Int32Array(memory.buffer, pairs, count * 2);
      const read = new Float64Array(count * 4).fill(NaN);
      const size = (element) => {
        const style = getComputedStyle(element), width = parseFloat(style.width), height = parseFloat(style.height);
        if (Number.isNaN(width) || Number.isNaN(height)) return [element.offsetWidth, element.offsetHeight];
        return [width, height];
      };
      for (let index = 0; index < count; index++) {
        const layout = elements[list[index * 2]], child = elements[list[index * 2 + 1]];
        if (!layout || !child || !layout.offsetParent) continue;
        if (child === layout) {
          read.set([0, 0, ...size(layout)], index * 4);
        } else if (child.offsetParent !== undefined) {
          if (!child.offsetParent) continue;
          const inside = child.offsetParent === layout;
          read.set([child.offsetLeft - (inside ? 0 : layout.offsetLeft), child.offsetTop - (inside ? 0 : layout.offsetTop),
            ...size(child)], index * 4);
        } else {
          const box = child.getBoundingClientRect(), room = layout.getBoundingClientRect();
          if (box.width === 0 && box.height === 0) continue;
          read.set([box.left - room.left, box.top - room.top, box.width, box.height], index * 4);
        }
      }
      new Float64Array(memory.buffer, into, count * 4).set(read);
    },
    read_scroll: (element, into) => doubles(into, [elements[element]?.scrollLeft ?? 0, elements[element]?.scrollTop ?? 0]),
    scroll_to: (element, x, y) => elements[element]?.scrollTo?.({ left: x, top: y, behavior: "instant" }),
    set_title: (pointer, length) => { document.title = text(pointer, length); },
    // The page's color under its window, kept for its next start - index.html wears it before the first paint.
    keep_page_color: (pointer, length) => {
      const color = text(pointer, length), page = document.documentElement?.style;
      if (color) page?.setProperty("--stateui-page", color); else page?.removeProperty("--stateui-page");
      try {
        const key = "stateui.page-color." + (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
        if (color) localStorage.setItem(key, color); else localStorage.removeItem(key);
      } catch {}
    },
    site_name: () => (read = encoder.encode(document.querySelector('meta[name="application-name"]')?.content ?? "")).length,
    request_frame: () => requestAnimationFrame((time) => frame(time)),
    wake_after: (milliseconds) => {
      clearTimeout(wake);
      wake = setTimeout(() => heard(0), milliseconds);
    },
    now: () => performance.now(),
    prefers_dark: () => (dark.matches ? 1 : 0),
    // The accent the page draws its controls in - the host's own, or the application's where it gave one - as
    // ARGB, in one number.
    accent_color: () => {
      const probe = document.createElement("span");
      probe.style.color = "var(--stateui-accent)";
      document.body.append(probe);
      const channels = getComputedStyle(probe).color.match(/[\d.]+/g)?.map(Number) ?? [0, 117, 255, 1];
      probe.remove();
      const [red, green, blue, alpha = 1] = channels;
      return ((Math.round(alpha * 255) << 24) | (red << 16) | (green << 8) | blue) | 0;
    },
    // The application's accent over the host's own, as ARGB; none gives the host's back.
    use_accent_color: (argb, has) => {
      const root = document.documentElement;
      if (!has) return root.style.removeProperty("--stateui-accent");
      const channel = (shift) => (argb >>> shift) & 255;
      root.style.setProperty("--stateui-accent", `rgb(${channel(16)} ${channel(8)} ${channel(0)} / ${channel(24) / 255})`);
    },
    use_color_scheme: (scheme) => {
      const root = document.documentElement;
      if (root) root.style.colorScheme = scheme === schemes.light ? "light" : scheme === schemes.dark ? "dark" : "";
    },
    listen_appearance: (listener) => hang(listener, dark, "change", () => heard(listener)),
    // The user's locale as the browser has it, a zero byte apart: the language the user put first, the same filled
    // out with its likeliest script and region, the local zone, that language's hour cycle and first day of the week
    // (1 Monday to 7 Sunday) and its writing's direction - "" for what the browser does not say - then each of the
    // user's languages; `copy_read` reads them.
    locale_words: () => {
      const languages = navigator.languages?.length ? [...navigator.languages] : [navigator.language || "en-US"];
      let filled = languages[0], cycle = "", first = "", direction = "";
      try {
        const locale = new Intl.Locale(languages[0]);
        filled = locale.maximize().toString();
        cycle = new Intl.DateTimeFormat(languages[0], { hour: "numeric" }).resolvedOptions().hourCycle ?? "";
        first = String((locale.getWeekInfo?.() ?? locale.weekInfo)?.firstDay ?? "");
        direction = (locale.getTextInfo?.() ?? locale.textInfo)?.direction ?? "";
      } catch {}
      const zone = Intl.DateTimeFormat().resolvedOptions().timeZone ?? "";
      return (read = encoder.encode([languages[0], filled, zone, cycle, first, direction, ...languages].join("\u0000")))
        .length;
    },
    listen_locale: (listener) => hang(listener, window, "languagechange", () => heard(listener)),
    listen_density: (listener) => {
      if (!density) followDensity();
      densities.add(listener);
      letGo(listener, () => densities.delete(listener));
    },
    reduces_motion: () => (still.matches ? 1 : 0),
    prefers_more_contrast: () => (contrast.matches ? 1 : 0),
    listen_accessibility: (listener) => {
      for (const query of [still, contrast]) hang(listener, query, "change", () => heard(listener));
    },
    draw_canvas: (element, numbers, count, words, length) => {
      const canvas = elements[element];
      const g = canvas?.getContext?.("2d");
      if (!g) return;
      // An empty list's address need not stand on a double's boundary, which a view of none still asks for.
      const list = count > 0 ? new Float64Array(memory.buffer, numbers, count).slice() : new Float64Array(0);
      const texts = length > 0 ? text(words, length).split("\u0000") : [];
      const ratio = globalThis.devicePixelRatio || 1;
      const width = canvas.clientWidth, height = canvas.clientHeight;
      if (canvas.width !== Math.round(width * ratio)) canvas.width = Math.round(width * ratio);
      if (canvas.height !== Math.round(height * ratio)) canvas.height = Math.round(height * ratio);
      g.setTransform(ratio, 0, 0, ratio, 0, 0);
      g.clearRect(0, 0, width, height);
      let at = 0;
      const next = () => list[at++];
      const color = () => `rgb(${next()} ${next()} ${next()} / ${next()})`;
      while (at < list.length) {
        switch (next()) {
          case operations.save: g.save(); break;
          case operations.restore: g.restore(); break;
          case operations.translate: g.translate(next(), next()); break;
          case operations.rotate: g.rotate(next()); break;
          case operations.scale: g.scale(next(), next()); break;
          case operations.beginPath: g.beginPath(); break;
          case operations.move: g.moveTo(next(), next()); break;
          case operations.line: g.lineTo(next(), next()); break;
          case operations.cubic: g.bezierCurveTo(next(), next(), next(), next(), next(), next()); break;
          case operations.quadratic: g.quadraticCurveTo(next(), next(), next(), next()); break;
          case operations.close: g.closePath(); break;
          case operations.fill: g.fillStyle = color(); g.fill(); break;
          case operations.stroke: g.strokeStyle = color(); g.lineWidth = next(); g.stroke(); break;
          case operations.text: {
            const words = texts[next()] ?? "", x = next(), y = next(), w = next(), h = next();
            const size = next(), height = next();
            g.fillStyle = color();
            const edge = next(), anchor = next(), down = next();
            write(g, words, x, y, w, h, size, height, edge, anchor, down);
            break;
          }
          default: at = list.length;
        }
      }
    },
    local_time: (into) => {
      const now = new Date();
      doubles(into, [now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds()]);
    },
    local_zone: () => (read = encoder.encode(Intl.DateTimeFormat().resolvedOptions().timeZone ?? "")).length,
    // The offset at the day's noon, read from the zone's own name for it: "GMT+05:30", or "GMT" for none.
    utc_offset: (zone, length, year, month, day) => {
      try {
        const named = length > 0 ? text(zone, length) : undefined;
        // A day at its noon, today as it stands now.
        const noon = year > 0 ? Date.UTC(year, month - 1, day, 12) : Date.now();
        const words = new Intl.DateTimeFormat("en-US", { timeZone: named, timeZoneName: "longOffset" })
          .formatToParts(noon).find((part) => part.type === "timeZoneName")?.value ?? "GMT";
        const found = /GMT([+-])(\d{1,2})(?::(\d{2}))?/.exec(words);
        return found ? (found[1] === "-" ? -1 : 1) * (Number(found[2]) * 60 + Number(found[3] ?? 0)) : 0;
      } catch {
        return NaN;
      }
    },
    // The words and the link offered to the browser's share sheet; a page a test drives holds it for the test to
    // answer (`stateui.share`).
    share: (words, wordsLength, link, linkLength, listener) => {
      const offered = { text: wordsLength < 0 ? undefined : text(words, wordsLength),
        url: linkLength < 0 ? undefined : text(link, linkLength) };
      const test = testing();
      if (test) {
        test.share = { offered: [offered.text, offered.url].filter((each) => each !== undefined).join("\n"),
          answer: (shared) => settle(listener, true, shared ? "1" : "0") };
        return;
      }
      if (!navigator.share) return settle(listener, false, "this browser has no share sheet");
      navigator.share(offered).then(() => settle(listener, true, "1"), (error) => error?.name === "AbortError"
        ? settle(listener, true, "0") : settle(listener, false, String(error?.message ?? error)));
    },
    clipboard_write: (pointer, length) => {
      navigator.clipboard?.writeText?.(text(pointer, length))?.catch?.(() => {});
    },
    clipboard_read: (listener) => {
      if (!navigator.clipboard?.readText) return settle(listener, false, "this page has no clipboard - one served over https has");
      navigator.clipboard.readText().then((words) => settle(listener, true, words),
        (error) => settle(listener, false, String(error?.message ?? error)));
    },
    announce: (pointer, length) => {
      let region = document.getElementById("stateui-announcer");
      if (!region) {
        region = document.createElement("div");
        region.id = "stateui-announcer";
        region.className = "stateui-announcer";
        region.setAttribute("aria-live", "polite");
        region.setAttribute("role", "status");
        document.body.append(region);
      }
      region.textContent = "";
      setTimeout(() => { region.textContent = text(pointer, length); }, 50);
    },
    blur_field: () => {
      const held = document.activeElement;
      if (!held || !held.matches?.("input, textarea, [contenteditable]")) return 0;
      held.blur();
      return 1;
    },
    edit: (command) => {
      const field = typedLast;
      if (!field?.isConnected) return;
      field.focus();
      if (command === 4) {
        // The browser reads the clipboard only through its own permission: what it gives lands where the caret is.
        navigator.clipboard?.readText?.()
          .then((words) => { field.focus(); document.execCommand("insertText", false, words); })
          .catch(() => {});
      } else if (command === 6) {
        field.select?.();
      } else {
        document.execCommand(["undo", "redo", "cut", "copy", "", "delete"][command]);
      }
    },
    focus: (element) => {
      const node = elements[element];
      if (!node) return 0;
      const target = node.matches?.("button, input, select, textarea, [tabindex]") ? node
        : node.querySelector?.("button, input, select, textarea, [tabindex]") ?? node;
      target.focus?.();
      return node.contains?.(document.activeElement) ? 1 : 0;
    },
    unfocus: (element) => {
      const node = elements[element];
      if (node?.contains?.(document.activeElement)) document.activeElement.blur();
    },
    holds_focus: (element) => (elements[element]?.contains?.(document.activeElement) ? 1 : 0),
    stored: (key, length) => {
      try { return (read = encoder.encode(localStorage.getItem(text(key, length)) ?? "")).length; } catch { return 0; }
    },
    store: (key, keyLength, words, length) => {
      try { localStorage.setItem(text(key, keyLength), text(words, length)); return 1; } catch { return 0; }
    },
    // One file to open, or several, of the extensions `accept` lists - any where it lists none.
    open_files: (several, accept, length, listener) => {
      const extensions = text(accept, length);
      const test = testing();
      if (test) {
        test.fileDialog = { kind: "open", answer: (names) =>
          settle(listener, true, chosen(names.map((name) => test.files.get(name)).filter(Boolean))) };
        return;
      }
      const input = document.createElement("input");
      input.type = "file";
      input.multiple = several !== 0;
      if (extensions) input.accept = extensions;
      input.addEventListener("change", () => settle(listener, true, chosen([...input.files])));
      input.addEventListener("cancel", () => settle(listener, true, ""));
      input.click();
    },
    // A place to save `contents` in, `name` suggested and the kinds offered - each its caption, then its extensions:
    // the browser's save dialog where it has one, else a download of the file.
    save_file: (name, nameLength, kinds, kindsLength, contents, length, listener) => {
      const named = text(name, nameLength);
      const offered = text(kinds, kindsLength).split("\u001E").filter(Boolean).map((kind) => kind.split("\u001F"))
        .map(([caption, extensions]) => ({ description: caption,
          accept: { "application/octet-stream": extensions.split(" ").filter(Boolean).map((each) => "." + each) } }));
      const saved = bytes(contents, length).slice();
      const test = testing();
      if (test) {
        test.fileDialog = { kind: "save", answer: (names) => {
          if (names.length === 0) return settle(listener, true, "");
          const file = new File([saved], names[0], { type: typeOf(names[0]) });
          test.files.set(names[0], file);
          settle(listener, true, chosen([file]));
        } };
        return;
      }
      if (typeof showSaveFilePicker === "function") {
        showSaveFilePicker({ suggestedName: named || undefined, types: offered.length ? offered : undefined })
          .then(async (handle) => {
            const stream = await handle.createWritable();
            await stream.write(saved);
            await stream.close();
            settle(listener, true, chosen([handle]));
          }, (error) => (error?.name === "AbortError" ? settle(listener, true, "")
            : settle(listener, false, String(error?.message ?? error))));
        return;
      }
      const file = new File([saved], named || "download", { type: typeOf(named) });
      const link = document.createElement("a");
      link.href = handOver(file);
      link.download = file.name;
      link.click();
      setTimeout(() => settle(listener, true, chosen([file])), 0);
    },
    // The file whole, or its first bytes where a most is given - a slice reads nothing past it: event 1 and its
    // length, its bytes read by `copy_read`.
    read_file: (file, maximum, listener) => {
      fileOf(files[file])
        .then((found) => {
          if (!found) throw new Error("the page holds no such file");
          return (maximum < 0 ? found : found.slice(0, maximum)).arrayBuffer();
        })
        .then((buffer) => { read = new Uint8Array(buffer); event = [1, read.length]; heard(listener); },
          (error) => settle(listener, false, String(error?.message ?? error)));
    },
    file_words: () => (read = encoder.encode(fileAnswer)).length,
    // A request through the browser's own `fetch`, its address read against the page's: event 1 and the status,
    // the headers and the body kept for `request_words` and `request_body`; 0 and why where no answer came.
    send_request: (address, addressLength, method, methodLength, headers, headersLength, body, bodyLength, listener) => {
      const named = text(headers, headersLength).split("\u001F");
      const asked = new Headers();
      for (let index = 0; index + 1 < named.length; index += 2) asked.append(named[index], named[index + 1]);
      const sent = bodyLength > 0 ? bytes(body, bodyLength).slice() : undefined;
      const stopping = new AbortController();
      requestsUnderWay.set(listener, stopping);
      fetch(text(address, addressLength),
        { method: text(method, methodLength), headers: asked, body: sent, signal: stopping.signal })
        .finally(() => requestsUnderWay.delete(listener))
        .then(async (response) => {
          const said = [];
          response.headers.forEach((value, name) => said.push(name, value));
          requestAnswer = { words: said.join("\u001F"), body: new Uint8Array(await response.arrayBuffer()) };
          event = [1, response.status];
          heard(listener);
        }, (error) => {
          requestAnswer = { words: String(error?.message ?? error), body: new Uint8Array(0) };
          event = [0];
          heard(listener);
        });
    },
    cancel_request: (listener) => requestsUnderWay.get(listener)?.abort(),
    request_words: () => (read = encoder.encode(requestAnswer.words)).length,
    request_body: () => (read = requestAnswer.body).length,
    // The file, or the address, opened in a window of its own; event 1 where the browser opened one.
    launch_file: (file, listener) => {
      const kept = files[file];
      const test = testing();
      let taken = !!kept;
      if (kept && test) test.launched.push(kept.name);
      else if (kept) taken = openWindow(fileOf(kept).then(handOver));
      setTimeout(() => { event = [taken ? 1 : 0]; heard(listener); }, 0);
    },
    // An address whose scheme Swift let through (`WebFileToolkit.launches`).
    launch_address: (address, length, listener) => {
      const target = text(address, length);
      let taken = true;
      const test = testing();
      if (test) test.launched.push(target);
      else taken = openWindow(target);
      setTimeout(() => { event = [taken ? 1 : 0]; heard(listener); }, 0);
    },
    // A drag: the element dragged carries `words` as plain text where `draggable`; it takes a drag of plain text where
    // `takes`, and of files from the system where `files` - its entering and leaving counted over its children - each
    // told to `listener`: event 0 started, 1 ended, 2 over, 3 left, 4 dropped words, 5 dropped files kept as the
    // relay keeps a chosen file, `drag_words` reading the words or the files.
    offer_drag: (element, words, length, draggable, takes, takesFiles, listener) => {
      const node = elements[element];
      if (!node) return;
      node.stateuiDragOff?.();
      const carried = draggable ? text(words, length) : null;
      const tell = (kind, said = "") => { dragWords = said; event = [kind]; heard(listener); };
      const handlers = {};
      if (carried !== null) {
        node.setAttribute("draggable", "true");
        handlers.dragstart = (start) => {
          start.stopPropagation();
          start.dataTransfer.setData("text/plain", carried);
          start.dataTransfer.effectAllowed = "copy";
          tell(0);
        };
        handlers.dragend = (end) => { end.stopPropagation(); tell(1); };
      } else {
        // Nothing of the browser's own either: a picture's or a link's drag would take the pointer away.
        node.setAttribute("draggable", "false");
      }
      if (takes || takesFiles) {
        let within = 0;
        const holds = (drag, type) => [...(drag.dataTransfer?.types ?? [])].includes(type);
        const taken = (drag) => (takesFiles && holds(drag, "Files")) || (takes && holds(drag, "text/plain"));
        handlers.dragenter = (drag) => {
          if (!taken(drag)) return;
          drag.preventDefault();
          drag.stopPropagation();
          if (within++ === 0) tell(2);
        };
        handlers.dragover = (drag) => {
          if (!taken(drag)) return;
          drag.preventDefault();
          drag.stopPropagation();
          drag.dataTransfer.dropEffect = "copy";
          tell(2);
        };
        handlers.dragleave = (drag) => {
          if (!taken(drag)) return;
          drag.stopPropagation();
          if (--within <= 0) { within = 0; tell(3); }
        };
        handlers.drop = (drag) => {
          drag.preventDefault();
          drag.stopPropagation();
          within = 0;
          if (takesFiles && drag.dataTransfer.files.length > 0) tell(5, chosen([...drag.dataTransfer.files]));
          else tell(4, drag.dataTransfer.getData("text/plain"));
        };
      }
      for (const [name, handler] of Object.entries(handlers)) node.addEventListener(name, handler);
      node.stateuiDragOff = () => {
        for (const [name, handler] of Object.entries(handlers)) node.removeEventListener(name, handler);
      };
    },
    drag_words: () => (read = encoder.encode(dragWords)).length,
    touch_screen: () => (matchMedia("(pointer: coarse)").matches ? Math.min(screen.width, screen.height) : 0),
  };
  if (probe) {
    for (const [name, run] of Object.entries(relay)) relay[name] = (...given) => probe.relay(name, () => run(...given));
  }

  // What the program reads as its environment: the page address's STATEUI_ parameters, ?STATEUI_TALLY=1.
  const environment = [...new URLSearchParams(location.search)]
    .filter(([key]) => key.startsWith("STATEUI_")).map(([key, value]) => `${key}=${value}`);
  const strings = (list, pointers, buffer) => {
    for (const each of list) {
      const encoded = encoder.encode(each + "\0");
      data().setUint32(pointers, buffer, true);
      bytes(buffer, encoded.length).set(encoded);
      pointers += 4;
      buffer += encoded.length;
    }
    return 0;
  };
  const sizes = (list, count, size) => {
    data().setUint32(count, list.length, true);
    data().setUint32(size, list.reduce((sum, each) => sum + encoder.encode(each).length + 1, 0), true);
    return 0;
  };

  // What the program writes to its standard output and error, a line at a time to the console.
  const lines = { 1: "", 2: "" };
  const say = (descriptor, written) => {
    lines[descriptor] += written;
    const parts = lines[descriptor].split("\n");
    lines[descriptor] = parts.pop();
    for (const line of parts) {
      if (probe?.stages(line)) continue;
      descriptor === 2 ? console.error(line) : console.log(line);
    }
  };

  const system = {
    args_sizes_get: (count, size) => sizes(argv, count, size),
    args_get: (pointers, buffer) => strings(argv, pointers, buffer),
    environ_sizes_get: (count, size) => sizes(environment, count, size),
    environ_get: (pointers, buffer) => strings(environment, pointers, buffer),
    clock_res_get: (clock, into) => { data().setBigUint64(into, 1000n, true); return 0; },
    clock_time_get: (clock, precision, into) => {
      const milliseconds = clock === 0 ? Date.now() : performance.now();
      data().setBigUint64(into, BigInt(Math.round(milliseconds * 1e6)), true);
      return 0;
    },
    fd_write: (descriptor, vectors, count, written) => {
      if (descriptor !== 1 && descriptor !== 2) return EBADF;
      let total = 0;
      for (let index = 0; index < count; index++) {
        const pointer = data().getUint32(vectors + index * 8, true), length = data().getUint32(vectors + index * 8 + 4, true);
        say(descriptor, text(pointer, length));
        total += length;
      }
      data().setUint32(written, total, true);
      return 0;
    },
    fd_read: (descriptor, vectors, count, read) => {
      if (descriptor !== 0) return EBADF;
      data().setUint32(read, 0, true);
      return 0;
    },
    // The standard streams are characters, and descriptor 3 the one directory: the root, empty.
    fd_fdstat_get: (descriptor, into) => {
      if (descriptor > ROOT) return EBADF;
      bytes(into, 24).fill(0);
      data().setUint8(into, descriptor === ROOT ? DIRECTORY : CHARACTERS);
      data().setBigUint64(into + 8, ~0n & 0xffffffffffffffffn, true);
      data().setBigUint64(into + 16, ~0n & 0xffffffffffffffffn, true);
      return 0;
    },
    fd_filestat_get: (descriptor, into) => {
      if (descriptor > ROOT) return EBADF;
      bytes(into, 64).fill(0);
      data().setUint8(into + 16, descriptor === ROOT ? DIRECTORY : CHARACTERS);
      return 0;
    },
    fd_close: (descriptor) => (descriptor > ROOT ? EBADF : 0),
    fd_seek: (descriptor) => (descriptor > 2 ? EBADF : ESPIPE),
    fd_prestat_get: (descriptor, into) => {
      if (descriptor !== ROOT) return EBADF;
      data().setUint8(into, 0);
      data().setUint32(into + 4, 1, true);
      return 0;
    },
    fd_prestat_dir_name: (descriptor, into) => {
      if (descriptor !== ROOT) return EBADF;
      bytes(into, 1).set(encoder.encode("/"));
      return 0;
    },
    path_filestat_get: (descriptor, flags, path, length, into) => {
      if (!["", ".", "/"].includes(text(path, length))) return ENOENT;
      bytes(into, 64).fill(0);
      data().setUint8(into + 16, DIRECTORY);
      return 0;
    },
    path_open: () => ENOENT,
    poll_oneoff: (subscriptions, events, count, happened) => { data().setUint32(happened, 0, true); return ENOSYS; },
    random_get: (into, length) => {
      for (let at = 0; at < length; at += 65536) crypto.getRandomValues(bytes(into + at, Math.min(65536, length - at)));
      return 0;
    },
    sched_yield: () => 0,
    proc_exit: (code) => { throw new Exit(code); },
  };
  // Anything else the program asks of the system it has none of.
  const answered = new Proxy(system, {
    get: (functions, asked) => functions[asked] ?? (() => { console.warn(`WASI: ${String(asked)} is not answered`); return ENOSYS; }),
  });

  const page = {
    element: (number) => elements[number],
    numberOf: (node) => Number(Object.keys(elements).find((number) => elements[number] === node) ?? -1),
    text, bytes,
  };
  const loading = globalThis.document?.getElementById?.("stateui-loading");
  try {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) throw new Error(`${url} answered ${response.status}`);
    const module = await received(response, loading?.querySelector("progress"));
    const { instance } = await WebAssembly.instantiate(module,
      { ...(imports ? imports(page) : {}), stateui_web: relay, wasi_snapshot_preview1: answered });
    memory = instance.exports.memory;
    table = instance.exports.__indirect_function_table;
    if (suspends) await WebAssembly.promising(instance.exports._start)();
    else instance.exports._start();
    if (loading) {
      loading.setAttribute("data-done", "");
      setTimeout(() => loading.remove(), 400);
    }
    exited?.(0);
  } catch (error) {
    if (error instanceof Exit && (exited || error.code === 0)) return exited?.(error.code);
    console.error(error);
    // The loading screen stands over the page: taken away, so the reason shows rather than a load with no end.
    loading?.remove();
    const shown = document.createElement("pre");
    shown.className = "stateui-failure";
    shown.textContent = `StateUI: ${name} did not start - ${error.message ?? error}`;
    document.body.append(shown);
    // A start that failed ends as one: whoever waits for the program's end - a test's runner - hears it failed.
    exited?.(1);
  }
}
