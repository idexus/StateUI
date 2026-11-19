// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What makes the EDITOR work as one host.
//
// A host is a trait. The language server reads each package's own file,
// .sourcekit-lsp/config.json, so the editor writes there: beside every
// application's Package.swift the host's trait (`swiftPM.traits`), which
// defines the host's condition in the application's code, and beside the
// host's head - a package of its own, Platforms/<Host>, which enables the trait
// itself - that head's index. Then the language server is restarted.
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
// AND THE HOST'S CONDITION IS GIVEN AS A FLAG TOO. SourceKit-LSP 6.4.2's
// build system enables no trait the file names - measured, Looks.swift was
// compiled without `-DAPPKIT` under `traits: ["AppKit"]` - and its Swift Build
// one leaves a build server running in the index's folder, which no restart
// stops. In an application's own package a trait defines its condition and
// nothing else, so `swiftCompilerFlags: ["-DAPPKIT"]` beside it is the same
// build, until the server enables the trait itself.
//
// AND A RESTART WAITS FOR THE BUILDS ALREADY RUNNING THERE. A server that is
// stopped does not stop the build it started, so a quick switch there and back
// had two servers building in one directory - the same failure, a few seconds
// apart. Switches therefore run one at a time, and each waits until no build is
// running in the directories its server is about to build in.
//
// ONE PACKAGE IS INDEXED AS ONE HOST AT A TIME: its .sourcekit-lsp/config.json is
// one file, which two windows working as two hosts would write in turn - each
// server then building as its own host in the other's scratch folder. Before it
// writes, the editor takes the tool's lease of its packages (`index/acquire`);
// where another window holds one as another host, it writes nothing.
//
// A HOST WHOSE HEADS RUN ON ANOTHER PLATFORM IS INDEXED FOR THAT PLATFORM, as
// the stateui tool says (`index/describe`): its scratch folder, and for Android
// and the Web the Swift SDK of the toolchain's release and the triple, for UIKit
// the triple and the iOS simulator's SDK - SwiftPM's own command infers that
// SDK from the triple, but the server's SwiftPM does not: measured, it compiled
// for the simulator against the macOS SDK, and nothing in a UIKit head
// resolved. Where the SDK is missing the editor still works as the host,
// compiling for this machine, and says why.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { pathOf } from "./applications";
import { describe, Host, HostDescription, hosts } from "./hosts";
import { IndexCleaning, IndexConflict, IndexContext, IndexLease } from "./Tooling/protocol";

/** What the stateui tool says `host`'s code is indexed with - nothing where it could not say, which it said. */
export type IndexDescriber = (host: Host | undefined) => Promise<IndexContext | undefined>;

/** The tool's lease of `roots` as `host` for this window - nothing where it could not answer, which it said. */
export type IndexAcquirer = (host: Host | undefined, roots: readonly string[]) => Promise<IndexLease | undefined>;

/** Another window indexes a package as another host: the editor's mode was left as it was. */
export class IndexConflictError extends Error {
    constructor(readonly conflict: IndexConflict) {
        super(`another window indexes ${pathOf(conflict.rootUri)} as ${conflict.host ? describe(conflict.host).label : "plain Swift"}`);
    }
}

let queue: Promise<unknown> = Promise.resolve();

/**
 * Makes the editor work as `host` for the applications in `roots` - as plain
 * Swift with no host: each application's trait and index directory, its head's
 * index, and - where any changed - a restart of the language server once
 * nothing is building where it will build.
 *
 * Calls are queued, so a second switch waits for the first to finish.
 *
 * @returns whether anything changed - nothing where the tool answered no lease of `roots`.
 * @throws IndexConflictError where another window indexes one of `roots` as another host, nothing changed.
 */
export function applyEditorMode(host: Host | undefined, roots: readonly string[], describeIndex: IndexDescriber,
    acquireIndex: IndexAcquirer): Promise<boolean> {
    const next = queue.then(() => apply(host, roots, describeIndex, acquireIndex));
    queue = next.catch(() => undefined);
    return next;
}

async function apply(host: Host | undefined, roots: readonly string[], describeIndex: IndexDescriber,
    acquireIndex: IndexAcquirer): Promise<boolean> {
    // A lease held comes before anything is written: none answered - the tool unreachable - writes nothing.
    const lease = roots.length > 0 ? await acquireIndex(host, roots) : undefined;
    if (roots.length > 0 && lease === undefined) {
        return false;
    }
    if (lease?.conflict) {
        throw new IndexConflictError(lease.conflict);
    }
    const context = roots.length > 0 ? await describeIndex(host) : undefined;
    if (!context) {
        await excludeOtherHosts(host);
        return false;
    }
    if (context.fallback && host) {
        void vscode.window.showWarningMessage(
            `StateUI: ${context.fallback}, so the editor compiles the code for this machine rather than for ${describe(host).label}.`);
    }
    const trait = context.trait;
    const heads = trait === undefined ? [] : roots.map((root) => path.join(root, "Platforms", trait))
        .filter((head) => fs.existsSync(path.join(head, "Package.swift")));

    let changed = false;
    for (const root of roots) {
        changed = writeServerConfig(root, serverSettings(context)) || changed;
    }
    for (const head of heads) {
        changed = writeServerConfig(head, serverSettings(context, "head")) || changed;
    }
    await excludeOtherHosts(host);

    if (changed) {
        // A Swift extension still activating starts its server after this; the restart then waits for it, unawaited.
        const restart = settle([...roots, ...heads].map((folder) => path.join(folder, context.scratchPath))).then(() => restartServer());
        if (vscode.extensions.getExtension(swiftExtension)?.isActive) {
            await restart;
        } else {
            restart.then(undefined, () => undefined);
        }
    }

    return changed;
}

