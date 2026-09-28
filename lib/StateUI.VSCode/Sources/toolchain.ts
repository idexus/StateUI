// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this machine needs to build and run the hosts it runs, as the handbook's Requirements say
// (docs/getting-started.md, docs/hosts/*.md, and this extension's README): each component looked for, and where it is
// missing, what to install. The scripts under .scripts find the same tools as they build; this only tells the reader
// what is there before a build fails on it.

import { execFile } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { swiftRelease, swiftSDKOf } from "./editorMode";

/** A component the machine needs, and what was found of it. */
export interface Finding {
    /** The component, with the least of it that serves: "Swift 6.4 or newer". */
    readonly component: string;

    /** Who needs it: "every host", "GTK", "Debug". */
    readonly neededBy: string;

    /** What was found - its version, where it stands; undefined where nothing serves. */
    readonly found?: string;

    /** How to get it, where it is missing. */
    readonly advice: string;
}

/** One component's check: what it is, who needs it, how to look for it, and how to get it. */
interface Check {
    readonly component: string;
    readonly neededBy: string;
    readonly advice: string;
    readonly look: () => Promise<string | undefined>;
}

/** Below 0, 0 or above 0 as version `a` is older than, the same as or newer than `b`, part by part. */
export function compareVersions(a: string, b: string): number {
    const first = a.split(".").map((each) => parseInt(each, 10) || 0);
    const second = b.split(".").map((each) => parseInt(each, 10) || 0);
    for (let index = 0; index < Math.max(first.length, second.length); index += 1) {
        const difference = (first[index] ?? 0) - (second[index] ?? 0);
        if (difference !== 0) {
            return difference;
        }
    }
    return 0;
}

/** Whether `version` is `minimum` or newer: "6.4.1" is at least "6.4", "26.0" at least "26". */
export function atLeast(version: string, minimum: string): boolean {
    return compareVersions(version, minimum) >= 0;
}

/** The first version - digits and dots - in `text`. */
export function versionIn(text: string): string | undefined {
    return text.match(/\d+(\.\d+)+|\d+/)?.[0];
}

/** Xcode's version in `xcodebuild -version`'s output: "27.0" in "Xcode 27.0". */
export function xcodeVersion(text: string): string | undefined {
    return text.match(/Xcode (\d+(\.\d+)*)/)?.[1];
}

