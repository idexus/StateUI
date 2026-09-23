// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What makes the EDITOR work as one host.
//
// Every extension runs in one extension-host process, and the Swift extension
// starts SourceKit-LSP with that process's environment beneath the
// `swift.swiftEnvironmentVariables` setting. So the host's variable is set
// here, on this process, and the language server is restarted: nothing is
// written to a settings file, and the manifest - whose cache keys on the
// environment - declares the host's head and defines its condition.
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
// says so.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { describe, environment, Host, hosts } from "./hosts";

let queue: Promise<unknown> = Promise.resolve();

/**
 * Makes the editor work as `host` for the packages in `roots`: this process's
 * environment, each package's index directory, and - where either changed - a
 * restart of the language server once nothing is building where it will build.
 *
 * Calls are queued, so a second switch waits for the first to finish.
 *
 * @returns whether anything changed.
 */
export function applyEditorMode(host: Host, roots: readonly string[]): Promise<boolean> {
    const next = queue.then(() => apply(host, roots));
    queue = next.catch(() => undefined);
    return next;
}

async function apply(host: Host, roots: readonly string[]): Promise<boolean> {
    let changed = false;
    const settings = serverSettings(host, roots.length > 0 ? await installedSwiftSDK(host) : undefined);

    for (const root of roots) {
        changed = writeServerConfig(root, settings) || changed;
    }

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

    if (changed) {
        await settle(roots.map((root) => path.join(root, describe(host).indexPath)));
        await vscode.commands.executeCommand("swift.restartLSPServer");
    }

    return changed;
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
    const directories = roots.flatMap((root) => hosts.map((each) => path.join(root, each.indexPath)));

    await settle(directories);
    for (const directory of directories) {
        fs.rmSync(directory, { recursive: true, force: true });
    }
    await vscode.commands.executeCommand("swift.restartLSPServer");
}

/**
 * The host variables a settings file sets. The setting is laid over this
 * process's environment, so a variable found there decides the editor's mode
 * whatever host is chosen.
 */
export function variablesInSettings(): string[] {
    const settings = vscode.workspace.getConfiguration("swift").get<Record<string, string>>("swiftEnvironmentVariables") ?? {};
    const known = new Set(hosts.flatMap((each) => (each.variable ? [each.variable] : [])));

    return Object.keys(settings).filter((variable) => known.has(variable));
}

/** What the language server is told about one host, under `swiftPM`. */
export interface ServerSettings {
    readonly scratchPath: string;
    readonly swiftSDK?: string;
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
 * its Swift SDK `swiftSDK` is installed - that SDK and the triple.
 */
export function serverSettings(host: Host, swiftSDK?: string): ServerSettings {
    const { indexPath, target } = describe(host);
    return target && swiftSDK ? { scratchPath: indexPath, swiftSDK, triple: target.triple } : { scratchPath: indexPath };
}

/**
 * `config` saying `settings` and preparing by building: an SDK and a triple
 * that `settings` leave out are removed, anything else the file says is kept.
 */
export function serverConfig(config: ServerConfig, settings: ServerSettings): ServerConfig {
    const kept = Object.entries(config.swiftPM ?? {}).filter(([key]) => key !== "swiftSDK" && key !== "triple");
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
 * The Swift SDK of `release` whose id names `family`, among the ids
 * `swift sdk list` printed as `list` - the last one, as build-swift.sh takes it.
 */
export function swiftSDKOf(release: string | undefined, list: string, family: string): string | undefined {
    return release === undefined
        ? undefined
        : list.split(/\s+/).filter((id) => id.toLowerCase().includes(family) && swiftRelease(id) === release).pop();
}

/**
 * The Swift SDK the language server compiles `host` with - or nothing, for a
 * host of this machine and, said in a warning, where none is installed.
 */
async function installedSwiftSDK(host: Host): Promise<string | undefined> {
    const { label, target } = describe(host);
    if (!target) {
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
