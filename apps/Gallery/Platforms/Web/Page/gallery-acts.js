// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: InteropActsSample.Web.javascript, InteropEventsSample.Web.javascript
// The gallery's own acts as the page's scripts answer them, and what they tell: the browser's console and its
// battery, wherever the browser offers it. The Swift half is Platforms/Web/Host/GalleryActs.swift and
// GalleryEventSources.swift.
// The page loads this script before the application starts.
// listing: end

// listing: InteropActsSample.Web.javascript
// A line for the log: the browser's console, where its developer tools read it.
StateUI.acts.log = (line) => {
  console.log(line);
  return "";
};
// listing: end

// listing: InteropActsSample.Web.javascript, InteropEventsSample.Web.javascript
// The battery as two words, its level from 0 to 1 and whether it charges; a browser that says nothing of it - a
// desktop's mains, Safari, Firefox - answers 0.
const battery = navigator.getBattery?.().catch(() => null) ?? Promise.resolve(null);
const said = (power) => (power ? `${power.level} ${power.charging}` : "0 false");
// listing: end

// listing: InteropActsSample.Web.javascript
StateUI.acts.batteryLevel = async () => said(await battery);
// listing: end

// listing: InteropEventsSample.Web.javascript
// A browser that offers its battery - Chrome, Edge - tells it at once and at each change; the others tell nothing.
battery.then((power) => {
  if (!power) return;
  const tell = () => StateUI.tell("battery", said(power));
  power.addEventListener("levelchange", tell);
  power.addEventListener("chargingchange", tell);
  tell();
});
// listing: end
