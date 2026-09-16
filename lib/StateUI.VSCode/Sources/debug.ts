// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// ONE Debug and ONE Release, whatever the host.
//
// A `stateui` configuration is never debugged itself: it is resolved into the
// configuration the chosen host's own debugger takes - lldb-dap for an AppKit
// head, which is built first, and the MAUI extension's `maui` for a MAUI head,
// on the device that extension's own picker chose. Resolved in the FIRST hook,
// so the new type's resolvers still run over it.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead.

import * as vscode from "vscode";
import { Application, appKitProgram } from "./applications";
import { environment, Host } from "./hosts";
import { runTask } from "./tasks";

/** Which build a launch runs. */
export type Configuration = "debug" | "release";

/** The choices a launch runs: the host, and the application for it. */
export interface Choices {
    host(): Host;

    /**
     * The application to run on `host` - the one named, else the one chosen,
     * else asked for - or nothing, where there is none or the reader declined.
     */
    application(folder: vscode.WorkspaceFolder, host: Host, named?: string): Promise<Application | undefined>;
}

/** The two configurations every workspace offers. */
export function configurations(): vscode.DebugConfiguration[] {
    return [
        { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" },
        { name: "StateUI: Release", type: "stateui", request: "launch", configuration: "release" },
    ];
}

export class StateUIDebugConfigurationProvider implements vscode.DebugConfigurationProvider {
    constructor(private readonly choices: Choices) {}

    provideDebugConfigurations(): vscode.DebugConfiguration[] {
        return configurations();
    }

    async resolveDebugConfiguration(
        folder: vscode.WorkspaceFolder | undefined,
        launch: vscode.DebugConfiguration,
    ): Promise<vscode.DebugConfiguration | undefined> {
        // F5 with no launch.json at all arrives as an empty configuration.
        const configuration: Configuration = launch.configuration === "release" ? "release" : "debug";
        const name = launch.name || (configuration === "release" ? "StateUI: Release" : "StateUI: Debug");
        const host = this.choices.host();

        const root = folder ?? vscode.workspace.workspaceFolders?.[0];
        if (!root) {
            void vscode.window.showErrorMessage("StateUI: open the folder of a StateUI application first.");
            return undefined;
        }

        const named = typeof launch.application === "string" ? launch.application : undefined;
        const application = await this.choices.application(root, host, named);
        if (!application) {
            return undefined;
        }

        if (host === "maui") {
            return {
                type: "maui",
                request: "launch",
                name,
                project: application.mauiProject,
                ...(configuration === "release" ? { configuration: "Release" } : {}),
            };
        }

        if (!(await buildAppKitHead(root, application, configuration))) {
            void vscode.window.showErrorMessage(
                `StateUI: the AppKit build of ${application.name} failed - its output is in the terminal.`);
            return undefined;
        }

        return {
            type: "lldb-dap",
            request: "launch",
            name,
            program: appKitProgram(application, configuration),
            cwd: root.uri.fsPath,
            stopOnEntry: false,
        };
    }
}

/**
 * Builds an application's AppKit head the way the command line does - its
 * bundling script where it has one, SwiftPM otherwise - as a task whose output
 * shows in the terminal.
 *
 * @returns whether the build succeeded.
 */
export async function buildAppKitHead(
    folder: vscode.WorkspaceFolder,
    application: Application,
    configuration: Configuration,
): Promise<boolean> {
    const env = Object.fromEntries(
        Object.entries(environment("appkit")).filter((entry): entry is [string, string] => entry[1] !== undefined));
    const execution = application.bundleScript
        ? new vscode.ShellExecution(application.bundleScript, [configuration], { cwd: folder.uri.fsPath, env })
        : new vscode.ShellExecution(
            "swift",
            ["build", "--package-path", application.directory, "--configuration", configuration,
                "--product", `${application.name}AppKit`],
            { cwd: folder.uri.fsPath, env });

    const definition = { type: "stateui", application: application.name, configuration };
    const task = new vscode.Task(
        definition, folder, `Build ${application.name} (AppKit, ${configuration})`, "StateUI", execution, []);
    task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };

    return (await runTask(task)) === 0;
}
