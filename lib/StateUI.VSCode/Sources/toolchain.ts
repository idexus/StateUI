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

    /** The version found that does not serve, older than the least the component names; undefined where none was. */
    readonly tooOld?: string;

    /** How to get it, where it is missing. */
    readonly advice: string;
}

/** A version found that does not serve: older than the least a component names. */
class TooOld {
    constructor(readonly version: string) {}
}

/** One component's check: what it is, who needs it, how to look for it, and how to get it. */
interface Check {
    readonly component: string;
    readonly neededBy: string;
    readonly advice: string;
    readonly look: () => Promise<string | TooOld | undefined>;
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

/** The loader a glycin loader's config names for SVG pictures - its `[loader:image/svg+xml]` - or undefined where it names none. */
export function svgLoaderInGlycin(config: string): string | undefined {
    const section = config.split(/\r?\n(?=\s*\[)/).find((part) => /^\s*\[loader:image\/svg\+xml\]/.test(part));
    const exec = section?.match(/^\s*Exec\s*=\s*(.+?)\s*$/m)?.[1];
    return exec ? path.basename(exec) : undefined;
}

/** glycin's SVG loader, among the loader configs of the data folders - where gdk-pixbuf 2.44 and newer read pictures
 *  through glycin - or undefined. */
function glycinSVGLoader(): string | undefined {
    const folders = (process.env.XDG_DATA_DIRS || "/usr/local/share:/usr/share").split(":")
        .concat(process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share"));
    for (const folder of folders.filter((each) => each.length > 0)) {
        const loaders = path.join(folder, "glycin-loaders");
        for (const version of fs.existsSync(loaders) ? fs.readdirSync(loaders) : []) {
            const configs = path.join(loaders, version, "conf.d");
            for (const file of fs.existsSync(configs) ? fs.readdirSync(configs).filter((each) => each.endsWith(".conf")) : []) {
                const loader = svgLoaderInGlycin(fs.readFileSync(path.join(configs, file), "utf8"));
                if (loader) {
                    return `glycin's ${loader}`;
                }
            }
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

/** A found version where it is `minimum` or newer, said with where it was found; one older, as too old. */
function served(version: string | undefined, minimum: string, where?: string): string | TooOld | undefined {
    if (version === undefined) {
        return undefined;
    }
    return atLeast(version, minimum) ? (where ? `${version} (${where})` : version) : new TooOld(version);
}

/** The first Apple Development identity `security find-identity -v -p codesigning` lists, by its name. */
export function developmentIdentityIn(text: string): string | undefined {
    return text.match(/"(Apple Development: [^"]+)"/)?.[1];
}

/** An NDK's release in its `source.properties`: "30.0.16248370". */
export function ndkRevisionIn(properties: string): string | undefined {
    return properties.match(/^Pkg\.Revision\s*=\s*(\S+)/m)?.[1];
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

/** Git, which New Project Group lists StateUI's releases with and clones one by. */
const git: Check = {
    component: "Git", neededBy: "New Project Group's releases",
    advice: "Install Git from https://git-scm.com.",
    look: async () => {
        const version = versionIn((await run("git", ["--version"])) ?? "");
        return version && `${version} (${onPath("git")})`;
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
            component: "WebKitGTK 6.0, with its headers", neededBy: "GTK's web view (lib/Backends/WebView.GTK), the GTK host's tests included",
            advice: "Install libwebkitgtk-6.0-dev on Ubuntu, webkitgtk-6.0 on Arch: the web view's backend links it.",
            look: async () => served((await run("pkg-config", ["--modversion", "webkitgtk-6.0"]))?.trim(), "2.40"),
        },
        {
            component: "gdk-pixbuf's SVG loader", neededBy: "GTK's pictures",
            advice: "Install librsvg2-common - or, where gdk-pixbuf reads through glycin, glycin's loaders (glycin on Arch):"
                + " without one GTK draws no SVG picture.",
            look: async () => {
                const cache = process.env.GDK_PIXBUF_MODULE_FILE
                    || (await run("pkg-config", ["--variable=gdk_pixbuf_cache_file", "gdk-pixbuf-2.0"]))?.trim();
                return (cache && fs.existsSync(cache) ? svgLoaderIn(fs.readFileSync(cache, "utf8")) : undefined)
                    ?? glycinSVGLoader();
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

/** The first swift.org toolchain of 6.4 or newer with a Swift SDK for Android of its own release, and that SDK's id. */
async function androidSwift(): Promise<{ swift: string; sdk: string } | undefined> {
    for (const candidate of swiftOrgToolchains()) {
        const text = (await run(candidate, ["--version"])) ?? "";
        const release = swiftRelease(text);
        if (!isSwiftOrgBuild(text) || release === undefined || !atLeast(release, "6.4")) {
            continue;
        }
        const sdk = swiftSDKOf(release, (await run(candidate, ["sdk", "list"])) ?? "", "android");
        if (sdk) {
            return { swift: candidate, sdk };
        }
    }
    return undefined;
}

/**
 * The NDK the Android build takes, where build-swift.sh looks and in its order: the one ANDROID_NDK_ROOT or
 * ANDROID_NDK_HOME names, the one the setup of the Swift SDK for Android `sdk` linked into its bundle, else the
 * Android SDK's newest.
 */
function ndkTheBuildTakes(sdk: string | undefined): string | undefined {
    const isNDK = (folder: string) => fs.existsSync(path.join(folder, "toolchains", "llvm", "prebuilt"));
    const named = [process.env.ANDROID_NDK_ROOT, process.env.ANDROID_NDK_HOME]
        .find((each): each is string => each !== undefined && each.length > 0 && isNDK(each));
    if (named) {
        return named;
    }
    const roots = [path.join(os.homedir(), "Library", "org.swift.swiftpm", "swift-sdks"), path.join(os.homedir(), ".swiftpm", "swift-sdks")];
    const bundles = roots
        .flatMap((root) => fs.existsSync(root)
            ? fs.readdirSync(root).filter((each) => each.endsWith(".artifactbundle")).map((each) => path.join(root, each))
            : [])
        .filter((bundle) => sdk !== undefined && fs.existsSync(path.join(bundle, "info.json"))
            && fs.readFileSync(path.join(bundle, "info.json"), "utf8").includes(`"${sdk}"`));
    for (const bundle of bundles) {
        const include = path.join(bundle, "swift-android", "ndk-sysroot", "usr", "include");
        if (fs.existsSync(include) && fs.lstatSync(include).isSymbolicLink()) {
            const prebuilt = ["", "toolchains", "llvm", "prebuilt", ""].join(path.sep);
            const linked = fs.readlinkSync(include).split(prebuilt)[0];
            if (isNDK(linked)) {
                return linked;
            }
        }
    }
    const folder = path.join(androidSDK(), "ndk");
    const newest = fs.existsSync(folder) ? fs.readdirSync(folder).sort(compareVersions).pop() : undefined;
    return newest && isNDK(path.join(folder, newest)) ? path.join(folder, newest) : undefined;
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
            component: "an Apple Development certificate", neededBy: "UIKit on an iPhone or iPad",
            advice: "Sign in with your Apple Account in Xcode's Settings, Accounts, and make a development certificate there;"
                + " Xcode makes a device's profile the first time it runs an application on it.",
            look: async () => developmentIdentityIn((await run("security", ["find-identity", "-v", "-p", "codesigning"])) ?? ""),
        },
        {
            component: "Swift 6.4 from swift.org, with the Swift SDK for Android of the same release", neededBy: "Android",
            advice: "Install the swift.org toolchain and its SDK: "
                + "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html",
            look: async () => {
                const found = await androidSwift();
                return found && `${found.sdk} (${found.swift})`;
            },
        },
        {
            component: "the Android SDK with platform 36 and its build tools", neededBy: "Android",
            advice: "Install it with Android Studio's SDK Manager, and set ANDROID_HOME where it is not ~/Library/Android/sdk.",
            look: async () => {
                const sdk = androidSDK();
                const tools = path.join(sdk, "build-tools");
                const aapt2 = fs.existsSync(tools)
                    && fs.readdirSync(tools).some((each) => fs.existsSync(path.join(tools, each, "aapt2")));
                return fs.existsSync(path.join(sdk, "platform-tools")) && fs.existsSync(path.join(sdk, "platforms", "android-36"))
                    && aapt2 ? sdk : undefined;
            },
        },
        {
            component: "the Android NDK r30 or newer", neededBy: "Android",
            advice: "Install it with Android Studio's SDK Manager, or name one with ANDROID_NDK_HOME.",
            look: async () => {
                const ndk = ndkTheBuildTakes((await androidSwift())?.sdk);
                if (ndk === undefined) {
                    return undefined;
                }
                const properties = path.join(ndk, "source.properties");
                const revision = fs.existsSync(properties) ? ndkRevisionIn(fs.readFileSync(properties, "utf8")) : undefined;
                return served(revision, "30", ndk);
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
            component: "the WebView2 runtime", neededBy: "WinUI's web view (lib/Backends/WebView.WinUI)",
            advice: "Install the Evergreen WebView2 Runtime from https://developer.microsoft.com/microsoft-edge/webview2 -"
                + " Windows 11 has it.",
            look: async () => {
                const application = path.join(programs, "Microsoft", "EdgeWebView", "Application");
                const version = fs.existsSync(application)
                    ? fs.readdirSync(application).filter((each) => /^\d+\./.test(each)).sort(compareVersions).pop() : undefined;
                return version && path.join(application, version);
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

/** What the Web host needs on macOS and Linux: the Swift SDK for WebAssembly of Swift's release, and Python to serve the page. */
function webChecks(): Check[] {
    return [
        {
            component: "the Swift SDK for WebAssembly of Swift's release", neededBy: "Web",
            advice: "Install it with `swift sdk install`: https://www.swift.org/documentation/articles/wasm-getting-started.html",
            look: async () => swiftSDKOf(swiftRelease((await run("swift", ["--version"])) ?? ""), (await run("swift", ["sdk", "list"])) ?? "", "wasm"),
        },
        {
            component: "Python 3", neededBy: "Web, which serves its page with it",
            advice: "Install Python 3: macOS's comes with Xcode's command line tools; on Linux, the distribution's python3.",
            look: async () => versionIn((await run("python3", ["--version"])) ?? ""),
        },
    ];
}

/** Every component this machine needs, in the order the check reads them. */
function checks(platform: NodeJS.Platform): Check[] {
    const own = platform === "darwin" ? macChecks() : platform === "win32" ? windowsChecks() : platform === "linux" ? linuxChecks() : [];
    const web = platform === "darwin" || platform === "linux" ? webChecks() : [];
    return [swift, ...own, ...web, lldbDap, git, node];
}

/** What this machine has of everything it needs, component by component. */
export async function checkToolchain(platform: NodeJS.Platform = process.platform): Promise<Finding[]> {
    const findings: Finding[] = [];
    for (const each of checks(platform)) {
        let looked: string | TooOld | undefined;
        try {
            looked = await each.look();
        } catch {
            looked = undefined;
        }
        const found = typeof looked === "string" ? looked : undefined;
        const tooOld = looked instanceof TooOld ? looked.version : undefined;
        findings.push({ component: each.component, neededBy: each.neededBy, found, tooOld, advice: each.advice });
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

/** Why an lldb-dap did not start, read from what it said to `--version` - the library its loader found missing - or
 *  undefined where it started. */
export function lldbDapFailure(output: string | undefined): string | undefined {
    if (output === undefined) {
        return "it did not run";
    }
    const missing = output.match(/error while loading shared libraries: ([^:\s]+)/);
    if (missing) {
        return `${missing[1]} is missing`;
    }
    return /LLVM version/.test(output) ? undefined : output.split(/\r?\n/)[0].trim();
}

/** The Python library `lldb-dap --check-python` printed as the one it resolved, or undefined where it found none. */
export function checkedPythonIn(output: string | undefined): string | undefined {
    return output?.split(/\r?\n/).map((line) => line.trim()).find((line) => /^[A-Za-z]:\\.*\.dll$/i.test(line));
}

/** On Linux and Windows, whether the lldb-dap a Debug launch starts - the one LLDB DAP's `lldb-dap.executable-path`
 *  names, else the search path's - starts with the Python its LLDB loads: on Linux the distribution's a swift.org
 *  toolchain was built for, which another may not have; on Windows the one the Swift installer lays beside the
 *  toolchain. Undefined on macOS, where Xcode's matches its system. */
export async function lldbDapFinding(configured?: string): Promise<Finding | undefined> {
    if (process.platform === "win32") {
        return windowsLldbDapFinding(configured || onPath("lldb-dap"));
    }
    if (process.platform !== "linux") {
        return undefined;
    }
    const executable = configured || onPath("lldb-dap");
    const output = executable ? await run(executable, ["--version"]) : undefined;
    const failure = executable ? lldbDapFailure(output) : "none is on the search path";
    return {
        component: "an lldb-dap that starts", neededBy: "Debug",
        found: failure === undefined ? `${output?.match(/LLVM version \S+/)?.[0] ?? "it starts"} (${executable})` : undefined,
        advice: `${executable ?? "lldb-dap"}: ${failure}. A swift.org toolchain's LLDB takes the Python library of the`
            + " distribution it was built for: install that library - libpython3.9 is python39 from the AUR on Arch - or"
            + " set lldb-dap.executable-path to an lldb-dap that starts.",
    };
}

/** Windows' lldb-dap asked which Python library it loads (`--check-python`): `--version` answers before it looks. */
async function windowsLldbDapFinding(executable: string | undefined): Promise<Finding> {
    const output = executable ? await run(executable, ["--check-python"]) : undefined;
    const python = checkedPythonIn(output);
    const failure = !executable ? "none is on the search path" : output?.split(/\r?\n/)[0].trim() || "it did not run";
    return {
        component: "an lldb-dap that starts", neededBy: "Debug",
        found: python && `its Python ${python} (${executable})`,
        advice: `${executable ?? "lldb-dap"}: ${failure}. A swift.org toolchain's LLDB loads the Python its installer lays`
            + " beside the toolchain (Programs\\Swift\\Python-<version>): repair the Swift installation, or set"
            + " lldb-dap.executable-path to an lldb-dap that starts.",
    };
}

/** The findings as the output shows them: a line each, found, too old or missing, and what to install for each not found. */
export function report(findings: readonly Finding[]): string[] {
    return findings.map((each) => each.found !== undefined
        ? `✓ ${each.component} - ${each.found} [${each.neededBy}]`
        : `✗ ${each.component} - ${each.tooOld !== undefined ? `${each.tooOld} found, too old` : "not found"} [${
            each.neededBy}]. ${each.advice}`);
}