/** Whether a swift.org toolchain wrote `swift --version`'s output: its build is "swift-6.4-RELEASE", not "swiftlang-…". */
export function isSwiftOrgBuild(text: string): boolean {
    return /\(swift-\d/.test(text);
}

/** The newest available iOS simulator runtime `xcrun simctl list runtimes available -j` lists, by its version. */
export function newestIOSRuntime(json: string): string | undefined {
    try {
        const runtimes: { platform?: string; name?: string; version?: string; isAvailable?: boolean }[] =
            JSON.parse(json).runtimes ?? [];
        return runtimes
            .filter((each) => (each.platform === "iOS" || each.name?.startsWith("iOS")) && each.isAvailable !== false)
            .map((each) => each.version ?? "")
            .filter((each) => each.length > 0)
            .sort(compareVersions)
            .pop();
    } catch {
        return undefined;
    }
}

/** The file of the loader a gdk-pixbuf loaders cache names for SVG pictures, or undefined where it names none. */
export function svgLoaderIn(cache: string): string | undefined {
    for (const entry of cache.split(/\r?\n\s*\r?\n/)) {
        const lines = entry.split(/\r?\n/).filter((line) => line.length > 0 && !line.startsWith("#"));
        if (lines.length > 1 && lines.some((line) => /(^|\s)"image\/svg\+xml"(\s|$)/.test(line))) {
            return path.basename(lines[0].replace(/^"|"$/g, ""));
        }
    }
    return undefined;
}

/** The output of `command` run with `args` - its standard output and error together - or undefined where it did not run. */
function run(command: string, args: readonly string[]): Promise<string | undefined> {
    return new Promise((resolve) => {
        execFile(command, [...args], { timeout: 30_000, windowsHide: true }, (error, stdout, stderr) => {
            const text = `${stdout ?? ""}${stderr ?? ""}`;
            resolve(error && (error as NodeJS.ErrnoException).code === "ENOENT" ? undefined : error && !text ? undefined : text);
        });
    });
}

/** Where `name` stands on the search path - with Windows' own extensions for a program - or undefined. */
export function onPath(name: string, platform: NodeJS.Platform = process.platform): string | undefined {
    const extensions = platform === "win32" ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT").split(";") : [""];
    for (const directory of (process.env.PATH ?? "").split(path.delimiter).filter((each) => each.length > 0)) {
        for (const extension of extensions) {
            const candidate = path.join(directory, name + extension.toLowerCase());
            if (fs.existsSync(candidate)) {
                return candidate;
            }
        }
    }
    return undefined;
}

/** A found version where it is `minimum` or newer, said with where it was found. */
function served(version: string | undefined, minimum: string, where?: string): string | undefined {
    return version !== undefined && atLeast(version, minimum) ? (where ? `${version} (${where})` : version) : undefined;
}

/** Swift 6.4 or newer, as `swift --version` says. */
const swift: Check = {
    component: "Swift 6.4 or newer", neededBy: "every host",
    advice: "Install Swift 6.4 from https://www.swift.org/install (on macOS, Xcode 27 brings it).",
    look: async () => {
        const text = await run("swift", ["--version"]);
        return text === undefined ? undefined : served(swiftRelease(text), "6.4", onPath("swift"));
    },
};

/** lldb-dap, which a Debug launch runs: Xcode's on macOS, else beside the toolchain's swift or on the search path. */
const lldbDap: Check = {
    component: "lldb-dap", neededBy: "Debug",
    advice: "It comes with the Swift toolchain; put the toolchain's bin directory on the search path.",
    look: async () => {
        if (process.platform === "darwin") {
            return (await run("xcrun", ["--find", "lldb-dap"]))?.trim().split("\n").pop() || undefined;
        }
        const swiftPath = onPath("swift");
        const beside = swiftPath && path.join(path.dirname(fs.realpathSync(swiftPath)),
            process.platform === "win32" ? "lldb-dap.exe" : "lldb-dap");
        return beside && fs.existsSync(beside) ? beside : onPath("lldb-dap");
    },
};

/** Node.js 20 or newer and npm, which build this extension from a checkout. */
const node: Check = {
    component: "Node.js 20 or newer, with npm", neededBy: "the extension's own build",
    advice: "Install Node.js 20 or newer from https://nodejs.org.",
    look: async () => {
        const version = (await run("node", ["--version"]))?.trim().replace(/^v/, "");
        return onPath("npm") ? served(version, "20") : undefined;
    },
};

/** What the GTK host needs on Linux. */
function linuxChecks(): Check[] {
    const module = (name: string, library: string, minimum: string, package_: string): Check => ({
        component: `${library} ${minimum} or newer, with its headers`, neededBy: "GTK",
        advice: `Install ${package_} (Ubuntu 24.04 or newer has it).`,
        look: async () => served((await run("pkg-config", ["--modversion", name]))?.trim(), minimum),
    });
    return [
        {
            component: "pkg-config", neededBy: "GTK", advice: "Install pkg-config.",
            look: async () => onPath("pkg-config"),
        },
        module("gtk4", "GTK", "4.14", "libgtk-4-dev"),
        module("libadwaita-1", "libadwaita", "1.5", "libadwaita-1-dev"),
        {
            component: "gdk-pixbuf's SVG loader", neededBy: "GTK's pictures",
            advice: "Install librsvg2-common: without it GTK draws no SVG picture.",
            look: async () => {
                const cache = process.env.GDK_PIXBUF_MODULE_FILE
                    || (await run("pkg-config", ["--variable=gdk_pixbuf_cache_file", "gdk-pixbuf-2.0"]))?.trim();
                return cache && fs.existsSync(cache) ? svgLoaderIn(fs.readFileSync(cache, "utf8")) : undefined;
            },
        },
        {
            component: "a desktop session", neededBy: "GTK, its test suite included",
            advice: "Run from a Wayland or X11 session: nothing shows a window without one.",
            look: async () => process.env.WAYLAND_DISPLAY ? `Wayland (${process.env.WAYLAND_DISPLAY})`
                : process.env.DISPLAY ? `X11 (${process.env.DISPLAY})` : undefined,
        },
    ];
}

/** Where the Android SDK stands: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, else Android Studio's own place. */
function androidSDK(): string {
    return process.env.ANDROID_HOME ?? process.env.ANDROID_SDK_ROOT ?? path.join(os.homedir(), "Library", "Android", "sdk");
}

/** The swift.org toolchains of this Mac, which the Android host builds with: Xcode's Swift cannot read the SDK. */
function swiftOrgToolchains(): string[] {
    const roots = [path.join(os.homedir(), "Library", "Developer", "Toolchains"), "/Library/Developer/Toolchains"];
    const found = roots.flatMap((root) => fs.existsSync(root)
        ? fs.readdirSync(root).filter((each) => each.endsWith(".xctoolchain")).map((each) => path.join(root, each, "usr", "bin", "swift"))
        : []);
    return [...found, path.join(os.homedir(), ".swiftly", "bin", "swift")].filter((each) => fs.existsSync(each));
}

/** What AppKit, UIKit and Android need on macOS. */
function macChecks(): Check[] {
    return [
        {
            component: "macOS 26 or newer", neededBy: "AppKit", advice: "Update macOS to 26 or newer.",
            look: async () => served((await run("sw_vers", ["-productVersion"]))?.trim(), "26"),
        },
        {
            component: "Xcode 27 or newer", neededBy: "AppKit, UIKit",
            advice: "Install Xcode 27 from the App Store, then run it once, or `xcode-select -s` it.",
            look: async () => served(xcodeVersion((await run("xcodebuild", ["-version"])) ?? ""), "27"),
        },
        {
            component: "an iOS 26 or newer simulator runtime", neededBy: "UIKit",
            advice: "Install the iOS platform in Xcode's Settings, Components.",
            look: async () => served(newestIOSRuntime((await run("xcrun", ["simctl", "list", "runtimes", "available", "-j"])) ?? ""), "26"),
        },
        {
            component: "Swift 6.4 from swift.org, with the Swift SDK for Android of the same release", neededBy: "Android",
            advice: "Install the swift.org toolchain and its SDK: "
                + "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html",
            look: async () => {
                for (const candidate of swiftOrgToolchains()) {
                    const text = (await run(candidate, ["--version"])) ?? "";
                    const release = swiftRelease(text);
                    if (!isSwiftOrgBuild(text) || release === undefined || !atLeast(release, "6.4")) {
                        continue;
                    }
                    const sdk = swiftSDKOf(release, (await run(candidate, ["sdk", "list"])) ?? "", "android");
                    if (sdk) {
                        return `${sdk} (${candidate})`;
                    }
                }
                return undefined;
            },
        },
        {
            component: "the Android SDK with platform 36", neededBy: "Android",
            advice: "Install it with Android Studio's SDK Manager, and set ANDROID_HOME where it is not ~/Library/Android/sdk.",
            look: async () => {
                const sdk = androidSDK();
                return fs.existsSync(path.join(sdk, "platform-tools")) && fs.existsSync(path.join(sdk, "platforms", "android-36"))
                    ? sdk : undefined;
            },
        },
        {
            component: "the Android NDK r30 or newer", neededBy: "Android",
            advice: "Install it with Android Studio's SDK Manager, or name one with ANDROID_NDK_HOME.",
            look: async () => {
                const named = process.env.ANDROID_NDK_ROOT ?? process.env.ANDROID_NDK_HOME;
                const folder = path.join(androidSDK(), "ndk");
                const newest = fs.existsSync(folder)
                    ? fs.readdirSync(folder).filter((each) => atLeast(each, "30")).sort(compareVersions).pop()
                    : undefined;
                return named && fs.existsSync(named) ? named : newest ? path.join(folder, newest) : undefined;
            },
        },
        {
            component: "JDK 21", neededBy: "Android, for Gradle",
            advice: "Install a JDK 21 - Android Studio's, or one of your own named by JAVA_HOME.",
            look: async () => {
                const home = (await run("/usr/libexec/java_home", ["-v", "21"]))?.trim();
                if (home && !home.includes("Unable")) {
                    return home;
                }
                const own = process.env.JAVA_HOME && (await run(path.join(process.env.JAVA_HOME, "bin", "java"), ["-version"]));
                return own && /"21\./.test(own) ? process.env.JAVA_HOME : undefined;
            },
        },
    ];
}

/** What the WinUI host needs on Windows. */
function windowsChecks(): Check[] {
    const programs = process.env["ProgramFiles(x86)"] ?? "C:\\Program Files (x86)";
    const tools = os.arch() === "arm64" ? "Microsoft.VisualStudio.Component.VC.Tools.ARM64" : "Microsoft.VisualStudio.Component.VC.Tools.x86.x64";
    return [
        {
            component: "Swift 6.4 from swift.org", neededBy: "WinUI",
            advice: "Install Swift 6.4 from https://www.swift.org/install/windows.",
            look: async () => {
                const text = (await run("swift", ["--version"])) ?? "";
                return isSwiftOrgBuild(text) ? served(swiftRelease(text), "6.4") : undefined;
            },
        },
        {
            component: "Visual Studio 2026 with the C++ tools for this machine", neededBy: "WinUI",
            advice: `Install Visual Studio 2026 with "Desktop development with C++" (${tools}).`,
            look: async () => {
                const vswhere = path.join(programs, "Microsoft Visual Studio", "Installer", "vswhere.exe");
                const version = (await run(vswhere, ["-latest", "-products", "*", "-requires", tools, "-property", "installationVersion"]))?.trim();
                return served(versionIn(version ?? ""), "18");
            },
        },
        {
            component: "the Windows SDK 10.0.26100", neededBy: "WinUI",
            advice: "Install the Windows 11 SDK (10.0.26100) with the Visual Studio Installer.",
            look: async () => {
                const include = path.join(programs, "Windows Kits", "10", "Include");
                const found = fs.existsSync(include) ? fs.readdirSync(include).filter((each) => each.startsWith("10.0.26100")).pop() : undefined;
                return found ? path.join(include, found) : undefined;
            },
        },
    ];
}

/** Every component this machine needs, in the order the check reads them. */
function checks(platform: NodeJS.Platform): Check[] {
    const own = platform === "darwin" ? macChecks() : platform === "win32" ? windowsChecks() : platform === "linux" ? linuxChecks() : [];
    return [swift, ...own, lldbDap, node];
}

/** What this machine has of everything it needs, component by component. */
export async function checkToolchain(platform: NodeJS.Platform = process.platform): Promise<Finding[]> {
    const findings: Finding[] = [];
    for (const each of checks(platform)) {
        let found: string | undefined;
        try {
            found = await each.look();
        } catch {
            found = undefined;
        }
        findings.push({ component: each.component, neededBy: each.neededBy, found, advice: each.advice });
    }
    return findings;
}

/** The LLDB DAP extension, which a Debug launch hands the head to, found among the debugger types the editor has. */
export function debuggerFinding(types: readonly string[]): Finding {
    return {
        component: "the LLDB DAP extension", neededBy: "Debug", found: types.includes("lldb-dap") ? "installed" : undefined,
        advice: "Install LLDB DAP (llvm-vs-code-extensions.lldb-dap) from the Extensions view.",
    };
}

/** The findings as the output shows them: a line each, found or missing, and what to install for each missing. */
export function report(findings: readonly Finding[]): string[] {
    return findings.map((each) => each.found !== undefined
        ? `✓ ${each.component} - ${each.found} [${each.neededBy}]`
        : `✗ ${each.component} - not found [${each.neededBy}]. ${each.advice}`);
}
