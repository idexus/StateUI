// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Packs the extension into artifacts/stateui-<version>.vsix at the repository
// root, on any system: the licence travels in the package, so it is copied in
// from the repository root for the length of the pack and removed after.

import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

const extension = path.resolve(__dirname, "..", "..");
const repository = path.join(extension, "..", "..");
const licence = path.join(extension, "LICENSE");
const version = JSON.parse(fs.readFileSync(path.join(extension, "package.json"), "utf8")).version;
const artifacts = path.join(repository, "artifacts");
const packed = path.join(artifacts, `stateui-${version}.vsix`);

fs.mkdirSync(artifacts, { recursive: true });
fs.copyFileSync(path.join(repository, "LICENSE"), licence);
try {
    const windows = process.platform === "win32";
    execFileSync(path.join(extension, "node_modules", ".bin", windows ? "vsce.cmd" : "vsce"), ["package", "--out", packed],
        { cwd: extension, stdio: "inherit", shell: windows });
} finally {
    fs.rmSync(licence, { force: true });
}
