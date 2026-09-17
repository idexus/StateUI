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
// naming its `application` runs that one instead. A MAUI head is debugged the
// way StateUI: Select Debugger chose - C#, Swift, or both on Mac Catalyst.

import * as path from "path";
import * as vscode from "vscode";
import { Application, appKitProgram } from "./applications";
import { environment, Host, MauiDebugger } from "./hosts";

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

    /** How a MAUI head is debugged. */
    debugger(): MauiDebugger;

    /** Runs a build as a task and answers its exit code. */
    run(task: vscode.Task): Promise<number | undefined>;

    /**
     * Attaches lldb-dap to `processName` once the C# session named
     * `sessionName` has started it - both debuggers against one process.
     */
    attachSwiftWhenStarted(sessionName: string, processName: string): void;

    /** The machine the launch runs on; the tests name one. */
    readonly platform?: NodeJS.Platform;
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
            return this.maui(root, application, configuration, name);
        }

        if (!(await buildAppKitHead(root, application, configuration, (task) => this.choices.run(task)))) {
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

    /** A MAUI head, debugged the way StateUI: Select Debugger chose. */
    private async maui(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const platform = this.choices.platform ?? process.platform;
        const project = asLoaded(application.mauiProject!, platform);
        const build = configuration === "release" ? "Release" : "Debug";
        const csharp: vscode.DebugConfiguration = {
            type: "maui", request: "launch", name, project,
            ...(configuration === "release" ? { configuration: "Release" } : {}),
            // ON WINDOWS A RELEASE LAUNCH NAMES ITS EXECUTABLE: the MAUI
            // extension works the executable out without the configuration and
            // looks in bin/Debug. No architecture in the path, because the
            // project keeps the runtime identifier out of its output path.
            ...(configuration === "release" && platform === "win32"
                ? { program: path.join(path.dirname(project), "bin", "Release", "net10.0-windows10.0.19041.0", `${application.name}.exe`) }
                : {}),
        };

        // Linux's head is a plain net10.0 executable, beside its runtime and
        // artwork, which no MAUI extension launches.
        const linuxProgram = path.join(path.dirname(project), "bin", build, "net10.0", application.name);
        const linuxBuild = (): Promise<boolean> => this.succeeds(root, application, `Build ${application.name} (MAUI, Linux, ${configuration})`,
            new vscode.ShellExecution("dotnet", ["build", project, "-c", build, "-nodeReuse:false"], { cwd: root.uri.fsPath }));

        const attach = (processName: string): vscode.DebugConfiguration => ({
            type: "lldb-dap", request: "attach", name, stopOnEntry: false,
            attachCommands: [`process attach --name ${processName}`],
        });

        switch (this.choices.debugger()) {
        case "csharp":
            if (platform !== "linux") {
                return csharp;
            }
            return (await linuxBuild())
                ? { type: "coreclr", request: "launch", name, program: linuxProgram, cwd: path.dirname(linuxProgram), console: "internalConsole", stopAtEntry: false }
                : undefined;

        case "swift-ios":
        case "swift-maccatalyst": {
            // Started WITHOUT a debugger, then attached to: the simulator's
            // watchdog kills an app a debugger holds stopped at launch.
            const target = this.choices.debugger() === "swift-ios" ? "ios" : "maccatalyst";
            const script = path.join(root.uri.fsPath, ".scripts", "Maui", "run-app.sh");
            const started = await this.succeeds(root, application, `Run ${application.name} (${target}, ${configuration})`,
                new vscode.ShellExecution("bash", [script, target, build, project], { cwd: root.uri.fsPath }));
            return started ? attach(application.name) : undefined;
        }

        case "csharp-swift-maccatalyst":
            this.choices.attachSwiftWhenStarted(name, application.name);
            return { ...csharp, targetFramework: "net10.0-maccatalyst" };

        case "swift":
            if (platform === "linux") {
                return (await linuxBuild())
                    ? { type: "lldb-dap", request: "launch", name, program: linuxProgram, cwd: path.dirname(linuxProgram), stopOnEntry: false }
                    : undefined;
            }
            {
                const script = path.join(root.uri.fsPath, ".scripts", "Maui", "run-app.ps1");
                const started = await this.succeeds(root, application, `Run ${application.name} (Windows, ${configuration})`,
                    new vscode.ShellExecution("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
                        "-Configuration", build, "-Project", project], { cwd: root.uri.fsPath }));
                // LLDB on Windows matches a process name WITH its extension.
                return started ? attach(`${application.name}.exe`) : undefined;
            }
        }
    }

    /** Runs one step before a launch as a task, and says so where it failed. */
    private async succeeds(root: vscode.WorkspaceFolder, application: Application, label: string, execution: vscode.ShellExecution): Promise<boolean> {
        const task = new vscode.Task({ type: "stateui", application: application.name }, root, label, "StateUI", execution, []);
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };

        if ((await this.choices.run(task)) === 0) {
            return true;
        }
        void vscode.window.showErrorMessage(`StateUI: ${label} failed - its output is in the terminal.`);
        return false;
    }
}

/**
 * `project` spelled as C# Dev Kit loads it. The MAUI extension finds a launch's
 * project by comparing that text with the path of each project loaded, and on
 * Windows those name the drive in upper case, where a workspace folder's
 * `fsPath` names it in lower case.
 */
function asLoaded(project: string, platform: NodeJS.Platform): string {
    return platform === "win32" ? project.replace(/^[a-z]:/, (drive) => drive.toUpperCase()) : project;
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
    run: (task: vscode.Task) => Promise<number | undefined>,
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

    return (await run(task)) === 0;
}
