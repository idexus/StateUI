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
  let memory, table, heard, frame;
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

  const relay = {
    start: (heardIndex, frameIndex) => {
      heard = table.get(heardIndex);
      frame = table.get(frameIndex);
    },
    body: () => body || (body = keep(document.body)),
    create: (tag, length) => keep(document.createElement(text(tag, length))),
    release: (element) => {
      elements[element].remove();
      elements[element] = undefined;
      free.push(element);
    },
    insert: (parent, child, index) => {
      const into = elements[parent], node = elements[child], at = into.children[index] ?? null;
      if (at !== node) into.insertBefore(node, at);
    },
    detach: (element) => elements[element].remove(),
    set_text: (element, pointer, length) => { elements[element].textContent = text(pointer, length); },
    set_attribute: (element, name, nameLength, value, valueLength) =>
      elements[element].setAttribute(text(name, nameLength), text(value, valueLength)),
    remove_attribute: (element, name, length) => elements[element].removeAttribute(text(name, length)),
    set_style: (element, name, nameLength, value, valueLength) => {
      const style = elements[element].style, property = text(name, nameLength);
      valueLength > 0 ? style.setProperty(property, text(value, valueLength)) : style.removeProperty(property);
    },
    // Writing the same words again would move the user's caret to their end.
    set_value: (element, pointer, length) => {
      const field = elements[element], value = text(pointer, length);
      if (field.value !== value) field.value = value;
    },
    read_value: (element) => (read = encoder.encode(elements[element].value)).length,
    copy_read: (into) => bytes(into, read.length).set(read),
    listen: (element, event, length, listener) => {
      const named = text(event, length);
      if (named === "enter") {
        elements[element].addEventListener("keydown", (key) => { if (key.key === "Enter") heard(listener); });
      } else {
        elements[element].addEventListener(named, () => heard(listener));
      }
    },
    set_title: (pointer, length) => { document.title = text(pointer, length); },
    request_frame: () => requestAnimationFrame((time) => frame(time)),
    now: () => performance.now(),
    prefers_dark: () => (dark.matches ? 1 : 0),
    listen_appearance: (listener) => dark.addEventListener("change", () => heard(listener)),
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
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) throw new Error(`${url} answered ${response.status}`);
    const { instance } = await WebAssembly.instantiate(await response.arrayBuffer(),
      { ...(imports ? imports(page) : {}), stateui_web: relay, wasi_snapshot_preview1: answered });
    memory = instance.exports.memory;
    table = instance.exports.__indirect_function_table;
    instance.exports._start();
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
