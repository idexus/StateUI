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

    /** The machines that build and run this host's heads in a guest of theirs - a Parallels virtual machine. */
    readonly guests?: readonly NodeJS.Platform[];
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
    {
        id: "winui", label: "WinUI", detail: "WinUI 3 on Windows or a Mac's Windows guest, in the application's own process",
        platforms: ["win32"], guests: ["darwin"],
    },
    {
        id: "gtk", label: "GTK", detail: "GTK 4 with libadwaita on Linux or a Mac's Linux guest, in the application's own process",
        platforms: ["linux"], guests: ["darwin"],
    },
    {
        id: "web", label: "Web", detail: "a page in the browser chosen, the application a WebAssembly module in it",
        platforms: ["darwin", "linux"],
    },
];


/**
 * The hosts this machine builds and runs, itself or in a guest - AppKit, UIKit and Android on macOS, WinUI on Windows,
 * GTK on Linux, both in a Mac's guests too, Web on macOS and Linux.
 */
export function availableHosts(platform: NodeJS.Platform = process.platform): HostDescription[] {
    return hosts.filter((each) => each.platforms.includes(platform) || (each.guests?.includes(platform) ?? false));
}

/** Whether this machine builds and runs `host`'s heads in a guest of its own, not itself. */
export function inGuest(host: Host, platform: NodeJS.Platform = process.platform): boolean {
    const described = describe(host);
    return !described.platforms.includes(platform) && (described.guests?.includes(platform) ?? false);
}

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}

