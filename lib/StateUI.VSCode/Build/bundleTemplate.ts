// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Copies the StateUIStarter template and the build it ships with into
// out/Template/, laid out as in a checkout - the copy the extension writes a new
// application from when it is made against a release rather than a checkout.
// Run by `npm run compile`, so the copy is never older than the extension.

import * as fs from "fs";
import * as path from "path";
import { carriedTemplate, leftOut, templateIn } from "../Sources/newApplication";

const extension = path.resolve(__dirname, "..", "..");
const repository = path.resolve(extension, "..", "..");
const bundled = carriedTemplate(extension);

const from = templateIn(repository);
const to = templateIn(bundled);

fs.rmSync(bundled, { recursive: true, force: true });
fs.cpSync(from.template, to.template, {
    recursive: true,
    filter: (source) => !leftOut.has(path.basename(source)) || source === from.template,
});
fs.cpSync(from.scripts, to.scripts, { recursive: true, filter: (source) => path.basename(source) !== ".DS_Store" });
