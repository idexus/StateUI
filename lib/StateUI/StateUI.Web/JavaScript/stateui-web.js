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

/**
 * Writes `words` in the room at (`x`, `y`) `w` by `h` on `g` at `size`, wrapped at its width, placed across - 0 the
 * start, 1 the middle, 2 the end - and down it the same way, cut to the room.
 */
function write(g, words, x, y, w, h, size, across, down) {
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
  const height = size * 1.25;
  const top = down === 1 ? y + (h - lines.length * height) / 2 : down === 2 ? y + h - lines.length * height : y;
  g.save();
  g.beginPath();
  g.rect(x, y, w, h);
  g.clip();
  g.textAlign = across === 1 ? "center" : across === 2 ? "end" : "start";
  const left = across === 1 ? x + w / 2 : across === 2 ? x + w : x;
  lines.forEach((line, index) => g.fillText(line, left, top + index * height + (height - size) / 2));
  g.restore();
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

  const bytes = (pointer, length) => new Uint8Array(memory.buffer, pointer, length);
  const text = (pointer, length) => decoder.decode(bytes(pointer, length));
  const data = () => new DataView(memory.buffer);

  // The DOM elements Swift made, by number; a number let go of is made again.
  const elements = [null];
  const free = [];
  const keep = (node) => {
    const number = free.length > 0 ? free.pop() : elements.length;
    elements[number] = node;
    return number;
  };
  let body = 0;

  const dark = matchMedia("(prefers-color-scheme: dark)");
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  // The keyboard in a strip of tabs and in a menu, as a platform's own take it: the arrows go from one to the next
  // - across a strip, as its words run - Home and End to the first and the last; a tab is chosen as the keyboard
  // reaches it, and the arrow towards a submenu opens it.
  document.addEventListener?.("keydown", (key) => {
    const within = key.target?.closest?.('[role="tablist"], [role="menu"]');
    if (!within || key.altKey || key.ctrlKey || key.metaKey) return;
    const menu = within.getAttribute("role") === "menu";
    const rtl = getComputedStyle(within).direction === "rtl";
    const items = [...within.children].filter((c) => c.matches(menu ? '[role="menuitem"]:not(:disabled)' : '[role="tab"]'));
    const at = items.indexOf(key.target.closest(menu ? '[role="menuitem"]' : '[role="tab"]'));
    const [back, on] = menu ? ["ArrowUp", "ArrowDown"] : rtl ? ["ArrowRight", "ArrowLeft"] : ["ArrowLeft", "ArrowRight"];
    if (menu && key.key === (rtl ? "ArrowLeft" : "ArrowRight") && key.target.getAttribute("aria-haspopup") === "menu") {
      key.preventDefault();
      key.target.click();
      const inner = [...within.querySelectorAll(":scope > .stateui-menu")].find((m) => m.matches(":popover-open"));
      inner?.querySelector('[role="menuitem"]:not(:disabled)')?.focus();
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

  // A button pressed leaves the keyboard with the field typed in, as a native button takes no keyboard of a field.
  document.addEventListener?.("mousedown", (down) => {
    const held = document.activeElement;
    if (down.target?.closest?.("button") && held?.matches?.("input, textarea, [contenteditable]")) down.preventDefault();
  }, true);

  // What the event being heard carries, as Swift reads it: its clicks, and where the pointer is in the listening
  // element.
  // A pointer's number, where it is on the page, its kind and its buttons, and a wheel's turn and whether a key
  // turned it into a pinch, too, and whether a click on a label passes to its control; and the event itself, which a
  // pointer is captured by.
  let event = [0, 0, 0];
  let happening = null;
  const kinds = { mouse: 0, pen: 1, touch: 2 };
  // A web view hears the user over its frame's own document where it is of the page's site: the pointer, a click and
  // the wheel there, told where they are in the view, heard again after every load. Coming and going it hears itself.
  const framesForward = new Set(["pointerdown", "pointermove", "pointerup", "pointercancel", "click", "wheel"]);
  const forwardFromFrame = (node, named, listener, takes) => {
    const frame = node.querySelector(":scope > iframe");
    if (!frame) return;
    const listen = () => {
      let inner;
      try { inner = frame.contentDocument; } catch { return; }
      if (!inner) return;
      inner.stateuiHeard ??= new Set();
      const key = `${named} ${listener}`;
      if (inner.stateuiHeard.has(key)) return;
      inner.stateuiHeard.add(key);
      inner.addEventListener(named, (happened) => {
        const box = frame.getBoundingClientRect();
        const told = new Proxy(happened, {
          get: (event, name) => name === "clientX" ? event.clientX + box.left
            : name === "clientY" ? event.clientY + box.top
            : typeof event[name] === "function" ? event[name].bind(event) : event[name],
        });
        hearing(listener, node)(told);
      }, { passive: !takes });
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
  const hearing = (listener, element) => (happened) => {
    const box = element.getBoundingClientRect?.() ?? { left: 0, top: 0 };
    event = [happened?.detail ?? 0, (happened?.clientX ?? 0) - box.left, (happened?.clientY ?? 0) - box.top,
      happened?.pointerId ?? 0, happened?.clientX ?? 0, happened?.clientY ?? 0, kinds[happened?.pointerType] ?? 0,
      happened?.button ?? 0, happened?.deltaY ?? 0, happened?.ctrlKey ? 1 : 0, happened?.scale ?? 1,
      box.width ?? 0, box.height ?? 0, passesToControl(happened) ? 1 : 0];
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
  let dragWords = "";
  const settle = (listener, kept, words) => { fileAnswer = words; event = [kept ? 1 : 0]; heard(listener); };
  const chosen = (list) => list.map((file) => `${files.push(file) - 1}\u001F${file.name}`).join("\u001F");
  const testing = () => (globalThis.stateui?.holdsFiles ? globalThis.stateui : null);
  const fileOf = async (kept) => (kept?.getFile ? await kept.getFile() : kept);
  const typeOf = (name) => ({ txt: "text/plain", md: "text/markdown", html: "text/html", htm: "text/html",
    csv: "text/csv", json: "application/json", xml: "application/xml", pdf: "application/pdf", png: "image/png",
    jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", svg: "image/svg+xml" })[name.split(".").pop().toLowerCase()] ?? "";
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
    },
    body: () => body || (body = keep(document.body)),
    create: (tag, length) => keep(document.createElement(text(tag, length))),
    create_vector: (tag, length) => keep(document.createElementNS("http://www.w3.org/2000/svg", text(tag, length))),
    read_shape_bounds: (element, into) => {
      let box = { x: 0, y: 0, width: 0, height: 0 };
      try { box = elements[element]?.getBBox?.() ?? box; } catch {}
      doubles(into, [box.x, box.y, box.width, box.height]);
    },
    // A number let go of is no element's until it is made again: what reaches one does nothing.
    release: (element) => {
      const node = elements[element];
      if (!node) return;
      resized?.unobserve(node);
      node.stateuiNearness?.unobserve(node);
      node.remove();
      elements[element] = undefined;
      free.push(element);
    },
    insert: (parent, child, index) => {
      const into = elements[parent], node = elements[child];
      if (!into || !node) return;
      const at = into.children[index] ?? null;
      if (at !== node) into.insertBefore(node, at);
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
    listen: (element, name, length, listener) => {
      const named = text(name, length), node = elements[element];
      if (!node) return;
      if (named === "enter") {
        node.addEventListener("keydown", (key) => { if (key.key === "Enter") heard(listener); });
      } else if (named === "focus") {
        // The keyboard coming into the element or anything in it, or leaving it all: the event's one number 1 or 0.
        let within = node.contains(document.activeElement);
        const tell = (now) => {
          if (now === within) return;
          within = now;
          event = [now ? 1 : 0];
          heard(listener);
        };
        node.addEventListener("focusin", () => tell(true));
        node.addEventListener("focusout", (left) => tell(node.contains(left.relatedTarget)));
      } else if (named === "steps") {
        // A step up or down from the keyboard's arrows, its direction the event's one number.
        node.addEventListener("keydown", (key) => {
          const by = key.key === "ArrowUp" ? 1 : key.key === "ArrowDown" ? -1 : 0;
          if (by === 0) return;
          key.preventDefault();
          event = [by];
          heard(listener);
        });
      } else if (named === "itemtap") {
        // A click on an item, but for one on a control inside it, which is the control's.
        node.addEventListener("click", (click) => {
          const inner = click.target?.closest?.("button, input, select, textarea, a, label, [data-taps]");
          if (!inner || inner === node || !node.contains(inner)) hearing(listener, node)(click);
        });
      } else if (named === "closed") {
        // A popover the browser took down - a click beside it, Escape - or the program did.
        node.addEventListener("toggle", (toggle) => { if (toggle.newState === "closed") heard(listener); });
      } else if (named === "menu") {
        // The user asks for the element's menu: its context menu, or a finger held still half a second.
        node.addEventListener("contextmenu", (asked) => { asked.preventDefault(); hearing(listener, node)(asked); });
        let held = null;
        node.addEventListener("pointerdown", (down) => {
          if (down.pointerType !== "touch") return;
          clearTimeout(held);
          held = setTimeout(() => hearing(listener, node)(down), 500);
        });
        for (const ended of ["pointerup", "pointercancel", "pointermove"]) {
          node.addEventListener(ended, (event) => {
            if (event.type !== "pointermove" || Math.hypot(event.movementX, event.movementY) > 6) clearTimeout(held);
          });
        }
      } else if (named === "dismiss") {
        // A modal dialog the user asked to close - Escape - closes only as the tree says.
        node.addEventListener("cancel", (cancel) => { cancel.preventDefault(); heard(listener); });
      } else if (named === "activate") {
        node.addEventListener("keydown", (key) => {
          if ((key.key === "Enter" || key.key === " ") && key.target === node) { key.preventDefault(); heard(listener); }
        });
      } else {
        // A wheel and Safari's gestures may be taken from the page - a pinch on a trackpad zooms it else.
        const takes = named === "wheel" || named.startsWith("gesture");
        node.addEventListener(named, hearing(listener, node), { passive: !takes });
        if (node.classList?.contains("stateui-frame") && framesForward.has(named)) forwardFromFrame(node, named, listener, takes);
      }
    },
    event_number: (index) => event[index] ?? 0,
    // The words the event being heard carries in its `detail` - a custom element's own.
    event_words: () => (read = encoder.encode(String(happening?.detail ?? ""))).length,
    // One watch a scroller for the elements in it coming near its view - within half its size - or going away.
    watch_nearness: (element, root, listener) => {
      const node = elements[element], scroller = elements[root];
      if (!node || !scroller || typeof IntersectionObserver === "undefined") return;
      scroller.stateuiNear ??= new IntersectionObserver((entries) => {
        for (const entry of entries) entry.target.stateuiNear?.(entry.isIntersecting);
      }, { root: scroller, rootMargin: "50%" });
      node.stateuiNear = (near) => { event = [near ? 1 : 0]; heard(listener); };
      node.stateuiNearness = scroller.stateuiNear;
      scroller.stateuiNear.observe(node);
    },
    // A popover over everything: under or beside the element `anchor` - beside for `side` - else at (x, y) in the
    // window, kept in the window whole.
    show_popover: (element, anchor, x, y, side) => {
      const menu = elements[element];
      if (!menu?.showPopover) return;
      menu.showPopover();
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
    // A frame shows an address, or a document written in place at an address of the page's own made for it - of the
    // page's own site, so it can be reached, and a step in the frame's history as any page shown is: the browser
    // takes a `srcdoc` written again in place of the one before.
    frame_show: (element, kind, words, length, base, baseLength) => {
      const frame = elements[element];
      if (!frame) return 0;
      frame.removeAttribute("srcdoc");
      if (kind === 0) {
        frame.src = text(words, length);
        return 0;
      }
      const at = baseLength > 0 ? `<base href="${text(base, baseLength).replace(/"/g, "&quot;")}">` : "";
      const address = URL.createObjectURL(new Blob([at + text(words, length)], { type: "text/html" }));
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
    // A step of the frame's own - 0 back, 1 forward, 2 the page again - where its document is of the page's site.
    frame_step: (element, step) => {
      try {
        const inside = elements[element].contentWindow;
        if (!inside.document) return 0;
        step === 0 ? inside.history.back() : step === 1 ? inside.history.forward() : inside.location.reload();
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
    push_history: () => history.pushState({ stateui: true }, ""),
    // Back over the page's own entry alone - never off the site from one the page did not put there: 1 where it went.
    back_history: () => (history.state?.stateui ? (history.back(), 1) : 0),
    listen_history: (listener) => addEventListener("popstate", () => heard(listener)),
    page_state: () => (document.visibilityState === "visible" ? 1 : 0) | (document.hasFocus() ? 2 : 0),
    listen_page: (changed, leaving) => {
      for (const name of ["focus", "blur"]) addEventListener(name, () => heard(changed));
      document.addEventListener("visibilitychange", () => heard(changed));
      addEventListener("pagehide", () => heard(leaving));
      // What the page stands as when it starts, told once, after its window is made.
      setTimeout(() => heard(changed), 0);
    },
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
    is_laid_out: (element) => {
      const node = elements[element];
      return node?.isConnected && node.getClientRects().length > 0 ? 1 : 0;
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
    // A child's place in its layout from the layout's own layout, never its drawing: a transform moves no place.
    read_places: (pairs, count, into) => {
      const list = new Int32Array(memory.buffer, pairs, count * 2);
      const read = new Float64Array(count * 4).fill(NaN);
      for (let index = 0; index < count; index++) {
        const layout = elements[list[index * 2]], child = elements[list[index * 2 + 1]];
        if (!layout || !child || !layout.offsetParent) continue;
        if (child === layout) {
          read.set([0, 0, layout.offsetWidth, layout.offsetHeight], index * 4);
        } else if (child.offsetParent !== undefined) {
          if (!child.offsetParent) continue;
          const inside = child.offsetParent === layout;
          read.set([child.offsetLeft - (inside ? 0 : layout.offsetLeft), child.offsetTop - (inside ? 0 : layout.offsetTop),
            child.offsetWidth, child.offsetHeight], index * 4);
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
    request_frame: () => requestAnimationFrame((time) => frame(time)),
    wake_after: (milliseconds) => {
      clearTimeout(wake);
      wake = setTimeout(() => heard(0), milliseconds);
    },
    now: () => performance.now(),
    prefers_dark: () => (dark.matches ? 1 : 0),
    listen_appearance: (listener) => dark.addEventListener("change", () => heard(listener)),
    reduces_motion: () => (still.matches ? 1 : 0),
    draw_canvas: (element, numbers, count, words, length) => {
      const canvas = elements[element];
      const g = canvas?.getContext?.("2d");
      if (!g) return;
      const list = new Float64Array(memory.buffer, numbers, count).slice();
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
          case 0: g.save(); break;
          case 1: g.restore(); break;
          case 2: g.translate(next(), next()); break;
          case 3: g.rotate(next()); break;
          case 4: g.scale(next(), next()); break;
          case 5: g.beginPath(); break;
          case 6: g.moveTo(next(), next()); break;
          case 7: g.lineTo(next(), next()); break;
          case 8: g.bezierCurveTo(next(), next(), next(), next(), next(), next()); break;
          case 9: g.quadraticCurveTo(next(), next(), next(), next()); break;
          case 10: g.closePath(); break;
          case 11: g.fillStyle = color(); g.fill(); break;
          case 12: g.strokeStyle = color(); g.lineWidth = next(); g.stroke(); break;
          case 13: {
            const words = texts[next()] ?? "", x = next(), y = next(), w = next(), h = next(), size = next() || 15;
            g.fillStyle = color();
            const across = next(), down = next();
            write(g, words, x, y, w, h, size, across, down);
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
      link.href = URL.createObjectURL(file);
      link.download = file.name;
      link.click();
      setTimeout(() => settle(listener, true, chosen([file])), 0);
    },
    // A file read whole: event 1 and its length, its bytes read by `copy_read`.
    read_file: (file, listener) => {
      fileOf(files[file])
        .then((found) => { if (!found) throw new Error("the page holds no such file"); return found.arrayBuffer(); })
        .then((buffer) => { read = new Uint8Array(buffer); event = [1, read.length]; heard(listener); },
          (error) => settle(listener, false, String(error?.message ?? error)));
    },
    file_words: () => (read = encoder.encode(fileAnswer)).length,
    // The file, or the address, opened in a window of its own; event 1 where the browser opened one.
    launch_file: (file, listener) => {
      const kept = files[file];
      const test = testing();
      let taken = !!kept;
      if (kept && test) test.launched.push(kept.name);
      else if (kept) taken = openWindow(fileOf(kept).then((found) => URL.createObjectURL(found)));
      setTimeout(() => { event = [taken ? 1 : 0]; heard(listener); }, 0);
    },
    launch_address: (address, length, listener) => {
      const target = text(address, length);
      let taken = false;
      try { taken = !!new URL(target).protocol; } catch {}
      const test = testing();
      if (taken && test) test.launched.push(target);
      else if (taken) taken = openWindow(target);
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
        node.removeAttribute("draggable");
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
    for (const line of parts) descriptor === 2 ? console.error(line) : console.log(line);
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

  const page = { element: (number) => elements[number], numberOf: (node) => elements.indexOf(node), text, bytes };
  try {
    const loading = globalThis.document?.getElementById?.("stateui-loading");
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
    const shown = document.createElement("pre");
    shown.className = "stateui-failure";
    shown.textContent = `StateUI: ${name} did not start - ${error.message ?? error}`;
    document.body.append(shown);
  }
}
