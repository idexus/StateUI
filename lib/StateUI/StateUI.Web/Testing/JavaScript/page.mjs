// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A page with just enough of a DOM for the Web host's relay, in Node: elements that hold children in order - an
// element inserted where it stands already moves - attributes, a style and listeners; and the driver's functions
// the suite reads it through (Sources/CWebTesting/CWebTesting.h). It proves what the host does to the page's
// elements, never how a browser draws them.

const encoder = new TextEncoder();

class Style {
  constructor() { this.properties = new Map(); }
  setProperty(name, value) { this.properties.set(name, value); }
  removeProperty(name) { this.properties.delete(name); }
  getPropertyValue(name) { return this.properties.get(name) ?? ""; }
}

class Element {
  constructor(tag) {
    this.tagName = tag.toUpperCase();
    this.children = [];
    this.parentNode = null;
    this.attributes = new Map();
    this.style = new Style();
    this.textContent = "";
    this.value = "";
    this.listeners = new Map();
    // Where the page lays the element out; nowhere until the suite says.
    this.offsetParent = null;
    Object.assign(this, { offsetLeft: 0, offsetTop: 0, offsetWidth: 0, offsetHeight: 0 });
  }

  insertBefore(node, before) {
    node.remove();
    const at = before ? this.children.indexOf(before) : -1;
    at < 0 ? this.children.push(node) : this.children.splice(at, 0, node);
    node.parentNode = this;
  }

  append(node) { this.insertBefore(node, null); }

  remove() {
    if (!this.parentNode) return;
    this.parentNode.children.splice(this.parentNode.children.indexOf(this), 1);
    this.parentNode = null;
  }

  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  removeAttribute(name) { this.attributes.delete(name); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }

  addEventListener(event, listener) {
    if (!this.listeners.has(event)) this.listeners.set(event, []);
    this.listeners.get(event).push(listener);
  }
}

/** Makes the page Node's globals: a document with a body, an address, the appearance and display frames. */
export function installPage() {
  globalThis.document = { body: new Element("body"), title: "", createElement: (tag) => new Element(tag) };
  globalThis.location = { search: "" };
  globalThis.matchMedia = () => ({ matches: false, addEventListener() {} });
  globalThis.requestAnimationFrame = (frame) => setTimeout(() => frame(performance.now()), 16);
}

/** The driver's functions, over `page` - the relay's elements and the module's memory. */
export function driver(page) {
  let read = new Uint8Array(0);
  const answer = (text) => (read = encoder.encode(text)).length;
  return {
    stateui_web_testing: {
      child_count: (element) => page.element(element).children.length,
      child: (element, index) => {
        const node = page.element(element).children[index];
        return node ? page.numberOf(node) : 0;
      },
      read_style: (element, name, length) => answer(page.element(element).style.getPropertyValue(page.text(name, length))),
      read_attribute: (element, name, length) => {
        const value = page.element(element).getAttribute(page.text(name, length));
        return value === null ? -1 : answer(value);
      },
      read_text: (element) => answer(page.element(element).textContent),
      read_value: (element) => answer(page.element(element).value),
      // The user types words into a field, which then says so, or leaves it.
      enter: (element, pointer, length) => {
        const field = page.element(element);
        field.value = page.text(pointer, length);
        for (const event of ["input", "change"]) for (const heard of field.listeners.get(event) ?? []) heard({});
      },
      // The page lays the element out at a place in its parent - a layout's own place in nothing at all.
      lay_out: (element, x, y, width, height) => {
        const node = page.element(element);
        Object.assign(node, { offsetLeft: x, offsetTop: y, offsetWidth: width, offsetHeight: height });
        node.offsetParent = node.parentNode ?? document.body;
      },
      // The user presses Escape on a modal dialog, which asks it to close.
      dismiss: (element) => {
        for (const heard of page.element(element).listeners.get("cancel") ?? []) heard({ preventDefault() {} });
      },
      // The application's own script tells something, as `StateUI.tell` does.
      tell: (name, length, words, wordsLength) => globalThis.StateUI?.tell(page.text(name, length), page.text(words, wordsLength)),
      tap: (element) => { for (const heard of page.element(element).listeners.get("click") ?? []) heard({ detail: 1 }); },
      leave: (element) => { for (const heard of page.element(element).listeners.get("blur") ?? []) heard({}); },
      copy_read: (into) => page.bytes(into, read.length).set(read),
      // A browser's page alone (browser.mjs) waits for a frame, asks its controller and runs a script.
      ...Object.fromEntries(["pause", "ask", "evaluate"].map((name) => [name, () => {
        throw new Error(`${name}: a browser's page alone answers it`);
      }])),
    },
  };
}
