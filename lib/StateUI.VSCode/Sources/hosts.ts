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

/** How a MAUI head is debugged. */
export type MauiDebugger = "csharp" | "swift-ios" | "swift-maccatalyst" | "csharp-swift-maccatalyst" | "swift";

/** What the extension knows about one way of debugging a MAUI head. */
export interface MauiDebuggerDescription {
    readonly id: MauiDebugger;
    readonly label: string;
    readonly detail: string;

    /** The machines it runs on - a Swift debugger attaches only to a process on this one. */
    readonly platforms: readonly NodeJS.Platform[];
}

/**
 * Every way of debugging a MAUI head, in the order the picker offers them.
 *
 * C# on iOS, Android and Mac Catalyst is the MAUI extension's: those run on
 * Mono, which only its debugger attaches to. Swift is lldb-dap's, on a process
 * this machine runs - the iOS Simulator, Mac Catalyst, Windows, Linux - and on
 * the iOS Simulator it attaches only AFTER the app is running, because the
 * simulator's watchdog kills an app a debugger holds stopped at launch. Both
 * at once only on Mac Catalyst: Windows allows one native debugger per process,
 * and the simulator's watchdog forbids it.
 */
export const mauiDebuggers: readonly MauiDebuggerDescription[] = [
    { id: "csharp", label: "C#", detail: "the MAUI extension's debugger, on the device its picker chose - coreclr on Linux", platforms: ["darwin", "win32", "linux"] },
    { id: "swift-ios", label: "Swift · iOS Simulator", detail: "built and started by run-app.sh, then lldb-dap attaches", platforms: ["darwin"] },
    { id: "swift-maccatalyst", label: "Swift · Mac Catalyst", detail: "built and started by run-app.sh, then lldb-dap attaches", platforms: ["darwin"] },
    { id: "csharp-swift-maccatalyst", label: "C# + Swift · Mac Catalyst", detail: "the C# session starts the app, then lldb-dap attaches beside it", platforms: ["darwin"] },
    { id: "swift", label: "Swift", detail: "lldb-dap - launched on Linux, attached on Windows after run-app.ps1", platforms: ["linux", "win32"] },
];

/** The ways of debugging a MAUI head this machine offers. */
export function availableMauiDebuggers(platform: NodeJS.Platform = process.platform): MauiDebuggerDescription[] {
    return mauiDebuggers.filter((each) => each.platforms.includes(platform));
}
