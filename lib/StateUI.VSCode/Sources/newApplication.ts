// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A new application: HelloWorld under another name, made in a checkout's apps/
// by the checkout's own scaffolder.

import * as fs from "fs";
import * as path from "path";

/**
 * Why `name` cannot name an application, or undefined where it can. Letters
 * and digits, starting with a letter: the name becomes a Swift module, a
 * process name, a package identifier and a directory, and the strictest wins.
 */
export function nameProblem(name: string): string | undefined {
    if (!/^[A-Za-z][A-Za-z0-9]*$/.test(name)) {
        return "Letters and digits only, starting with a letter.";
    }
    if (name === "StateUI") {
        return "StateUI is the library. Pick a name of the application's own.";
    }
    return undefined;
}

/** Whether `directory` is a StateUI checkout with apps/HelloWorld and its scaffolder. */
export function isCheckout(directory: string): boolean {
    return fs.existsSync(path.join(directory, ".scripts", "new-app.sh"))
        && fs.existsSync(path.join(directory, "apps", "HelloWorld"));
}

/** The command line that makes `name` in a checkout's apps/. */
export function inAppsCommand(checkout: string, name: string, platform: NodeJS.Platform = process.platform): { command: string; args: string[] } {
    return platform === "win32"
        ? { command: "powershell", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(checkout, ".scripts", "new-app.ps1"), "-Name", name] }
        : { command: "bash", args: [path.join(checkout, ".scripts", "new-app.sh"), name] };
}
