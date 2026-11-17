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
// An Android head is built and started by the stateui tool (`application/run`)
// on the device chosen, its log followed in StateUI Run. A Debug launch readies
// the NDK's lldb-server in the application's sandbox; the run's `started` event
// says its socket and the process, and lldb-dap attaches through it. The debug
// session's end stops the run. A Release build has no session.
//
// A UIKit head is built and started by the stateui tool (`application/run`) on
// the iPhone, iPad or simulator chosen, its output followed in StateUI Run. A
// Debug launch starts it held until a debugger attaches; the run's `started`
// event says its process - on a simulator one of this Mac's, a device's
// reached through the device - and lldb-dap attaches, which lets it run. The
// debug session's end stops the run. A Release launch has no session.
//
// A GTK head is built and installed for the user by the stateui tool, a copy
// still running stopped, and launched by lldb-dap: the debugger is the
// application's parent, which is what Ubuntu's ptrace scope permits.
//
// A WinUI head is built by the stateui tool - a running copy stopped first, its
// executable written again - for this machine's architecture, and launched by
// lldb-dap, which reads the DWARF the head carries.
//
// A head of a host this machine works in a guest - GTK and WinUI on a Mac, as
// the stateui tool says (`server/info`) - is built and started in the guest
// chosen by the tool (`application/run`), its output followed in StateUI Run.
// Where the tool says no debugger reaches the guest, a Debug launch runs the
// debug build without one, said, and neither has a session.
//
// A Web head is built, laid out and served by the stateui tool
// (`application/run`), which opens the page in the browser chosen. A Debug
// launch in a browser a debugger follows, as the tool says - one of
// Chromium's - has the page served alone, and VS Code's own
// JavaScript debugger starts that browser's program on the address the
// `started` event says: the console in the Debug Console, a breakpoint in the
// relay; the debug session's end stops the run. Any other browser the tool
// opens, with no session.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead.

import { execFile } from "child_process";
import * as vscode from "vscode";
import { Application, pathOf } from "./applications";
import { Browser } from "./browsers";
import { Guest } from "./guests";
import { lldbDapFinding } from "./toolchain";
import { Host } from "./hosts";
import { LaunchedApplication, Place } from "./Tooling/protocol";

/** Which build a launch runs. */
export type Configuration = "debug" | "release";

/** The choices a launch runs: the host, and the application for it. */
export interface Choices {
    /** The host chosen - nothing on a machine that runs none. */
    host(): Host | undefined;

    /** Where `host`'s heads run from this machine, as the stateui tool says - nothing where it builds none. */
    place(host: Host): Place | undefined;

    /**
     * The application to run on `host` - the one named, else the one chosen,
     * else asked for - or nothing, where there is none or the user declined.
     */
    application(folder: vscode.WorkspaceFolder, host: Host, named?: string): Promise<Application | undefined>;

    /**
     * Has the stateui tool build `application` for `host` in `configuration` and answers the program its build
     * published - nothing where it failed or was cancelled, which the tool's error said.
     */
    build(folder: vscode.WorkspaceFolder, application: Application, host: Host, configuration: Configuration): Promise<string | undefined>;

    /**
     * What the tool knows the Android device a launch runs on by - the one
     * chosen while it is listed, else asked for - or nothing, where none is
     * picked.
     */
    device(): Promise<string | undefined>;

    /**
     * The iPhone, iPad or simulator a UIKit launch runs on - the one chosen
     * while it is listed, else asked for - or nothing, where none is picked.
     */
    uiKitDevice(): Promise<string | undefined>;

    /**
     * The guest a launch of `host` is built and run in, where this machine works it in one: the one chosen while it
     * is listed, else asked for - or nothing, where none is picked.
     */
    guest(host: Host): Promise<Guest | undefined>;

    /**
     * Has the stateui tool build `application` for `host` in `configuration` and start it on `device` - a debugger
     * readied where `debug` - following its output; once it started, what started and the token a debug session
     * carries, whose end stops the run - nothing where it failed or was cancelled, which the tool's error said.
     */
    runHead(
        folder: vscode.WorkspaceFolder, application: Application, host: Host, configuration: Configuration, device: string, debug: boolean,
    ): Promise<{ launched: LaunchedApplication; token: string } | undefined>;

