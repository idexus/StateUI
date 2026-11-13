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
