// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Packs the extension into stateui-<version>.vsix, on any system: the licence
// travels in the package, so it is copied in from the repository root for the
// length of the pack and removed after.

import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

const extension = path.resolve(__dirname, "..", "..");
const licence = path.join(extension, "LICENSE");

fs.copyFileSync(path.join(extension, "..", "..", "LICENSE"), licence);
try {
    const windows = process.platform === "win32";
    execFileSync(path.join(extension, "node_modules", ".bin", windows ? "vsce.cmd" : "vsce"), ["package"],
        { cwd: extension, stdio: "inherit", shell: windows });
} finally {
    fs.rmSync(licence, { force: true });
}
