// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs a WebAssembly program of the Web host's suite in a browser - the tests that need the browser's own layout,
// focus, dialogs and input: the conformance suite, and the host's tests that run a host - and ends with the program's
// exit code:
//
//   node run-in-browser.mjs <browser> <program.wasm> [arguments...]
//
// It serves the page on this machine's loopback alone - the host's relay and style sheet, the suite's pictures and
// its driver (browser.mjs) - and drives the browser, headless, over its DevTools pipe: it says what the page writes
// to its console, and answers what the program asks of it - the user's input as the browser takes it, a file of the
// repository read, the verdicts held to their file or written there with STATEUI_UPDATE_EXPORTS=1.
//
// Each test named in a comma-separated list - a class, or a class's test - runs in a program of its own, the page
// loaded anew: a host makes the UI thread's executor MainActor's, and XCTest then starts every later test from a job
// of that executor, inside the drain running it - where every drain the test asks for returns at once, and no
// `await` of an application's handler ever goes on.
import { spawn } from "child_process";
import fs from "fs";
import http from "http";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

const [browser, program, ...args] = process.argv.slice(2);
const here = path.dirname(fileURLToPath(import.meta.url));
const testing = path.resolve(here, "..");
const host = path.resolve(testing, "..");
const repository = path.resolve(host, "../../..");
const exports = path.join(repository, "lib/StateUI/exports");
const width = 1280, height = 800;

// The page's files, by their address.
const files = {
  "/stateui-web.js": path.join(host, "JavaScript/stateui-web.js"),
  "/stateui-web.css": path.join(host, "JavaScript/stateui-web.css"),
  "/browser.mjs": path.join(here, "browser.mjs"),
  "/program.wasm": program,
};
const types = { ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css", ".wasm": "application/wasm",
  ".png": "image/png", ".svg": "image/svg+xml", ".html": "text/html" };
// The runs: each test named apart, every other argument handed to each.
const [named = "", ...others] = args;
const runs = named.split(",").filter(Boolean);
if (runs.length === 0) runs.push("");
let run = 0;
let worst = 0;
const runArgs = () => [runs[run], ...others].filter(Boolean);
const pageFor = (handed) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<link rel="stylesheet" href="./stateui-web.css">
<script>globalThis.StateUI = { acts: {}, told: new Map(), tell(name, words) { this.told.set(name, String(words ?? "")); this.heard?.(name); } };</script>
<script type="module">
  import { start } from "./stateui-web.js";
  import { driver, exited } from "./browser.mjs";
  start("./program.wasm", { imports: driver, args: ${JSON.stringify(handed)}, suspends: true, exited });
</script></head><body></body></html>`;

const server = http.createServer((request, response) => {
  const address = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const file = address === "/" ? null
    : files[address] ?? (address.startsWith("/Images/") ? path.join(testing, "Tests/Resources", address) : undefined);
  if (file === undefined || (file && !fs.existsSync(file))) {
    response.writeHead(404, { "Cache-Control": "no-store" });
    return response.end();
  }
  response.writeHead(200, { "Content-Type": file ? types[path.extname(file)] ?? "application/octet-stream" : "text/html",
    "Cache-Control": "no-store" });
  response.end(file ? fs.readFileSync(file) : pageFor(runArgs()));
});
await new Promise((done) => server.listen(0, "127.0.0.1", done));
const query = ["STATEUI_UPDATE_EXPORTS", "STATEUI_STALE_ONLY"].filter((name) => process.env[name])
  .map((name) => `${name}=${encodeURIComponent(process.env[name])}`).join("&");
const url = `http://127.0.0.1:${server.address().port}/${query ? `?${query}` : ""}`;

// The browser, its DevTools on descriptors 3 and 4: a message a JSON text ended by NUL.
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-conformance-"));
const chrome = spawn(browser, [
  "--headless=new", "--remote-debugging-pipe", `--user-data-dir=${profile}`, `--window-size=${width},${height}`,
  "--no-first-run", "--no-default-browser-check", "--hide-scrollbars", "--mute-audio",
  "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "about:blank",
], { stdio: ["ignore", "ignore", "pipe", "pipe", "pipe"] });
chrome.stderr.on("data", () => {});
const [, , , toBrowser, fromBrowser] = chrome.stdio;

