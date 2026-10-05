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
      copy_read: (into) => page.bytes(into, read.length).set(read),
    },
  };
}
