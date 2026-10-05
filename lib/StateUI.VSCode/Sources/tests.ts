// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The suites a workspace holds, run AS THE CHOSEN HOST - the same runs
// .scripts/test-native.sh and CI make, one condition at a time.

import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { findApplications } from "./applications";
import { androidScript } from "./devices";
import { describe, environment, Host } from "./hosts";
import { uiKitScript } from "./uiKitDevices";
import { runTask } from "./tasks";

/** One suite, and the command that runs it. */
export interface Suite {
    readonly label: string;
    readonly detail: string;
    readonly command: string;
    readonly args: readonly string[];
    readonly env: Record<string, string>;

    /**
     * Whether it runs on the host's device - an Android device, a simulator for UIKit - whose serial or UDID ends
     * its arguments once one is chosen.
     */
    readonly onDevice?: boolean;
}

/**
 * The suites under `root` for `host`, in the order they are best run: the
 * library first, the hosts' packages next, the applications, then a device's suite.
 *
 * - A Swift package with a test target runs with `swift test`. For AppKit an
 *   APPLICATION runs as the host - `STATEUI_HOST=appkit` on `.build/appkit`.
 * - A host's own package - `lib/StateUI/StateUI.AppKit`, or its tests' own,
 *   `lib/StateUI/StateUI.GTK/Testing` - and a backend for a host -
 *   `lib/Backends/WebView.GTK` - run only for that host.
 * - For the Android host an application runs as plain Swift, its Android build
 *   running only on a device, and the host's own tests -
 *   `lib/StateUI/StateUI.Android/Tests` - run on the device chosen, by
 *   `.scripts/Android/test-android.sh`.
 * - For the UIKit host an application runs as plain Swift, and the host's own
 *   tests - an application, `lib/StateUI/StateUI.UIKit/Tests` - run on the simulator
 *   chosen, by `.scripts/UIKit/test-uikit.sh`.
 * - For the WinUI host an application runs as plain Swift, and the host's own
 *   package runs by `.scripts/WinUI/test-winui.ps1`, which lays the Windows
 *   App SDK beside its test runner first.
 * - For the GTK host an application runs as plain Swift, and the host's own
 *   package with `swift test`, its windows on the desktop's display.
 * - For the Web host an application runs as plain Swift, and the host's own
 *   package - `lib/StateUI/StateUI.Web/Testing`, compiled for WebAssembly - by
 *   `.scripts/Web/test-web.sh`, in Node over a page with just enough of a DOM.
 * - With no host - a machine that runs none - every package but the hosts'
 *   own runs as plain Swift.
 */
export function findSuites(root: string, host: Host | undefined): Suite[] {
    const suites: Suite[] = [];
    const applications = new Set(findApplications(root).map((each) => each.directory));
    const appKitEnvironment = Object.fromEntries(
        Object.entries(environment("appkit")).filter((entry): entry is [string, string] => entry[1] !== undefined));

    // The library's packages stand in lib/StateUI, the backends in lib/Backends, and a package's own tests may
    // stand in a package of their own, Testing, inside it.
    const library = [path.join(root, "lib"), path.join(root, "lib", "StateUI"), path.join(root, "lib", "Backends")];
    const grouped = library.flatMap(children);
    const packages = [root, ...grouped.flatMap((each) => [each, path.join(each, "Testing")]), ...children(path.join(root, "apps"))];
    for (const directory of packages) {
        const manifest = path.join(directory, "Package.swift");
        if (!fs.existsSync(manifest) || !fs.readFileSync(manifest, "utf8").includes(".testTarget(")) {
            continue;
        }

        // A label reads the same on every platform: a path written with forward slashes.
        const name = directory === root ? path.basename(root) : path.relative(root, directory).split(path.sep).join("/");
        const owner = path.basename(directory) === "Testing" ? path.dirname(directory) : directory;
        const forHost = path.basename(owner).match(/\.(AppKit|UIKit|Android|WinUI|GTK|Web)$/)?.[1]?.toLowerCase();
        if (forHost && forHost !== host) {
            continue;
        }
        // A backend - lib/Backends/<Element>.<Host> - runs for its host by swift test, never as the host's own package.
        if (forHost && path.basename(path.dirname(owner)) === "Backends") {
            suites.push({ label: name, detail: `swift test - a backend for the ${describe(forHost as Host).label} host`, command: "swift", args: ["test", "--package-path", directory], env: {} });
            continue;
        }
        const hostPackage = forHost;

        const base = ["test", "--package-path", directory];
        const winUITests = path.join(root, ".scripts", "WinUI", "test-winui.ps1");
        const webTests = path.join(root, ".scripts", "Web", "test-web.sh");
        if (hostPackage === "web" && fs.existsSync(webTests)) {
            suites.push({
                label: name, detail: "test-web.sh - the Web host's own package, compiled for WebAssembly and run in Node",
                command: "bash", args: [webTests], env: {},
            });
        } else if (hostPackage === "winui" && fs.existsSync(winUITests)) {
            suites.push({
                label: name, detail: "test-winui.ps1 - the WinUI host's own package, the Windows App SDK beside its runner",
                command: "powershell", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", winUITests], env: {},
            });
        } else if (hostPackage && host) {
            suites.push({ label: name, detail: `swift test - the ${describe(host).label} host's own package`, command: "swift", args: base, env: {} });
        } else if (host === "appkit" && applications.has(directory)) {
            suites.push({
                label: name, detail: "swift test as an AppKit build, on .build/appkit", command: "swift",
                args: [...base, "--scratch-path", path.join(directory, ".build", "appkit")], env: appKitEnvironment,
            });
        } else {
            suites.push({ label: name, detail: "swift test", command: "swift", args: base, env: {} });
        }
    }

    const testScript = androidScript(root, "test-android.sh");
    if (host === "android" && fs.existsSync(testScript)) {
        suites.push({
            label: "lib/StateUI/StateUI.Android/Tests", detail: "test-android.sh - the Android host's own tests, on the device chosen",
            command: "bash", args: [testScript], env: {}, onDevice: true,
        });
    }

    const uiKitTests = uiKitScript(root, "test-uikit.sh");
    if (host === "uikit" && fs.existsSync(uiKitTests)) {
        suites.push({
            label: "lib/StateUI/StateUI.UIKit/Tests", detail: "test-uikit.sh - the UIKit host's own tests, on the simulator chosen",
            command: "bash", args: [uiKitTests], env: {}, onDevice: true,
        });
    }

    return suites;
}

/** `suite` run on the device `serial` - an Android device's serial, a simulator's UDID - where it runs on one. */
export function forDevice(suite: Suite, serial: string): Suite {
    return suite.onDevice ? { ...suite, args: [...suite.args, serial] } : suite;
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
