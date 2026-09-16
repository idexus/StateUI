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
// Every launch asks which application to run, the last one run offered first;
// a launch configuration naming its `application` asks nothing.

import * as vscode from "vscode";
import { Application, appKitProgram, findApplications } from "./applications";
import { environment, Host } from "./hosts";

/** Which build a launch runs. */
export type Configuration = "debug" | "release";

/** The host chosen in the status bar, and where the last application run is kept. */
export interface Choices {
    host(): Host;
    readonly state: vscode.Memento;
}

const lastRunKey = "stateui.lastApplication";

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

        const application = await this.application(root, host, launch.application);
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

    /**
     * The application a launch runs on `host`: the one it names, the only one
     * there is, or the one picked - with the last one run offered first.
     */
    private async application(
        folder: vscode.WorkspaceFolder,
        host: Host,
        named: unknown,
    ): Promise<Application | undefined> {
        const candidates = findApplications(folder.uri.fsPath)
            .filter((each) => (host === "appkit" ? each.hasAppKitHead : each.mauiProject !== undefined));
        const head = host === "appkit" ? "an AppKit head (Platforms/AppKit/main.swift)" : "a MAUI head (Platforms/Maui/*.csproj)";

        if (candidates.length === 0) {
            void vscode.window.showErrorMessage(`StateUI: no application here has ${head}.`);
            return undefined;
        }

        if (typeof named === "string") {
            const found = candidates.find((each) => each.name === named);
            if (!found) {
                void vscode.window.showErrorMessage(`StateUI: no application named ${named} has ${head}.`);
            }
            return found;
        }

        let chosen = candidates[0];
        if (candidates.length > 1) {
            const last = this.choices.state.get<string>(lastRunKey);
            const ordered = [...candidates].sort((a, b) => Number(b.name === last) - Number(a.name === last));
            const picked = await vscode.window.showQuickPick(
                ordered.map((each) => ({
                    label: each.name,
                    description: each.name === last ? "last run" : undefined,
                    detail: vscode.workspace.asRelativePath(each.directory),
                    application: each,
                })),
                { placeHolder: "Which application?", ignoreFocusOut: true });

            if (!picked) {
                return undefined;
            }
            chosen = picked.application;
        }

        await this.choices.state.update(lastRunKey, chosen.name);
        return chosen;
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
    const env = defined(environment("appkit"));
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

    return (await run(task)) === 0;
}

/** Runs a task and answers its exit code - listening before it starts, so a quick one is not missed. */
function run(task: vscode.Task): Promise<number | undefined> {
    return new Promise((resolve, reject) => {
        let started: vscode.TaskExecution | undefined;
        let ended = false;

        const listener = vscode.tasks.onDidEndTaskProcess((event) => {
            if (started ? event.execution === started : event.execution.task.definition === task.definition) {
                listener.dispose();
                ended = true;
                resolve(event.exitCode);
            }
        });

        vscode.tasks.executeTask(task).then(
            (execution) => { started = execution; },
            (error) => { listener.dispose(); if (!ended) { reject(error); } });
    });
}

function defined(values: Record<string, string | undefined>): Record<string, string> {
    return Object.fromEntries(Object.entries(values).filter((entry): entry is [string, string] => entry[1] !== undefined));
}
