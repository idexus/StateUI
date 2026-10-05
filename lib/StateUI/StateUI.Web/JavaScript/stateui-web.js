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
 * The module's bytes as they come, `bar` - where the page has one - filled as far as they have: the length the
 * server says, where it says one of the bytes themselves, else no length at all; and wanting none once all are in,
 * while the browser compiles them.
 */
async function received(response, bar) {
  const reader = response.body?.getReader?.();
  if (!reader) return response.arrayBuffer();
  const whole = response.headers.get("content-encoding") ? 0 : Number(response.headers.get("content-length")) || 0;
  const parts = [];
  let length = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    parts.push(value);
    length += value.length;
    if (bar && whole > 0) bar.value = Math.min(1, length / whole);
  }
  bar?.removeAttribute("value");
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
 * after its name, and hears the program's end in `exited(code)`.
 */
export async function start(url, { imports, args = [], exited } = {}) {
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

  // What the event being heard carries, as Swift reads it: its clicks, and where the pointer is in the listening
  // element.
  // A pointer's number, where it is on the page, its kind and its buttons, and a wheel's turn and whether a key
  // turned it into a pinch, too; and the event itself, which a pointer is captured by.
  let event = [0, 0, 0];
  let happening = null;
  const kinds = { mouse: 0, pen: 1, touch: 2 };
  const hearing = (listener, element) => (happened) => {
    const box = element.getBoundingClientRect?.() ?? { left: 0, top: 0 };
    event = [happened?.detail ?? 0, (happened?.clientX ?? 0) - box.left, (happened?.clientY ?? 0) - box.top,
      happened?.pointerId ?? 0, happened?.clientX ?? 0, happened?.clientY ?? 0, kinds[happened?.pointerType] ?? 0,
      happened?.button ?? 0, happened?.deltaY ?? 0, happened?.ctrlKey ? 1 : 0, happened?.scale ?? 1,
      box.width ?? 0, box.height ?? 0];
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
    step: (element, by) => {
      const field = elements[element];
      if (!field) return;
      by > 0 ? field.stepUp(by) : field.stepDown(-by);
    },
    read_value: (element) => (read = encoder.encode(elements[element]?.value ?? "")).length,
    copy_read: (into) => bytes(into, read.length).set(read),
    listen: (element, name, length, listener) => {
      const named = text(name, length), node = elements[element];
      if (!node) return;
      if (named === "enter") {
        node.addEventListener("keydown", (key) => { if (key.key === "Enter") heard(listener); });
      } else if (named === "activate") {
        node.addEventListener("keydown", (key) => {
          if ((key.key === "Enter" || key.key === " ") && key.target === node) { key.preventDefault(); heard(listener); }
        });
      } else {
        // A wheel and Safari's gestures may be taken from the page - a pinch on a trackpad zooms it else.
        const takes = named === "wheel" || named.startsWith("gesture");
        node.addEventListener(named, hearing(listener, node), { passive: !takes });
      }
    },
    event_number: (index) => event[index] ?? 0,
    // The pointer the event being heard is of goes on telling the element, wherever it moves, until it lets go.
    capture_pointer: (element) => {
      if (happening?.pointerId === undefined) return;
      try { elements[element]?.setPointerCapture?.(happening.pointerId); } catch {}
    },
    // The event being heard does what the page would do with it no more: scroll, zoom, select.
    take_event: () => happening?.preventDefault?.(),
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
        const today = new Date();
        const noon = year > 0 ? Date.UTC(year, month - 1, day, 12) : Date.UTC(today.getFullYear(), today.getMonth(), today.getDate(), 12);
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
    instance.exports._start();
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
