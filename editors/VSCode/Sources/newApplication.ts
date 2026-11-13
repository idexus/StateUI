// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A new application: HelloWorld under another name, made by the stateui tool
// (`project/create`) in an apps/, the checkout's or a project group's; the tool
// names the checkout by the path from the application itself.

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