let next = 0;
const replies = new Map();
const handlers = new Map();
let pending = "";
fromBrowser.on("data", (chunk) => {
  pending += chunk.toString("utf8");
  let end;
  while ((end = pending.indexOf("\0")) >= 0) {
    const message = JSON.parse(pending.slice(0, end));
    pending = pending.slice(end + 1);
    if (message.id !== undefined) {
      replies.get(message.id)?.(message);
      replies.delete(message.id);
    } else {
      handlers.get(message.method)?.(message.params, message.sessionId);
    }
  }
});

/** Sends `method` to the browser - to the page's session, where one is given - and answers its result. */
function send(method, params = {}, sessionId = undefined) {
  const id = ++next;
  return new Promise((done, failed) => {
    replies.set(id, (reply) => (reply.error ? failed(new Error(`${method}: ${reply.error.message}`)) : done(reply.result)));
    toBrowser.write(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }) + "\0");
  });
}

const ended = (code) => {
  server.close();
  chrome.kill();
  // The browser may still be writing its profile as it goes: what it leaves is the system's temporary folder's.
  try { fs.rmSync(profile, { recursive: true, force: true, maxRetries: 3 }); } catch {}
  process.exit(code);
};
// A run that hears nothing for so long has stopped.
let heardLast = Date.now();
setInterval(() => {
  if (Date.now() - heardLast < Number(process.env.STATEUI_SILENCE ?? 300_000)) return;
  console.error("conformance: the page said nothing for too long");
  ended(2);
}, 10_000).unref();

const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
const page$ = (method, params) => send(method, params, sessionId);

handlers.set("Runtime.consoleAPICalled", ({ type, args: values }) => {
  heardLast = Date.now();
  const line = values.map((value) => value.value ?? value.description ?? "").join(" ");
  (type === "error" || type === "warning" ? process.stderr : process.stdout).write(line + "\n");
});
handlers.set("Runtime.exceptionThrown", ({ exceptionDetails }) => {
  process.stderr.write(`exception: ${exceptionDetails.exception?.description ?? exceptionDetails.text}\n`);
});
// The page leaving its document - a way back past its own history - ends the program with it.
handlers.set("Page.frameNavigated", ({ frame }) => {
  if (frame.parentId || frame.url === url || frame.url === "about:blank") return;
  console.error(`conformance: the page left for ${frame.url}`);
  ended(3);
});
handlers.set("Inspector.targetCrashed", () => {
  console.error("conformance: the page crashed");
  ended(3);
});

