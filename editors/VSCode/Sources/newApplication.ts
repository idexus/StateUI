// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A new application: HelloWorld under another name, made by a checkout's own
// scaffolder in an apps/ - the checkout's, or a project group's - and named to
// that checkout by the path from its own directory.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { findApplications } from "./applications";
import { isCheckout } from "./checkouts";

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

/**
 * The checkout a folder's applications build with: the folder itself where it
 * is a checkout, else the one the first of its applications names.
 */
export function checkoutOf(folder: string): string | undefined {
    return isCheckout(folder) ? folder : findApplications(folder).find((each) => each.checkout)?.checkout;
}

/** The command line of `checkout`'s scaffolder that makes `name` in `apps`. */
export function scaffolderCommand(checkout: string, apps: string, name: string,
    platform: NodeJS.Platform = process.platform): { command: string; args: string[] } {
    return platform === "win32"
        ? { command: "powershell", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            path.join(checkout, ".scripts", "new-app.ps1"), "-Name", name, "-AppsDir", apps] }
        : { command: "bash", args: [path.join(checkout, ".scripts", "new-app.sh"), name, apps] };
}

/**
 * Makes `name` in `apps` with `checkout`'s scaffolder, then names the checkout
 * in its Package.swift by the path from the application - `../..` in the
 * checkout's own apps/, which HelloWorld already says.
 *
 * @returns whether it was made, and what the scaffolder said.
 */
export function makeApplication(checkout: string, apps: string, name: string): Promise<{ made: boolean; output: string }> {
    const { command, args } = scaffolderCommand(checkout, apps, name);
    fs.mkdirSync(apps, { recursive: true });
    return new Promise((resolve) => execFile(command, args, { cwd: apps }, (error, stdout, stderr) => {
        const output = `${stdout}${stderr}`;
        if (error) {
            resolve({ made: false, output });
            return;
        }
        nameCheckout(path.join(apps, name), checkout);
        resolve({ made: true, output });
    }));
}

/**
 * Rewrites every `../..` in the application's Package.swift - the checkout's
 * root, as HelloWorld names it - to the path from the application to
 * `checkout`, written with forward slashes as SwiftPM reads it everywhere.
 */
export function nameCheckout(application: string, checkout: string): void {
    const relative = path.relative(fs.realpathSync(application), fs.realpathSync(checkout)).split(path.sep).join("/");
    if (relative === "../..") {
        return;
    }
    const manifest = path.join(application, "Package.swift");
    fs.writeFileSync(manifest, fs.readFileSync(manifest, "utf8").split("../..").join(relative));
}
