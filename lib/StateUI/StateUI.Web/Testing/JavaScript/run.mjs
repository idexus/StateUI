// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs a WebAssembly program of the Web host's suite in Node over the page of page.mjs, through the host's own relay:
//
//   node run.mjs <stateui-web.js> <program.wasm> [arguments...]
//
// and ends with the program's exit code.
import fs from "fs";
import path from "path";
import { pathToFileURL } from "url";
import { driver, installPage } from "./page.mjs";

const [relay, program, ...args] = process.argv.slice(2);
installPage();
globalThis.fetch = async (url) => {
  const bytes = fs.readFileSync(program);
  return { ok: true, arrayBuffer: async () => bytes };
};

const { start } = await import(pathToFileURL(path.resolve(relay)).href);
await start(program, { imports: driver, args, exited: (code) => process.exit(code) });
