// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A StateUI checkout: the library's repository on disk - cloned by hand, or a
// release cloned into a project group - whose .scripts build and run every
// application that names it in its Package.swift.

import * as fs from "fs";
import * as path from "path";

/** Whether `directory` is a StateUI checkout with apps/HelloWorld and its scaffolder. */
export function isCheckout(directory: string): boolean {
    return fs.existsSync(path.join(directory, ".scripts", "new-app.sh"))
        && fs.existsSync(path.join(directory, "apps", "HelloWorld"));
}

/**
 * The StateUI checkout the Package.swift in `directory` names by path: the
 * first `.package(path:)` outside a comment that resolves to one. An
 * application in a checkout's apps/ names it `../..`, one in a project group
 * the release cloned into the group or the local checkout.
 */
export function checkoutNamedBy(directory: string): string | undefined {
    const manifest = path.join(directory, "Package.swift");
    if (!fs.existsSync(manifest)) {
        return undefined;
    }
    const from = fs.realpathSync(directory);
    return fs.readFileSync(manifest, "utf8").split(/\r?\n/)
        .filter((line) => line.includes(".package(") && !line.trimStart().startsWith("//"))
        .flatMap((line) => [...line.matchAll(/path: "([^"]+)"/g)].map((match) => path.resolve(from, match[1])))
        .find(isCheckout);
}
