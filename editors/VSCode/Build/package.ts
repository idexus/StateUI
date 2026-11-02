// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Packs the extension into artifacts/stateui-<version>.vsix at the repository
// root, on any system. The license and the readme - the handbook's page,
// docs/editors/VSCode/README.md - travel in the package, so they are copied in
// for the length of the pack and removed after; the readme's relative links
// lead to that page of the release on GitHub.

import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

const extension = path.resolve(__dirname, "..", "..");
const repository = path.join(extension, "..", "..");
const manifest = JSON.parse(fs.readFileSync(path.join(extension, "package.json"), "utf8"));
const page = "docs/editors/VSCode";
const online = manifest.repository.url.replace(/\.git$/, "");
const copied = [[path.join(repository, "LICENSE"), "LICENSE"], [path.join(repository, page, "README.md"), "README.md"]];
const artifacts = path.join(repository, "artifacts");
const packed = path.join(artifacts, `stateui-${manifest.version}.vsix`);

fs.mkdirSync(artifacts, { recursive: true });
try {
    for (const [source, name] of copied) {
        fs.copyFileSync(source, path.join(extension, name));
    }
    const windows = process.platform === "win32";
    execFileSync(path.join(extension, "node_modules", ".bin", windows ? "vsce.cmd" : "vsce"), [
        "package", "--out", packed,
        "--baseContentUrl", `${online}/blob/${manifest.version}/${page}/`,
        "--baseImagesUrl", `${online}/raw/${manifest.version}/${page}/`,
    ], { cwd: extension, stdio: "inherit", shell: windows });
} finally {
    for (const [, name] of copied) {
        fs.rmSync(path.join(extension, name), { force: true });
    }
}
