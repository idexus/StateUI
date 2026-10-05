// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What makes the EDITOR work as one host.
//
// Every extension runs in one extension-host process, and the Swift extension
// starts SourceKit-LSP with that process's environment beneath the
// `swift.swiftEnvironmentVariables` setting. So the host's variable is set
// here, on this process, and the language server is restarted: the variable is
// written to no settings file, and the manifest - whose cache keys on the
// environment - declares the host's head and defines its condition. StateUI
// does not wait for the Swift extension to activate: it sets the variable as it
// activates itself, before that extension starts the server.
//
// EACH HOST INDEXES IN A DIRECTORY OF ITS OWN. The server prepares modules for
// its index with a build, and one directory shared by two hosts is two
// differently configured builds in one place - measured: "couldn't build
// GalleryUI.swiftmodule because of missing inputs". The directory is
// `swiftPM.scratchPath` in .sourcekit-lsp/config.json, the server's own file,
// which it reads from the root of EACH package and resolves against it - so it
// is written beside every application's Package.swift, and ignored by git.
//
// AND THE INDEX IS PREPARED BY BUILDING, not by the server's default
// preparation. An application depends on the DYNAMIC StateUI product, and
// SwiftPM's `--experimental-prepare-for-indexing` then asks for a
// libStateUI.dylib it never links - measured on the command line: "couldn't
// build GalleryUI.swiftmodule because of missing inputs: …/libStateUI.dylib",
// exit 1, where a plain build of the target succeeds in 8 s. Without the module,
// nothing in Platforms/AppKit that imports the application resolves. So the
// same file says `backgroundPreparationMode: build`.
//
// AND A RESTART WAITS FOR THE BUILDS ALREADY RUNNING THERE. A server that is
// stopped does not stop the build it started, so a quick switch there and back
// had two servers building in one directory - the same failure, a few seconds
// apart. Switches therefore run one at a time, and each waits until no build is
// running in the directories its server is about to build in.
//
// A HOST WHOSE HEADS RUN ON ANOTHER PLATFORM IS INDEXED FOR THAT PLATFORM. For
// Android the same file names the Swift SDK of the toolchain's release and the
// triple, found as .scripts/Android/build-swift.sh finds them. With no such SDK
// installed the editor still works as the host, compiling for this Mac, and
// says so. For UIKit it names the triple and the iOS simulator's SDK, which
// Xcode ships - found as .scripts/UIKit/tools.sh finds it. SwiftPM's own
// command infers that SDK from the triple, but the server's SwiftPM does not:
// measured, it compiled for the simulator against the macOS SDK, and nothing
// in a UIKit head resolved.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { describe, environment, Host, HostDescription, hostVariable, hosts, plainIndexPath } from "./hosts";

let queue: Promise<unknown> = Promise.resolve();

/**
 * Makes the editor work as `host` for the packages in `roots` - as plain Swift
 * with no host: this process's environment, each package's index directory,
 * and - where either changed - a restart of the language server once nothing
 * is building where it will build.
 *
 * Calls are queued, so a second switch waits for the first to finish.
 *
 * @returns whether anything changed.
 */
export function applyEditorMode(host: Host | undefined, roots: readonly string[]): Promise<boolean> {
    const next = queue.then(() => apply(host, roots));
    queue = next.catch(() => undefined);
    return next;
}

async function apply(host: Host | undefined, roots: readonly string[]): Promise<boolean> {
    let changed = setHostEnvironment(host);
    const settings = serverSettings(host, roots.length > 0 ? await installedSwiftSDK(host) : undefined,
        roots.length > 0 ? await xcodeSDKPath(host) : undefined);

    for (const root of roots) {
        changed = writeServerConfig(root, settings) || changed;
    }
    await excludeOtherHosts(host);

    if (changed) {
        // A Swift extension still activating starts its server after this; the restart then waits for it, unawaited.
        const restart = settle(roots.map((root) => path.join(root, settings.scratchPath)))
            .then(() => vscode.commands.executeCommand("swift.restartLSPServer"));
        if (vscode.extensions.getExtension(swiftExtension)?.isActive) {
            await restart;
        } else {
            restart.then(undefined, () => undefined);
        }
    }

    return changed;
}

/** The Swift extension, which starts the language server with this process's environment. */
const swiftExtension = "swiftlang.swift-vscode";

/**
 * Sets this process's environment for `host` at once: called before the Swift extension starts its server, it starts
 * the server as that host with no restart.
 *
 * @returns whether anything changed.
 */
