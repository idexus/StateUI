// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The hosts a StateUI application can run on, and what makes a build - and the
// editor - one host's.

/** A host an application is built for and run on. */
export type Host = "appkit" | "uikit" | "android" | "winui" | "gtk" | "web";

/** What the extension knows about one host. */
export interface HostDescription {
    readonly id: Host;
    readonly label: string;
    readonly detail: string;

    /** The machines that build and run this host's heads. */
    readonly platforms: readonly NodeJS.Platform[];
}

/** Every host, in the order the picker offers them. */
export const hosts: readonly HostDescription[] = [
    { id: "appkit", label: "AppKit", detail: "macOS, in the application's own process", platforms: ["darwin"] },
    {
        id: "uikit", label: "UIKit", detail: "iOS and iPadOS on a simulator, in the application's own process", platforms: ["darwin"],
    },
    {
        id: "android", label: "Android", detail: "Android Views, in the application's own process", platforms: ["darwin"],
    },
    { id: "winui", label: "WinUI", detail: "WinUI 3 on Windows, in the application's own process", platforms: ["win32"] },
    { id: "gtk", label: "GTK", detail: "GTK 4 with libadwaita on Linux, in the application's own process", platforms: ["linux"] },
    {
        id: "web", label: "Web", detail: "a page in the browser chosen, the application a WebAssembly module in it",
        platforms: ["darwin", "linux"],
    },
];


/** The hosts this machine builds and runs - AppKit, UIKit and Android on macOS, WinUI on Windows, GTK on Linux, Web on macOS and Linux. */
export function availableHosts(platform: NodeJS.Platform = process.platform): HostDescription[] {
    return hosts.filter((each) => each.platforms.includes(platform));
}

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}

