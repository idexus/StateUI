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

    for (const root of roots) {
        changed = writeServerConfig(root, describe(host).indexPath) || changed;
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

/**
 * Sets the index directory and the preparation mode in
 * `root`/.sourcekit-lsp/config.json, keeping anything else the file says.
 *
 * @returns whether the file changed.
 */
function writeServerConfig(root: string, indexPath: string): boolean {
    const directory = path.join(root, ".sourcekit-lsp");
    const file = path.join(directory, "config.json");

    let config: { swiftPM?: Record<string, unknown>; backgroundPreparationMode?: string } = {};
    if (fs.existsSync(file)) {
        try {
            config = JSON.parse(fs.readFileSync(file, "utf8"));
        } catch {
            void vscode.window.showWarningMessage(`StateUI: ${file} is not JSON, so the index directory was not set.`);
            return false;
        }
    }

    if (config.swiftPM?.scratchPath === indexPath && config.backgroundPreparationMode === "build") {
        return false;
    }

    config.swiftPM = { ...config.swiftPM, scratchPath: indexPath };
    config.backgroundPreparationMode = "build";
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
    return true;
}