export function setHostEnvironment(host: Host | undefined): boolean {
    let changed = false;
    for (const [variable, value] of Object.entries(environment(host))) {
        if (process.env[variable] === value) {
            continue;
        }
        if (value === undefined) {
            delete process.env[variable];
        } else {
            process.env[variable] = value;
        }
        changed = true;
    }
    return changed;
}

/**
 * `exclusions` - `swift.excludePathsFromActivation` - excluding the packages of every host but `host`, and of every
 * host with none: each host's own `lib/StateUI/StateUI.<Host>` (with the packages inside it) and its backends
 * `lib/Backends/<Element>.<Host>`. Anything else it says is kept.
 */
export function otherHostsExcluded(host: Host | undefined, exclusions: Readonly<Record<string, boolean>>): Record<string, boolean> {
    const patterns = (each: HostDescription): string[] =>
        [`**/lib/StateUI/StateUI.${each.label}`, `**/lib/Backends/*.${each.label}`];
    const owned = new Set(hosts.flatMap(patterns));
    const kept = Object.entries(exclusions).filter(([pattern]) => !owned.has(pattern));
    const excluded = hosts.filter((each) => each.id !== host).flatMap(patterns).map((pattern) => [pattern, true] as const);
    return Object.fromEntries([...kept, ...excluded].sort(([a], [b]) => a.localeCompare(b)));
}

/**
 * Keeps the Swift extension from loading the packages of the hosts the editor does not work as - each costs its
 * activation seconds - in the user's settings, which it reads as it starts: the next start of the editor.
 */
async function excludeOtherHosts(host: Host | undefined): Promise<void> {
    const swift = vscode.workspace.getConfiguration("swift");
    const current = swift.inspect<Record<string, boolean>>("excludePathsFromActivation")?.globalValue ?? {};
    const next = otherHostsExcluded(host, current);
    if (JSON.stringify(next) !== JSON.stringify(current)) {
        await swift.update("excludePathsFromActivation", next, vscode.ConfigurationTarget.Global);
    }
}

/** Waits until no process is building in any of `directories`. */
async function settle(directories: readonly string[]): Promise<void> {
    const status = vscode.window.setStatusBarMessage("$(sync~spin) StateUI: waiting for the index build to finish");

    try {
        while ((await Promise.all(directories.map(building))).some(Boolean)) {
            await new Promise((resume) => setTimeout(resume, 1000));
        }
    } finally {
        status.dispose();
    }
}

/** Whether a process names `directory` on its command line - a build there. */
function building(directory: string): Promise<boolean> {
    return new Promise((resolve) => {
        execFile("pgrep", ["-f", directory], (error) => resolve(error === null));
    });
}

/**
 * Removes every host's index directory under `roots`, for an index a failed
 * build left inconsistent. The language server builds it again when restarted.
 */
export async function cleanIndex(roots: readonly string[]): Promise<void> {
    const directories = roots.flatMap((root) =>
        [...hosts.map((each) => each.indexPath), plainIndexPath].map((indexPath) => path.join(root, indexPath)));

    await settle(directories);
    for (const directory of directories) {
        fs.rmSync(directory, { recursive: true, force: true });
    }
    await vscode.commands.executeCommand("swift.restartLSPServer");
}

/**
 * The host variable, where a settings file sets it. The setting is laid over
 * this process's environment, so the variable found there decides the editor's
 * mode whatever host is chosen.
 */
export function variablesInSettings(): string[] {
    const settings = vscode.workspace.getConfiguration("swift").get<Record<string, string>>("swiftEnvironmentVariables") ?? {};

    return Object.keys(settings).filter((variable) => variable === hostVariable);
}

/** What the language server is told about one host, under `swiftPM`. */
export interface ServerSettings {
    readonly scratchPath: string;
    readonly swiftSDK?: string;
    readonly sdk?: string;
    readonly triple?: string;
}

/** The language server's own file, .sourcekit-lsp/config.json. */
export interface ServerConfig {
    swiftPM?: Record<string, unknown>;
    backgroundPreparationMode?: string;
    [key: string]: unknown;
}

/**
 * What the language server is told while the editor works as `host`: the
 * host's index directory and - for a host compiled for another platform, where
 * its Swift SDK `swiftSDK` is installed, or Xcode's SDK is found at `sdk` -
 * that SDK and the triple. With no host, SwiftPM's own index directory and no
 * SDK.
 */
export function serverSettings(host: Host | undefined, swiftSDK?: string, sdk?: string): ServerSettings {
    if (!host) {
        return { scratchPath: plainIndexPath };
    }
    const { indexPath, target } = describe(host);
    if (target?.xcodeSDK) {
        return sdk ? { scratchPath: indexPath, sdk, triple: target.triple } : { scratchPath: indexPath };
    }
    return target && swiftSDK ? { scratchPath: indexPath, swiftSDK, triple: target.triple } : { scratchPath: indexPath };
}

