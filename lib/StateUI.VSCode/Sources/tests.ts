// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The suites a workspace holds, run AS THE CHOSEN HOST - the same runs
// .scripts/test-native.sh and CI make, one condition at a time.

import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { findApplications } from "./applications";
import { environment, Host } from "./hosts";
import { runTask } from "./tasks";

/** One suite, and the command that runs it. */
export interface Suite {
    readonly label: string;
    readonly detail: string;
    readonly command: string;
    readonly args: readonly string[];
    readonly env: Record<string, string>;
}

/**
 * The suites under `root` for `host`, in the order they are best run: the
 * library first, the hosts' packages next, the applications last.
 *
 * - A Swift package with a test target runs with `swift test`. An
 *   APPLICATION runs as the host - `STATEUI_APPKIT=1` on `.build-appkit`, or
 *   `-Xswiftc -DMAUI` on `.build-maui` - and so does the library, whose code
 *   under `#if MAUI` compiles only in a MAUI run.
 * - A host's own package - `lib/StateUI.AppKit` - runs only for that host.
 * - A C# test project - `lib/StateUI.Maui/Tests` - runs for the MAUI host.
 */
export function findSuites(root: string, host: Host): Suite[] {
    const suites: Suite[] = [];
    const applications = new Set(findApplications(root).map((each) => each.directory));
    const appKitEnvironment = Object.fromEntries(
        Object.entries(environment("appkit")).filter((entry): entry is [string, string] => entry[1] !== undefined));

    const packages = [root, ...children(path.join(root, "lib")), ...children(path.join(root, "apps"))];
    for (const directory of packages) {
        const manifest = path.join(directory, "Package.swift");
        if (!fs.existsSync(manifest) || !fs.readFileSync(manifest, "utf8").includes(".testTarget(")) {
            continue;
        }

        const name = directory === root ? path.basename(root) : path.relative(root, directory);
        const hostPackage = path.basename(directory).match(/\.(AppKit|Maui)$/)?.[1]?.toLowerCase();
        if (hostPackage && hostPackage !== host) {
            continue;
        }

        const base = ["test", "--package-path", directory];
        if (hostPackage) {
            suites.push({ label: name, detail: `swift test - ${host === "appkit" ? "the AppKit" : "the MAUI"} host's own package`, command: "swift", args: base, env: {} });
        } else if (host === "maui") {
            suites.push({
                label: name, detail: "swift test -Xswiftc -DMAUI, on .build-maui", command: "swift",
                args: [...base, "--scratch-path", path.join(directory, ".build-maui"), "-Xswiftc", "-DMAUI"], env: {},
            });
        } else if (applications.has(directory)) {
            suites.push({
                label: name, detail: "swift test as an AppKit build, on .build-appkit", command: "swift",
                args: [...base, "--scratch-path", path.join(directory, ".build-appkit")], env: appKitEnvironment,
            });
        } else {
            suites.push({ label: name, detail: "swift test", command: "swift", args: base, env: {} });
        }
    }

    if (host === "maui") {
        for (const directory of children(path.join(root, "lib"))) {
            const tests = path.join(directory, "Tests");
            if (fs.existsSync(tests) && fs.readdirSync(tests).some((entry) => entry.endsWith(".csproj"))) {
                suites.push({ label: path.relative(root, tests), detail: "dotnet test", command: "dotnet", args: ["test", tests], env: {} });
            }
        }
    }

    return suites;
}

function children(directory: string): string[] {
    return fs.existsSync(directory)
        ? fs.readdirSync(directory).sort().map((entry) => path.join(directory, entry)).filter((entry) => fs.statSync(entry).isDirectory())
        : [];
}

/**
 * Runs `suites` one after another, each as a task of its own, and answers the
 * labels of those that failed. A failure does not stop the ones after it: the
 * point of running them all is to see all of them.
 */
export async function runSuites(folder: vscode.WorkspaceFolder, suites: readonly Suite[]): Promise<string[]> {
    const failed: string[] = [];

    for (const suite of suites) {
        const task = new vscode.Task(
            { type: "stateui", suite: suite.label }, folder, `Test ${suite.label}`, "StateUI",
            new vscode.ShellExecution(suite.command, [...suite.args], { cwd: folder.uri.fsPath, env: suite.env }), []);
        task.group = vscode.TaskGroup.Test;
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };

        if ((await runTask(task)) !== 0) {
            failed.push(suite.label);
        }
    }

    return failed;
}
