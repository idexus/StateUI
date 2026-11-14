// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension built again from a checkout's editors/VSCode and installed over itself by the stateui tool
// (`repository/integrationPackage`, `repository/integrationInstall`), with the command line of the VS Code that runs
// it.

import * as fs from "fs";
import * as path from "path";

/** Whether `checkout` holds the extension's sources, editors/VSCode. */
export function hasExtensionSources(checkout: string): boolean {
    return fs.existsSync(path.join(checkout, "editors", "VSCode", "package.json"));
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
