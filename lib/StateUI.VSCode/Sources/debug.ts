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
// An Android head is run by .scripts/Android/run-app.sh, which builds, installs
// and starts it on the device chosen, in a task whose terminal then follows its
// log. A Debug launch is then attached to by lldb-dap: the script readies the
// NDK's lldb-server in the application's sandbox and writes where it listens to
// .build-android/debugger.json. A Release build cannot be debugged, and
// resolves to no session.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead. A MAUI head is debugged the
// way StateUI: Select Debugger chose - C#, Swift, or both on Mac Catalyst.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { Application, appKitProgram } from "./applications";
import { androidScript } from "./devices";
import { environment, Host, MauiDebugger } from "./hosts";

/** Which build a launch runs. */
export type Configuration = "debug" | "release";

/** The choices a launch runs: the host, and the application for it. */
export interface Choices {
    host(): Host;

    /**
     * The application to run on `host` - the one named, else the one chosen,
     * else asked for - or nothing, where there is none or the user declined.
     */
    application(folder: vscode.WorkspaceFolder, host: Host, named?: string): Promise<Application | undefined>;

    /** How a MAUI head is debugged. */
    debugger(): MauiDebugger;

    /** Runs a build as a task and answers its exit code. */
    run(task: vscode.Task): Promise<number | undefined>;

    /** Starts a task that runs until it is stopped - a head followed by its log. */
    start(task: vscode.Task): Promise<void>;

    /**
     * Waits, while `task` runs, for it to write `file`; whether it did before
     * it ended.
     */
    ready(file: string, task: vscode.Task): Promise<boolean>;

    /**
     * The serial of the Android device a launch runs on - the one chosen while
     * it is attached, else asked for - or nothing, where none is picked.
     */
    device(folder: vscode.WorkspaceFolder): Promise<string | undefined>;

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
        if (host === "android") {
            return this.android(root, application, configuration, name);
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
            const script = await this.buildScript(project, `net10.0-${target}`, "run-app.sh");
            if (!script) {
                return undefined;
            }
            const started = await this.succeeds(root, application, `Run ${application.name} (${target}, ${configuration})`,
                new vscode.ShellExecution("bash", [script, target, build, project], { cwd: root.uri.fsPath }));
            return started ? attach(application.name) : undefined;
        }

        case "csharp-swift-maccatalyst":
            this.choices.attachSwiftWhenStarted(name, application.name);
            return { ...csharp, targetFramework: "net10.0-maccatalyst27.0" };

