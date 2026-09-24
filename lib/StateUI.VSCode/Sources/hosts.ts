// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The hosts a StateUI application can run on, and what makes a build - and the
// editor - one host's.

/** A host an application is built for and run on. */
export type Host = "appkit" | "android" | "winui";

/** What the extension knows about one host. */
export interface HostDescription {
    readonly id: Host;
    readonly label: string;
    readonly detail: string;

    /**
     * The variable an application's manifest reads to declare this host's head
     * and define its compilation condition.
     */
    readonly variable: string;

    /**
     * Where the language server keeps its index while the editor works as this
     * host, relative to each package: the build directory the host's own builds
     * already keep apart. One index for two hosts is two differently
     * configured builds in one directory - measured, it leaves the build
     * database asking for inputs that no longer exist.
     */
    readonly indexPath: string;

    /**
     * What the language server compiles for while the editor works as this
     * host, where that is not this machine.
     */
    readonly target?: {
        readonly triple: string;

        /** What names the Swift SDK in its id: `android` in `swift-6.4.0-RELEASE_android`. */
        readonly swiftSDK: string;

        /** Where that Swift SDK is installed from. */
        readonly swiftSDKGuide: string;
    };

    /** The machines that build and run this host's heads. */
    readonly platforms: readonly NodeJS.Platform[];
}

/** Every host, in the order the picker offers them. */
export const hosts: readonly HostDescription[] = [
    { id: "appkit", label: "AppKit", detail: "macOS, in the application's own process", variable: "STATEUI_APPKIT", indexPath: ".build-appkit/index-build", platforms: ["darwin"] },
    {
        id: "android", label: "Android", detail: "Android Views, in the application's own process", variable: "STATEUI_ANDROID",
        indexPath: ".build-android/index-build", platforms: ["darwin"],
        target: {
            triple: "aarch64-unknown-linux-android28", swiftSDK: "android",
            swiftSDKGuide: "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html",
        },
    },
    { id: "winui", label: "WinUI", detail: "WinUI 3 on Windows, in the application's own process", variable: "STATEUI_WINUI", indexPath: ".build-winui/index-build", platforms: ["win32"] },
];

/**
 * Where the language server keeps its index while the editor works as no host,
 * on a machine that runs none: SwiftPM's own place.
 */
export const plainIndexPath = ".build/index-build";

/** The hosts this machine builds and runs - AppKit and Android on macOS, WinUI on Windows. */
export function availableHosts(platform: NodeJS.Platform = process.platform): HostDescription[] {
    return hosts.filter((each) => each.platforms.includes(platform));
}

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}

/**
 * The environment that makes a process work as `host`: that host's variable
 * set, and every other host's variable absent - every one of them, with no
 * host. At most one at a time, so a manifest is never asked to be two hosts.
 */
export function environment(host: Host | undefined): Record<string, string | undefined> {
    const values: Record<string, string | undefined> = {};

    for (const each of hosts) {
        values[each.variable] = each.id === host ? "1" : undefined;
    }

    return values;
}
