// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The hosts a StateUI application can run on, as the editor shows them; which of them this machine builds, and
// where their heads run, the stateui tool says.

import type { HostPlace, Place } from "./Tooling/protocol";

/** A host an application is built for and run on. */
export type Host = "appkit" | "uikit" | "android" | "winui" | "gtk" | "web";

/** What the extension shows of one host. */
export interface HostDescription {
    readonly id: Host;
    readonly label: string;
    readonly detail: string;
}

/** Every host, in the order the picker offers them. */
export const hosts: readonly HostDescription[] = [
    { id: "appkit", label: "AppKit", detail: "macOS, in the application's own process" },
    { id: "uikit", label: "UIKit", detail: "iOS and iPadOS on a simulator or a device, in the application's own process" },
    { id: "android", label: "Android", detail: "Android Views, in the application's own process" },
    { id: "winui", label: "WinUI", detail: "WinUI 3 on Windows, in the application's own process" },
    { id: "gtk", label: "GTK", detail: "GTK 4 with libadwaita on Linux, in the application's own process" },
    { id: "web", label: "Web", detail: "a page in the browser chosen, the application a WebAssembly module in it" },
];

/** The hosts `places` names - this machine's, as the stateui tool says them (`server/info`) - in the picker's order. */
export function availableHosts(places: readonly HostPlace[]): HostDescription[] {
    return hosts.filter((each) => places.some((one) => one.host === each.id));
}

/** Where `host`'s heads run from this machine, as `places` says; nothing where it builds none. */
export function placeOf(host: Host, places: readonly HostPlace[]): Place | undefined {
    return places.find((each) => each.host === host)?.place;
}

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}