/** The Swift extension, which starts the language server. */
const swiftExtension = "swiftlang.swift-vscode";

/**
 * `exclusions` - `swift.excludePathsFromActivation` - excluding the packages of every host but `host`, and of every
 * host with none: each host's own `lib/StateUI/StateUI.<Host>` (with the packages inside it), its backends
 * `lib/Backends/<Element>.<Host>` and every application's head for it, `Platforms/<Host>`. Anything else it says is
 * kept.
 */
export function otherHostsExcluded(host: Host | undefined, exclusions: Readonly<Record<string, boolean>>): Record<string, boolean> {
    const patterns = (each: HostDescription): string[] =>
        [`**/lib/StateUI/StateUI.${each.label}`, `**/lib/Backends/*.${each.label}`, `**/Platforms/${each.label}`];
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
    const { command, args } = buildingCommand(directory);
    return new Promise((resolve) => {
        execFile(command, args, (error) => resolve(error === null));
    });
}

/**
 * The command that ends well where a process names `directory` on its command line, on `platform`: `pgrep`, which
 * Windows has none of - there PowerShell asks for the processes, itself left out.
 */
export function buildingCommand(directory: string, platform: NodeJS.Platform = process.platform): { command: string; args: string[] } {
    if (platform !== "win32") {
        return { command: "pgrep", args: ["-f", directory] };
    }
    const quoted = directory.replace(/'/g, "''");
    return {
        command: "powershell",
        args: ["-NoProfile", "-Command", `if (Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine `
            + `-and $_.CommandLine.Contains('${quoted}') }) { exit 0 } else { exit 1 }`],
    };
}

/**
 * Removes every host's index directory under `roots`, for an index a failed
 * build left inconsistent. The language server builds it again when restarted.
 *
 * @throws IndexConflictError where another window indexes one of `roots`: the tool left it, and the server is not
 * restarted.
 */
export async function cleanIndex(
    roots: readonly string[], clean: (roots: readonly string[]) => Promise<IndexCleaning | undefined>): Promise<void> {
    await settle(roots.map((root) => path.join(root, ".build")));
    const cleaning = await clean(roots);
    const conflict = cleaning?.conflicts?.[0];
    if (conflict) {
        throw new IndexConflictError(conflict);
    }
    await restartServer();
}

/**
 * Restarts the Swift extension's language server. A server still loading its packages may not stop within the two
 * seconds that extension gives it, and a client still starting refuses to stop: a refused restart is asked again,
 * every `pause` milliseconds, `attempts` times in all, the last refusal the caller's.
 */
export async function restartServer(
    restart: () => Thenable<unknown> = () => vscode.commands.executeCommand("swift.restartLSPServer"),
    attempts = 30, pause = 2000): Promise<void> {
    for (let attempt = 1; ; attempt += 1) {
        try {
            await restart();
            return;
        } catch (error) {
            if (attempt >= attempts) {
                throw error;
            }
            await new Promise((resume) => setTimeout(resume, pause));
        }
    }
}

/** What the language server is told about one host, under `swiftPM`. */
export interface ServerSettings {
    readonly traits?: readonly string[];
    readonly swiftCompilerFlags?: readonly string[];
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
 * What the language server is told for an index `context` in a package of `kind`: its scratch folder, its SDK and
 * triple where it has them, and in an application's own package the host's trait and the condition it defines - a
 * head's package enables its own.
 */
export function serverSettings(context: IndexContext, kind: "application" | "head" = "application"): ServerSettings {
    const trait = kind === "application" ? context.trait : undefined;
    return Object.fromEntries(Object.entries({
        traits: trait !== undefined ? [trait] : undefined,
        swiftCompilerFlags: trait !== undefined ? [`-D${trait.toUpperCase()}`] : undefined,
        scratchPath: context.scratchPath, swiftSDK: context.swiftSDK, sdk: context.sdk, triple: context.triple,
    }).filter((entry) => entry[1] !== undefined)) as unknown as ServerSettings;
}

/** The flags a host's trait stands for in an application: its condition, `-DAPPKIT`. */
const hostConditions = new Set(hosts.map((each) => `-D${each.label.toUpperCase()}`));

/**
 * `config` saying `settings` and preparing by building: traits, an SDK, a
 * triple and a host's condition that `settings` leave out are removed, anything
 * else the file says - flags of the user's own too - is kept.
 */
export function serverConfig(config: ServerConfig, settings: ServerSettings): ServerConfig {
    const owned = ["traits", "swiftSDK", "sdk", "triple", "swiftCompilerFlags"];
    const kept = Object.entries(config.swiftPM ?? {}).filter(([key]) => !owned.includes(key));
    const own = ((config.swiftPM?.swiftCompilerFlags as string[] | undefined) ?? []).filter((flag) => !hostConditions.has(flag));
    const flags = [...own, ...(settings.swiftCompilerFlags ?? [])];
    const { swiftCompilerFlags: _, ...rest } = settings;
    return {
        ...config,
        swiftPM: { ...Object.fromEntries(kept), ...rest, ...(flags.length > 0 ? { swiftCompilerFlags: flags } : {}) },
        backgroundPreparationMode: "build",
    };
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