/**
 * `config` saying `settings` and preparing by building: an SDK and a triple
 * that `settings` leave out are removed, anything else the file says is kept.
 */
export function serverConfig(config: ServerConfig, settings: ServerSettings): ServerConfig {
    const kept = Object.entries(config.swiftPM ?? {}).filter(([key]) => !["swiftSDK", "sdk", "triple"].includes(key));
    return { ...config, swiftPM: { ...Object.fromEntries(kept), ...settings }, backgroundPreparationMode: "build" };
}

/**
 * The release a Swift version names - `6.4` in `swift --version`'s "Swift
 * version 6.4" or in the SDK id `swift-6.4.0-RELEASE_android`: a release
 * ending in `.0` is the release without it, as build-swift.sh reads it.
 */
export function swiftRelease(text: string): string | undefined {
    const version = text.match(/Swift version (\d+\.\d+(\.\d+)?)/)?.[1] ?? text.match(/\d+\.\d+(\.\d+)?/)?.[0];
    return version?.replace(/^(\d+\.\d+)\.0$/, "$1");
}

/**
 * The Swift SDK of `release` whose id ends in `_<family>`, among the ids
 * `swift sdk list` printed as `list` - the last one, as build-swift.sh takes it.
 * `wasm` is `swift-6.4.0-RELEASE_wasm`, never its Embedded Swift sibling `_wasm-embedded`.
 */
export function swiftSDKOf(release: string | undefined, list: string, family: string): string | undefined {
    return release === undefined
        ? undefined
        : list.split(/\s+/).filter((id) => id.toLowerCase().endsWith(`_${family}`) && swiftRelease(id) === release).pop();
}

/**
 * The Swift SDK the language server compiles `host` with - or nothing, for a
 * host of this machine and, said in a warning, where none is installed.
 */
async function installedSwiftSDK(host: Host | undefined): Promise<string | undefined> {
    const { label, target } = host ? describe(host) : { label: "", target: undefined };
    if (!target?.swiftSDK) {
        return undefined;
    }

    const swift = (args: string[]): Promise<string> => new Promise((resolve) =>
        execFile("swift", args, (_error, stdout, stderr) => resolve(`${stdout}${stderr}`)));
    const release = swiftRelease(await swift(["--version"]));
    const found = swiftSDKOf(release, await swift(["sdk", "list"]), target.swiftSDK);

    if (!found) {
        void vscode.window.showWarningMessage(
            `StateUI: no Swift SDK for ${label} of ${release ? `Swift ${release}` : "this toolchain's release"} is installed, `
            + `so the editor compiles the code for this Mac rather than for ${label}. [Install the Swift SDK for ${label}](${target.swiftSDKGuide}).`);
    }
    return found;
}

/**
 * Where Xcode's SDK for `host` is - or nothing, for a host with none and, said in a warning, where Xcode has not
 * got it.
 */
async function xcodeSDKPath(host: Host | undefined): Promise<string | undefined> {
    const { label, target } = host ? describe(host) : { label: "", target: undefined };
    if (!target?.xcodeSDK) {
        return undefined;
    }

    const found = await new Promise<string | undefined>((resolve) =>
        execFile("xcrun", ["--sdk", target.xcodeSDK!, "--show-sdk-path"], (error, stdout) =>
            resolve(error ? undefined : stdout.trim() || undefined)));
    if (!found) {
        void vscode.window.showWarningMessage(
            `StateUI: Xcode's ${target.xcodeSDK} SDK was not found, so the editor compiles the code for this Mac rather than for ${label}.`);
    }
    return found;
}

/**
 * Sets `settings` and the preparation mode in `root`/.sourcekit-lsp/config.json,
 * keeping anything else the file says.
 *
 * @returns whether the file changed.
 */
function writeServerConfig(root: string, settings: ServerSettings): boolean {
    const directory = path.join(root, ".sourcekit-lsp");
    const file = path.join(directory, "config.json");

    let config: ServerConfig = {};
    if (fs.existsSync(file)) {
        try {
            config = JSON.parse(fs.readFileSync(file, "utf8"));
        } catch {
            void vscode.window.showWarningMessage(`StateUI: ${file} is not JSON, so the index directory was not set.`);
            return false;
        }
    }

    const next = serverConfig(config, settings);
    if (JSON.stringify(next) === JSON.stringify(config)) {
        return false;
    }

    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(file, JSON.stringify(next, null, 2) + "\n");
    return true;
}