    /**
     * The browser a Web launch opens the page in - the one chosen while it is installed, else asked for - or nothing,
     * where none is picked.
     */
    browser(): Promise<Browser | undefined>;
}

/** What a machine that runs no host is told, wherever a host is asked for. */
export const noHost = "the stateui tool builds no StateUI host on this machine - `stateui version` names the hosts it builds and where.";


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

        // A page needs no lldb-dap: its debugger is the browser's; a guest's is the tool's to give.
        if (host === "web") {
            return this.web(root, application, configuration, name);
        }
        if (this.choices.place(host) === "guest") {
            return this.inGuest(root, application, host, configuration);
        }

        // A debugger that cannot start stops the launch before the build, saying why: else the build ends and nothing runs.
        const debuggerStarts = await lldbDapFinding(vscode.workspace.getConfiguration("lldb-dap").get<string>("executable-path"));
        if (debuggerStarts && debuggerStarts.found === undefined) {
            void vscode.window.showErrorMessage(`StateUI: the debugger does not start - ${debuggerStarts.advice}`);
            return undefined;
        }

        if (host === "android") {
            return this.android(root, application, configuration, name);
        }

        if (host === "uikit") {
            return this.uiKit(root, application, configuration, name);
        }

        if (host === "gtk") {
            return this.gtk(root, application, configuration, name);
        }

        // AppKit and WinUI: built by the stateui tool, lldb-dap launching the program it published.
        const program = await this.choices.build(root, application, host, configuration);
        if (!program) {
            return undefined;
        }

        return {
            type: "lldb-dap",
            request: "launch",
            name,
            program,
            cwd: root.uri.fsPath,
            stopOnEntry: false,
        };
    }

    /**
     * An Android head, built and started on the device chosen by the stateui tool, which follows its log; a Debug
     * build's debugger server readied in its sandbox and attached to by lldb-dap, the session's end stopping the run -
     * a Release build has no session.
     */
    private async android(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const device = await this.choices.device();
        if (!device) {
            return undefined;
        }
        const debug = configuration === "debug";
        const running = await this.choices.runHead(root, application, "android", configuration, device, debug);
        if (!running || !debug) {
            return undefined;
        }
        const { launched, token } = running;
        const serial = launched.build.destination?.id;
        if (launched.process === undefined || !launched.debuggerSocket || !serial || !launched.build.symbolsUri) {
            void vscode.window.showErrorMessage(`StateUI: ${application.name} started, but where a debugger attaches is not known.`);
            return undefined;
        }
        return {
            ...androidAttach(name, serial, {
                process: launched.process, socket: launched.debuggerSocket, symbols: pathOf(launched.build.symbolsUri),
            }),
            stateuiRun: token,
        };
    }

    /**
     * A UIKit head, built and started on the device chosen by the stateui tool, which follows its output; a Debug
     * build started held and attached to by lldb-dap, the session's end stopping the run - a Release build has no
     * session.
     */
    private async uiKit(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const device = await this.choices.uiKitDevice();
        if (!device) {
            return undefined;
        }
        const debug = configuration === "debug";
        const running = await this.choices.runHead(root, application, "uikit", configuration, device, debug);
        if (!running || !debug) {
            return undefined;
        }
        const { launched, token } = running;
        if (launched.process === undefined) {
            void vscode.window.showErrorMessage(`StateUI: ${application.name} started, but its process is not known to attach to.`);
            return undefined;
        }
        const destination = launched.build.destination;
        return {
            ...uiKitAttach(name, {
                process: launched.process,
                device: destination?.kind === "device" ? destination.id : undefined,
                symbols: launched.build.bundleUri && pathOf(launched.build.bundleUri),
            }),
            stateuiRun: token,
        };
    }

    /**
     * A GTK head, built and installed by the stateui tool, a copy still running stopped - a GTK application being one
     * instance - and launched by lldb-dap.
     */
    private async gtk(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const program = await this.choices.build(root, application, "gtk", configuration);
        if (!program) {
            return undefined;
        }
        // A GTK application is one instance: a copy still running would only be brought forward.
        await new Promise((resolve) => execFile("pkill", ["-f", `^${program}( |$)`], () => resolve(undefined)));

        return {
            type: "lldb-dap",
            request: "launch",
            name,
            program,
            cwd: root.uri.fsPath,
            stopOnEntry: false,
        };
    }

    /**
     * A head built and started by the stateui tool in the guest chosen, which follows its output; where the tool says
     * no debugger reaches the guest, a Debug build runs without one, said - neither has a session.
     */
    private async inGuest(
        root: vscode.WorkspaceFolder,
        application: Application,
        host: Host,
        configuration: Configuration,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const guest = await this.choices.guest(host);
        if (!guest) {
            return undefined;
        }
        if (configuration === "debug" && !guest.debugger) {
            void vscode.window.showInformationMessage(
                `StateUI: no debugger reaches ${guest.name} - ${application.name}'s debug build runs there without one.`);
        }
        await this.choices.runHead(root, application, host, configuration, guest.name, false);
        return undefined;
    }

    /**
     * A Web head, built and served by the stateui tool, which opens the page in the browser chosen; a Debug launch in
     * a browser a debugger follows - one of Chromium's, as the tool says - has the page served alone and VS Code's
     * JavaScript debugger starting that browser on it, the session's end stopping the run.
     */
    private async web(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const browser = await this.choices.browser();
        if (!browser) {
            return undefined;
        }

        const debugged = configuration === "debug" && browser.debugger;
        const running = await this.choices.runHead(root, application, "web", configuration, debugged ? "none" : browser.id, false);
        if (!running || !debugged) {
            return undefined;
        }
        const { launched, token } = running;
        if (!launched.url) {
            void vscode.window.showErrorMessage(`StateUI: ${application.name}'s page is served, but its address is not known.`);
            return undefined;
        }
        return { ...webLaunch(name, launched.url, browser, pathOf(launched.build.folderUri)), stateuiRun: token };
    }
}

