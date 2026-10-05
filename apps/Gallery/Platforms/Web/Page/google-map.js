// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// <gallery-map>: a map of Google's, drawn by the Maps JavaScript API - an element that knows nothing of StateUI.
// Its attributes say what it shows: `region` and `moving-to` ("latitude longitude radius-in-meters", the second
// sliding the map there), `map-type` (standard, satellite, hybrid), `traffic`, `user-location`, `no-zoom`,
// `no-scroll`, and `markers` - a line each: "number, latitude, longitude, kind, label, subtitle", a tab apart. It
// raises `mapclick` ("latitude longitude"), `markerselect` and `markerdetails` (a marker's number) in `detail`.
//
// The API's key is the application's: Page/google-maps-key.js, which git keeps out, sets `StateUI.googleMapsKey`,
// and `StateUI.googleMapsMapId` where the key's project has a map of its own. The Swift half is
// Platforms/Web/Host/GoogleMapElement.swift.

/** The Maps JavaScript API, loaded once - Google's own loader, its `importLibrary` answering each library asked. */
let api;
function maps() {
  if (api) return api;
  const options = { v: "weekly", key: globalThis.StateUI?.googleMapsKey ?? "" };
  api = new Promise((loaded, failed) => {
    const query = new URLSearchParams({ ...options, callback: "stateuiMapsLoaded", loading: "async" });
    globalThis.stateuiMapsLoaded = () => loaded(globalThis.google.maps);
    const script = document.createElement("script");
    script.src = `https://maps.googleapis.com/maps/api/js?${query}`;
    script.onerror = () => failed(new Error("the Maps JavaScript API could not load"));
    document.head.append(script);
  });
  if (!options.key) console.warn("<gallery-map>: no key - Page/google-maps-key.js sets StateUI.googleMapsKey");
  return api;
}

/** A marker's colour by its kind. */
const colours = { generic: "#ea4335", place: "#1a73e8", saved: "#f9ab00", searchResult: "#188038" };

/** Meters in a degree of latitude. */
const meters = 111320;

class GalleryMap extends HTMLElement {
  static observedAttributes = ["region", "moving-to", "map-type", "traffic", "user-location", "no-zoom", "no-scroll",
    "markers"];

  constructor() {
    super();
    this.room = document.createElement("div");
    this.room.style.cssText = "position: absolute; inset: 0;";
    this.shown = new Map();
  }

  connectedCallback() {
    this.style.display = "block";
    this.style.position = "relative";
    this.style.overflow = "hidden";
    if (!this.room.isConnected) this.append(this.room);
    this.made ??= this.make();
  }

  async make() {
    try {
      const google = await maps();
      const [{ Map, InfoWindow }, { AdvancedMarkerElement, PinElement }] =
        await Promise.all([google.importLibrary("maps"), google.importLibrary("marker")]);
      Object.assign(this, { google, AdvancedMarkerElement, PinElement });
      this.map = new Map(this.room, {
        center: { lat: 0, lng: 0 }, zoom: 2, mapId: globalThis.StateUI?.googleMapsMapId ?? "DEMO_MAP_ID",
        streetViewControl: false, mapTypeControl: false, fullscreenControl: false, clickableIcons: false,
      });
      this.details = new InfoWindow();
      this.map.addListener("click", (event) => {
        if (!event.latLng) return;
        this.raise("mapclick", `${event.latLng.lat()} ${event.latLng.lng()}`);
      });
      for (const name of GalleryMap.observedAttributes) this.attributeChangedCallback(name);
    } catch (error) {
      this.room.textContent = `Map: ${error.message}`;
    }
  }

  attributeChangedCallback(name) {
    if (!this.map) return;
    const value = this.getAttribute(name);
    switch (name) {
      case "region": if (value) this.map.fitBounds(this.bounds(value), 0); break;
      case "moving-to": if (value) this.map.fitBounds(this.bounds(value), 0); break;
      case "map-type": this.map.setMapTypeId({ satellite: "satellite", hybrid: "hybrid" }[value] ?? "roadmap"); break;
      case "traffic":
        this.traffic ??= new this.google.TrafficLayer();
        this.traffic.setMap(value === null ? null : this.map);
        break;
      case "user-location": this.follow(value !== null); break;
      case "no-zoom": case "no-scroll": this.gestures(); break;
      case "markers": this.mark(value ?? ""); break;
    }
  }

