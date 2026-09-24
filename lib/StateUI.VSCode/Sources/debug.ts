// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// ONE Debug and ONE Release, whatever the host.
//
// A `stateui` configuration is never debugged itself: it is resolved into the
// configuration the chosen host's own debugger takes - lldb-dap for an AppKit
// head, which is built first. Resolved in the FIRST hook, so the new type's
// resolvers still run over it. On a machine that runs no host, nothing is
// resolved and the launch says so.
//
// An Android head is run by .scripts/Android/run-app.sh, which builds, installs
// and starts it on the device chosen, in a task whose terminal then follows its
// log. A Debug launch is then attached to by lldb-dap: the script readies the
// NDK's lldb-server in the application's sandbox and writes where it listens to
// .build-android/debugger.json. A Release build cannot be debugged, and
// resolves to no session.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead.

import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { Application, appKitProgram } from "./applications";
import { androidScript } from "./devices";
import { environment, Host } from "./hosts";

/** Which build a launch runs. */
export type Configuration = "debug" | "release";

/** The choices a launch runs: the host, and the application for it. */
export interface Choices {
    /** The host chosen - nothing on a machine that runs none. */
    host(): Host | undefined;

    /**
     * The application to run on `host` - the one named, else the one chosen,
     * else asked for - or nothing, where there is none or the user declined.
     */
    application(folder: vscode.WorkspaceFolder, host: Host, named?: string): Promise<Application | undefined>;

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
}

/** What a machine that runs no host is told, wherever a host is asked for. */
export const noHost = "no StateUI host runs on this machine yet - AppKit and Android are built and run on macOS.";

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

        if (!host) {
            void vscode.window.showErrorMessage(`StateUI: ${noHost}`);
            return undefined;
        }

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
