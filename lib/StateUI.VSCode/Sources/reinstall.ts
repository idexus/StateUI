// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension built again from a checkout's lib/StateUI.VSCode and installed over itself: compiled and packed into
// artifacts/stateui-<version>.vsix by `npm run package`, then installed with --force by the command line of the
// VS Code that runs it.

import * as fs from "fs";
import * as path from "path";

/** One step: a command line and where it runs. */
export interface Step {
    readonly command: string;
    readonly args: readonly string[];
    readonly cwd: string;
}

/** The extension's own sources in a checkout. */
export function extensionSources(checkout: string): string {
    return path.join(checkout, "lib", "StateUI.VSCode");
}

/** Whether `checkout` holds the extension's sources. */
export function hasExtensionSources(checkout: string): boolean {
    return fs.existsSync(path.join(extensionSources(checkout), "package.json"));
}

/** The package `npm run package` writes: artifacts/stateui-<version>.vsix at the checkout's root. */
export function packedExtension(checkout: string): string {
    const manifest = JSON.parse(fs.readFileSync(path.join(extensionSources(checkout), "package.json"), "utf8"));
    return path.join(checkout, "artifacts", `stateui-${manifest.version}.vsix`);
}

/**
 * The command line of the VS Code installed at `appRoot` - `vscode.env.appRoot` - named as its product names it
 * (`code`, `code-insiders`): in the nearest `bin/` above `appRoot` that holds it, or the name alone, found on the PATH.
 */
export function editorCommandLine(appRoot: string, platform: NodeJS.Platform = process.platform): string {
    const product = path.join(appRoot, "product.json");
    const name = fs.existsSync(product) ? JSON.parse(fs.readFileSync(product, "utf8")).applicationName ?? "code" : "code";
    const file = platform === "win32" ? `${name}.cmd` : name;
    // macOS keeps bin/ inside appRoot; Linux and Windows at the installation's root, two levels above it.
    for (let directory = appRoot; path.dirname(directory) !== directory; directory = path.dirname(directory)) {
        const command = path.join(directory, "bin", file);
        if (fs.existsSync(command)) {
            return command;
        }
    }
    return file;
}

/**
 * The steps that build the extension in `checkout` and install it with `editor`, the editor's command line. Windows
 * runs npm by its `npm.cmd`: a terminal's PowerShell takes `npm.ps1` first, which its default policy refuses.
 */
export function reinstallSteps(checkout: string, editor: string, platform: NodeJS.Platform = process.platform): Step[] {
    return [
        { command: platform === "win32" ? "npm.cmd" : "npm", args: ["run", "package"], cwd: extensionSources(checkout) },
        { command: editor, args: ["--install-extension", packedExtension(checkout), "--force"], cwd: checkout },
    ];
}