        case "swift":
            if (platform === "linux") {
                return (await linuxBuild())
                    ? { type: "lldb-dap", request: "launch", name, program: linuxProgram, cwd: path.dirname(linuxProgram), stopOnEntry: false }
                    : undefined;
            }
            {
                const script = await this.buildScript(project, "net10.0-windows10.0.19041.0", "run-app.ps1");
                if (!script) {
                    return undefined;
                }
                const started = await this.succeeds(root, application, `Run ${application.name} (Windows, ${configuration})`,
                    new vscode.ShellExecution("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
                        "-Configuration", build, "-Project", project], { cwd: root.uri.fsPath }));
                // LLDB on Windows matches a process name WITH its extension.
                return started ? attach(`${application.name}.exe`) : undefined;
            }
        }
    }

    /**
     * An Android head, started by run-app.sh in a task that follows its log;
     * a Debug build then attached to by lldb-dap, through the lldb-server the
     * script readied - a Release build has no session.
     */
    private async android(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const script = androidScript(root.uri.fsPath, "run-app.sh");
        if (!fs.existsSync(script)) {
            void vscode.window.showErrorMessage(
                `StateUI: an Android head runs through a StateUI checkout's .scripts/Android/run-app.sh, which ${root.name} does not have.`);
            return undefined;
        }

        const serial = await this.choices.device(root);
        if (!serial) {
            return undefined;
        }

        const debug = configuration === "debug";
        const facts = path.join(application.directory, ".build-android", "debugger.json");
        fs.rmSync(facts, { force: true });
        const task = new vscode.Task(
            { type: "stateui", application: application.name, configuration, device: serial }, root,
            `Run ${application.name} (Android, ${configuration})`, "StateUI",
            new vscode.ShellExecution("bash",
                [script, application.directory, configuration, serial, ...(debug ? ["--debugger"] : [])],
                { cwd: root.uri.fsPath }), []);
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
        await this.choices.start(task);
        if (!debug) {
            return undefined;
        }

        if (!(await this.choices.ready(facts, task))) {
            void vscode.window.showErrorMessage(
                `StateUI: ${application.name} did not start for the debugger on ${serial} - the terminal says why.`);
            return undefined;
        }
        return androidAttach(name, serial, JSON.parse(fs.readFileSync(facts, "utf8")));
    }

    /**
     * A script of the StateUI build `project` imports - the one its own build
     * runs with, whether that is a checkout's or the StateUI.Maui package's -
     * or nothing, said, where the project imports none.
     */
    private async buildScript(project: string, targetFramework: string, script: string): Promise<string | undefined> {
        const directory = await stateUIBuildDirectory(project, targetFramework);
        const found = directory && path.join(directory, script);
        if (found && fs.existsSync(found)) {
            return found;
        }
        void vscode.window.showErrorMessage(
            `StateUI: ${path.basename(project)} imports no StateUI build with ${script} - it references neither a StateUI checkout's .scripts/Maui/StateUI.targets nor the StateUI.Maui package.`);
        return undefined;
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

/** Where run-app.sh --debugger left the application, and its debugger's server. */
export interface AndroidDebugger {
    /** The package, the process started, the server's socket, and the libraries unstripped. */
    package: string;
    process: number;
    socket: string;
    symbols: string;
}

/**
 * lldb-dap attached to an Android head's process through the lldb-server that
 * runs in its sandbox: the device named in the address, whichever others are
 * attached, and the libraries read from the build, which kept them unstripped.
 * The runtime raises SIGSEGV and SIGBUS on purpose - its null and suspend
 * checks - so they pass to it without stopping the session. LLDB does not
 * follow the code the runtime's JIT compiles: announced to it method by
 * method, each stopping the whole application, over USB it froze the UI
 * thread for seconds.
 */
export function androidAttach(name: string, serial: string, server: AndroidDebugger): vscode.DebugConfiguration {
    return {
        type: "lldb-dap",
        request: "attach",
        name,
        stopOnEntry: false,
        initCommands: [
            "settings set plugin.jit-loader.gdb.enable off",
            "platform select remote-android",
            `platform connect unix-abstract-connect://${serial}/${server.socket}`,
            `settings append target.exec-search-paths ${server.symbols}`,
        ],
        attachCommands: [
            `process attach --pid ${server.process}`,
            "process handle SIGSEGV --pass true --stop false --notify false",
            "process handle SIGBUS --pass true --stop false --notify false",
        ],
    };
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

/**
 * Where the StateUI build a MAUI project imports lives, for `targetFramework`:
 * `.scripts/Maui/` of the checkout it is built against, or
 * `buildTransitive/Maui/` of the StateUI.Maui package it references. Asked of
 * MSBuild, so it is the directory the project's own build runs from.
 *
 * Restored first and without the framework - a restore handed one framework
 * restores that one alone - since a restore is what brings a package's build
 * into the project. Then asked WITH it: NuGet imports a package's build per
 * target framework, so a project evaluated for none of them has none.
 */
export async function stateUIBuildDirectory(project: string, targetFramework: string): Promise<string | undefined> {
    // No node reuse: a worker left behind would hold these calls' output open.
    const msbuild = (args: string[]): Promise<{ failed: boolean; output: string }> => new Promise((resolve) =>
        execFile("dotnet", ["msbuild", project, ...args, "-nologo", "-nodeReuse:false"], { cwd: path.dirname(project) },
            (error, stdout) => resolve({ failed: error !== null, output: stdout })));

    await msbuild(["-t:Restore"]);
    const asked = await msbuild(["-getProperty:StateUIBuildDir", `-p:TargetFramework=${targetFramework}`]);
    const directory = asked.output.trim().split(/\r?\n/).pop()?.trim();
    return !asked.failed && directory ? directory : undefined;
}
