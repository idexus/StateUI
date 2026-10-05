// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// <gallery-rating-bar>: five stars in a row, as many lit as its `rating` attribute - an element that knows nothing
// of StateUI. A tap on a star is the user's rating, 1 through 5: the bar lights it and raises `ratingchange`, its
// `detail` the rating. `flash()` dims the bar and brings it back. The Swift half is
// Platforms/Web/Host/RatingBarElement.swift.

class RatingBar extends HTMLElement {
  static observedAttributes = ["rating"];

  constructor() {
    super();
    const shadow = this.attachShadow({ mode: "open" });
    shadow.innerHTML = `<style>
      :host { display: inline-flex; gap: 6px; }
      button { padding: 0; border: 0; background: none; cursor: pointer; font-size: 34px; line-height: 1;
        color: #f5b546; opacity: 0.22; transition: opacity 0.15s ease; }
      button[aria-pressed="true"] { opacity: 1; }
      button:focus-visible { outline: 2px solid #f5b546; outline-offset: 2px; border-radius: 6px; }
    </style>`;
    for (let index = 0; index < 5; index++) {
      const star = document.createElement("button");
      star.textContent = "★";
      star.setAttribute("aria-label", `${index + 1} of 5`);
      star.addEventListener("click", () => {
        this.setAttribute("rating", String(index + 1));
        this.dispatchEvent(new CustomEvent("ratingchange", { detail: index + 1 }));
      });
      shadow.append(star);
    }
    this.show();
  }

  attributeChangedCallback() {
    this.show();
  }

  show() {
    const rating = Number(this.getAttribute("rating") ?? 0);
    this.shadowRoot.querySelectorAll("button").forEach((star, index) => star.setAttribute("aria-pressed", String(rating >= index + 1)));
  }

  // Dims the bar and brings it back, twice: the browser's own animation of its opacity.
  flash() {
    this.animate([{ opacity: 1 }, { opacity: 0.25 }, { opacity: 1 }], { duration: 240, iterations: 2 });
  }
}

customElements.define("gallery-rating-bar", RatingBar);
