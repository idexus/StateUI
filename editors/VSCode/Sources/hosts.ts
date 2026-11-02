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

        /** What ends the Swift SDK's id: `android` in `swift-6.4.0-RELEASE_android`. */
        readonly swiftSDK?: string;

        /** Where that Swift SDK is installed from. */
        readonly swiftSDKGuide?: string;

        /** Or the SDK Xcode ships for the platform, by its name for `xcrun --sdk`: `iphonesimulator`. */
        readonly xcodeSDK?: string;
    };

    /** The machines that build and run this host's heads. */
    readonly platforms: readonly NodeJS.Platform[];
}

/** Every host, in the order the picker offers them. */
export const hosts: readonly HostDescription[] = [
    { id: "appkit", label: "AppKit", detail: "macOS, in the application's own process", indexPath: ".build/appkit/index-build", platforms: ["darwin"] },
    {
        id: "uikit", label: "UIKit", detail: "iOS and iPadOS on a simulator, in the application's own process",
        indexPath: ".build/uikit/index-build", platforms: ["darwin"],
        target: { triple: "arm64-apple-ios26.0-simulator", xcodeSDK: "iphonesimulator" },
    },
    {
        id: "android", label: "Android", detail: "Android Views, in the application's own process",
        indexPath: ".build/android/index-build", platforms: ["darwin"],
        target: {
            triple: "aarch64-unknown-linux-android28", swiftSDK: "android",
            swiftSDKGuide: "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html",
        },
    },
    { id: "winui", label: "WinUI", detail: "WinUI 3 on Windows, in the application's own process", indexPath: ".build/winui/index-build", platforms: ["win32"] },
    { id: "gtk", label: "GTK", detail: "GTK 4 with libadwaita on Linux, in the application's own process", indexPath: ".build/gtk/index-build", platforms: ["linux"] },
    {
        id: "web", label: "Web", detail: "a page in the browser chosen, the application a WebAssembly module in it",
        indexPath: ".build/web/index-build", platforms: ["darwin", "linux"],
        target: {
            triple: "wasm32-unknown-wasip1", swiftSDK: "wasm",
            swiftSDKGuide: "https://www.swift.org/documentation/articles/wasm-getting-started.html",
        },
    },
];

/**
 * Where the language server keeps its index while the editor works as no host,
 * on a machine that runs none: SwiftPM's own place.
 */
export const plainIndexPath = ".build/index-build";

/** The hosts this machine builds and runs - AppKit, UIKit and Android on macOS, WinUI on Windows, GTK on Linux, Web on macOS and Linux. */
export function availableHosts(platform: NodeJS.Platform = process.platform): HostDescription[] {
    return hosts.filter((each) => each.platforms.includes(platform));
}

/** The description of one host. */
export function describe(host: Host): HostDescription {
    return hosts.find((each) => each.id === host) ?? hosts[0];
}

/**
 * The variable a build names its host by - `STATEUI_HOST=appkit` - which an
 * application's manifest reads to declare that host's head and define its
 * condition. One variable holds one host, so no build is two hosts' at once.
 */
export const hostVariable = "STATEUI_HOST";

/** The environment that makes a process work as `host`: the variable naming it, and absent with no host. */
export function environment(host: Host | undefined): Record<string, string | undefined> {
    return { [hostVariable]: host };
}
