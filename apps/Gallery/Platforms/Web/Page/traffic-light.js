// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// <gallery-traffic-light>: three lamps in a housing, one lit at a time - an element that knows nothing of StateUI.
// Its `signal` attribute says which lamp is lit, 0 red, 1 amber, 2 green; a tap on a lamp raises `lamptap`, its
// `detail` the lamp's index top to bottom. It does not switch itself: whoever owns the state decides. The Swift
// half is Platforms/Web/Host/TrafficLightElement.swift.

class TrafficLight extends HTMLElement {
  static observedAttributes = ["signal"];

  constructor() {
    super();
    const shadow = this.attachShadow({ mode: "open" });
    shadow.innerHTML = `<style>
      :host { display: inline-grid; gap: 10px; padding: 12px; border-radius: 16px; background: #1a1725; }
      button { width: 44px; height: 44px; padding: 0; border: 0; border-radius: 50%; cursor: pointer;
        background: var(--lamp); opacity: 0.22; transition: opacity 0.15s ease, box-shadow 0.15s ease; }
      button[aria-pressed="true"] { opacity: 1; box-shadow: 0 0 18px var(--lamp); }
      button:focus-visible { outline: 2px solid white; outline-offset: 2px; }
    </style>`;
    ["#e5484d", "#f5b546", "#46b45f"].forEach((lamp, index) => {
      const button = document.createElement("button");
      button.style.setProperty("--lamp", lamp);
      button.setAttribute("aria-label", ["Red", "Amber", "Green"][index]);
      button.addEventListener("click", () => this.dispatchEvent(new CustomEvent("lamptap", { detail: index })));
      shadow.append(button);
    });
    this.show();
  }

  attributeChangedCallback() {
    this.show();
  }

  show() {
    const lit = Number(this.getAttribute("signal") ?? 0);
    this.shadowRoot.querySelectorAll("button").forEach((lamp, index) => lamp.setAttribute("aria-pressed", String(index === lit)));
  }
}

customElements.define("gallery-traffic-light", TrafficLight);
