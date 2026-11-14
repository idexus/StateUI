// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A StateUI checkout: the library's repository on disk - cloned by hand, or a
// release cloned into a project group - which every application that names it
// in its Package.swift builds with, known by the marks the stateui tool's
// `Checkout` reads.

import * as fs from "fs";
import * as path from "path";

/** Whether `directory` is a StateUI checkout: the library's manifest, its heads' package and the starter. */
export function isCheckout(directory: string): boolean {
    return ["Package.swift", path.join("lib", "StateUI.Head", "Package.swift"), path.join("apps", "HelloWorld", "Package.swift")]
        .every((each) => fs.existsSync(path.join(directory, each)));
}