/** Where a run goes: an application's head on a device - its page, whichever browser opens it. */
export function runPlace(directory: string, host: Host, device: string): string {
    return JSON.stringify([directory, host, host === "web" ? "" : device]);
}

/**
 * VS Code's JavaScript debugger starting `browser`, one of Chromium's, on the page at `url`, in a profile of its own:
 * the page's console in the Debug Console, and the relay's sources read from `site`.
 */
export function webLaunch(name: string, url: string, browser: Browser, site: string): vscode.DebugConfiguration {
    return { type: "chrome", request: "launch", name, url, runtimeExecutable: browser.program, webRoot: site };
}

/** Where a run readied an Android head for a debugger: its process, the debugger server's socket, its symbols. */
export interface AndroidDebugger {
    /** The process started, the server's socket, and the libraries unstripped. */
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
 * Where a UIKit head waits for a debugger: its process, held until one
 * attaches, and on a device the device and the bundle built.
 */
export interface UIKitDebugger {
    process: number;
    device?: string;
    symbols?: string;
}

/**
 * lldb-dap attached to a UIKit head's process, which lets it run: on a
 * simulator a process of this Mac, found by its number; on a device through
 * the device, its symbols read from the bundle built rather than copied back.
 * The session's end kills the process through the debugger.
 */
export function uiKitAttach(name: string, facts: UIKitDebugger): vscode.DebugConfiguration {
    // The session's end ends the application by the debugger itself, which then lets go of it whole.
    const terminateCommands = ["process kill"];
    if (!facts.device) {
        return { type: "lldb-dap", request: "attach", name, pid: facts.process, stopOnEntry: false, terminateCommands };
    }
    return {
        type: "lldb-dap",
        request: "attach",
        name,
        stopOnEntry: false,
        terminateCommands,
        initCommands: facts.symbols
            ? [`settings append target.exec-search-paths ${facts.symbols}`,
                `settings append target.exec-search-paths ${facts.symbols}/Frameworks`]
            : [],
        attachCommands: [`device select ${facts.device}`, `device process attach --pid ${facts.process}`],
    };
}