// What the program asks the controller: the user's input, a file. Each answer is words, or null for none.
const keys = {
  Enter: { key: "Enter", code: "Enter", windowsVirtualKeyCode: 13, text: "\r" },
  Escape: { key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 },
  Tab: { key: "Tab", code: "Tab", windowsVirtualKeyCode: 9 },
  Backspace: { key: "Backspace", code: "Backspace", windowsVirtualKeyCode: 8 },
  Delete: { key: "Delete", code: "Delete", windowsVirtualKeyCode: 46 },
  ArrowUp: { key: "ArrowUp", code: "ArrowUp", windowsVirtualKeyCode: 38 },
  ArrowDown: { key: "ArrowDown", code: "ArrowDown", windowsVirtualKeyCode: 40 },
  ArrowLeft: { key: "ArrowLeft", code: "ArrowLeft", windowsVirtualKeyCode: 37 },
  ArrowRight: { key: "ArrowRight", code: "ArrowRight", windowsVirtualKeyCode: 39 },
  Home: { key: "Home", code: "Home", windowsVirtualKeyCode: 36 },
  End: { key: "End", code: "End", windowsVirtualKeyCode: 35 },
};
async function answer(message) {
  // The mouse: pressed, released, moved - its button, the left unless one is named, held down where `held` - or its
  // wheel turned.
  if (message.mouse) {
    const { mouse: type, x, y, count = 1, held = false, deltaX = 0, deltaY = 0, button = "left" } = message;
    const pressing = type === "mousePressed" || type === "mouseReleased" || held;
    await page$("Input.dispatchMouseEvent", { type, x, y, button: pressing ? button : "none",
      buttons: type === "mousePressed" || held ? (button === "right" ? 2 : 1) : 0, clickCount: pressing ? count : 0, deltaX, deltaY,
      modifiers: message.modifiers ?? 0 });
    return "";
  }
  if (message.touch) {
    await page$("Input.dispatchTouchEvent", { type: message.touch,
      touchPoints: (message.points ?? []).map(([x, y], id) => ({ x, y, id })) });
    return "";
  }
  // The colour the window shows at a point, as "red,green,blue,alpha": one pixel of its own picture.
  if (message.pixel) {
    const [[x, y]] = message.pixel;
    const { data } = await page$("Page.captureScreenshot", { format: "png", clip: { x, y, width: 1, height: 1, scale: 1 } });
    const { result } = await page$("Runtime.evaluate", { awaitPromise: true, returnByValue: true, expression: `(async () => {
      const picture = await createImageBitmap(await (await fetch("data:image/png;base64,${data}")).blob());
      const painter = new OffscreenCanvas(1, 1).getContext("2d");
      painter.drawImage(picture, 0, 0);
      return [...painter.getImageData(0, 0, 1, 1).data].join(",");
    })()` });
    return result.value ?? null;
  }
  if (message.insertText !== undefined) {
    await page$("Input.insertText", { text: message.insertText });
    return "";
  }
  if (message.key) {
    const key = keys[message.key];
    if (!key) throw new Error(`no key ${message.key}`);
    await page$("Input.dispatchKeyEvent", { type: "keyDown", ...key, modifiers: message.modifiers ?? 0 });
    await page$("Input.dispatchKeyEvent", { type: "keyUp", ...key, text: undefined, modifiers: message.modifiers ?? 0 });
    return "";
  }
  if (message.read !== undefined) {
    const file = path.join(repository, message.read);
    return fs.existsSync(file) ? fs.readFileSync(file, "utf8") : null;
  }
  // A verdicts' file under exports: written with STATEUI_UPDATE_EXPORTS=1, read back otherwise, for the program to
  // hold its own to.
  if (message.hold !== undefined) {
    const file = path.join(exports, message.hold);
    if (!file.startsWith(exports + path.sep)) throw new Error(`${message.hold} stands outside ${exports}`);
    if (process.env.STATEUI_UPDATE_EXPORTS === "1") {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, message.text);
      return message.text;
    }
    return fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  }
  throw new Error(`nothing answers ${JSON.stringify(message)}`);
}

await page$("Runtime.addBinding", { name: "stateuiDriver" });
handlers.set("Runtime.bindingCalled", async ({ name, payload }) => {
  if (name !== "stateuiDriver") return;
  heardLast = Date.now();
  const { number, message, exit } = JSON.parse(payload);
  if (exit !== undefined) {
    worst = Math.max(worst, exit);
    run += 1;
    if (run >= runs.length) return ended(worst);
    // The next test in a program of its own, on the page loaded anew.
    await page$("Page.navigate", { url: "about:blank" });
    await page$("Page.navigate", { url });
    return;
  }
  let words;
  try {
    words = await answer(message);
  } catch (error) {
    console.error(`conformance: ${error.message}`);
    words = null;
  }
  await page$("Runtime.evaluate", { expression: `stateuiAnswered(${number}, ${JSON.stringify(words)})` });
});
await page$("Runtime.enable");
await page$("Page.enable");
await page$("Emulation.setFocusEmulationEnabled", { enabled: true });
await page$("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: false });
await page$("Page.navigate", { url });