  /** The bounds of "latitude longitude radius": the radius each way from the point. */
  bounds(words) {
    const [lat, lng, radius] = words.split(" ").map(Number);
    const across = radius / (meters * Math.max(Math.cos((lat * Math.PI) / 180), 0.01));
    return { north: lat + radius / meters, south: lat - radius / meters, east: lng + across, west: lng - across };
  }

  /** What a hand may do: pan, zoom, both or neither. */
  gestures() {
    const zooms = !this.hasAttribute("no-zoom"), scrolls = !this.hasAttribute("no-scroll");
    this.map.setOptions({
      gestureHandling: scrolls ? "greedy" : "none", zoomControl: zooms, scrollwheel: zooms,
      disableDoubleClickZoom: !zooms, keyboardShortcuts: zooms && scrolls,
    });
  }

  /** Shows the markers of `lines`, keeping each marker shown before by its number. */
  mark(lines) {
    const kept = new Set();
    for (const line of lines.split("\n").filter(Boolean)) {
      const [number, lat, lng, kind, label, subtitle] = line.split("\t");
      kept.add(number);
      let marker = this.shown.get(number);
      if (!marker) {
        marker = new this.AdvancedMarkerElement({ map: this.map, gmpClickable: true });
        marker.addListener("click", () => this.select(number));
        this.shown.set(number, marker);
      }
      marker.position = { lat: Number(lat), lng: Number(lng) };
      marker.title = label;
      marker.content = new this.PinElement({ background: colours[kind] ?? colours.generic, borderColor: "#ffffff",
        glyphColor: "#ffffff" }).element;
      Object.assign(marker, { label, subtitle });
    }
    for (const [number, marker] of this.shown) {
      if (kept.has(number)) continue;
      marker.map = null;
      this.shown.delete(number);
    }
  }

  /** The user chose a marker: it is said, and its details offered under its words. */
  select(number) {
    const marker = this.shown.get(number);
    this.raise("markerselect", number);
    const card = document.createElement("div");
    card.style.cssText = "font: 13px system-ui, sans-serif; color: #202124; display: grid; gap: 4px; min-width: 140px;";
    const title = document.createElement("strong");
    title.textContent = marker.label;
    const under = document.createElement("span");
    under.textContent = marker.subtitle;
    const details = document.createElement("button");
    details.type = "button";
    details.textContent = "Details";
    details.style.cssText = "justify-self: start; margin-top: 4px; font: inherit; padding: 4px 10px; cursor: pointer;";
    details.addEventListener("click", () => this.raise("markerdetails", number));
    card.append(title, ...(marker.subtitle ? [under] : []), details);
    this.details.setContent(card);
    this.details.open({ map: this.map, anchor: marker });
  }

  /** Follows the user's own position - where the browser tells it, on a page of a secure site - or stops. */
  follow(on) {
    if (this.watch !== undefined) navigator.geolocation?.clearWatch(this.watch);
    this.watch = undefined;
    if (this.me) this.me.map = null;
    if (!on || !navigator.geolocation) return;
    this.watch = navigator.geolocation.watchPosition((position) => {
      if (!this.me) {
        const dot = document.createElement("div");
        dot.style.cssText = "width: 14px; height: 14px; border-radius: 50%; background: #1a73e8; "
          + "border: 2px solid white; box-shadow: 0 0 0 4px rgba(26, 115, 232, 0.25);";
        this.me = new this.AdvancedMarkerElement({ content: dot, title: "You" });
      }
      this.me.map = this.map;
      this.me.position = { lat: position.coords.latitude, lng: position.coords.longitude };
    }, () => {});
  }

  raise(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail }));
  }
}

customElements.define("gallery-map", GalleryMap);
