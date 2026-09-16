// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The hosts a StateUI application can run on, and what makes a build - and the
// editor - one host's.

/** A host an application is built for and run on. */
export type Host = "appkit" | "maui";

/** What the extension knows about one host. */
export interface HostDescription {
    readonly id: Host;
    readonly label: string;
    readonly detail: string;

    /**
     * The variable an application's manifest reads to declare this host's head
     * and define its compilation condition - or none, where the manifest reads
     * nothing for the host yet. MAUI's Apple and Windows builds call swiftc
     * directly and pass `-D MAUI` themselves.
     */
    readonly variable?: string;

    /**
     * Where the language server keeps its index while the editor works as this
     * host, relative to each package: the build directory the host's own builds
     * already keep apart. One index for two hosts is two differently
     * configured builds in one directory - measured, it leaves the build
     * database asking for inputs that no longer exist.
     */
    readonly indexPath: string;
}

/** Every host, in the order the picker offers them. */
export const hosts: readonly HostDescription[] = [
    { id: "appkit", label: "AppKit", detail: "macOS, in the application's own process", variable: "STATEUI_APPKIT", indexPath: ".build-appkit/index-build" },
    { id: "maui", label: ".NET MAUI", detail: "Android, iOS, Mac Catalyst, Windows and Linux", indexPath: ".build-maui/index-build" },
];

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}

/**
 * The environment that makes a process work as `host`: that host's variable
 * set, and every other host's variable absent. Exactly one at a time, so a
 * manifest is never asked to be two hosts.
 */
export function environment(host: Host): Record<string, string | undefined> {
    const values: Record<string, string | undefined> = {};

    for (const each of hosts) {
        if (each.variable) {
            values[each.variable] = each.id === host ? "1" : undefined;
        }
    }

    return values;
}
