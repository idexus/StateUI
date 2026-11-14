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
// .build/android/debugger.json. A Release build cannot be debugged, and
// resolves to no session.
//
// A UIKit head is built and started by the stateui tool (`application/run`) on
// the iPhone, iPad or simulator chosen, its output followed in StateUI Run. A
// Debug launch starts it held until a debugger attaches; the run's `started`
// event says its process - on a simulator one of this Mac's, a device's
// reached through the device - and lldb-dap attaches, which lets it run. The
// debug session's end stops the run. A Release launch has no session.
//
// A GTK head is built by .scripts/GTK/run-app.sh --build-only, as a task, and
// launched by lldb-dap: the debugger is the application's parent, which is what
// Ubuntu's ptrace scope permits.
//
// A WinUI head is built by .scripts/WinUI/run-app.ps1 -BuildOnly, as a task -
// which stops a running copy first, its executable written again - and
// launched by lldb-dap, which reads the DWARF the head carries.
//
// A Web head is built, laid out and served by .scripts/Web/run-app.sh in a task
// whose terminal follows the server, and opened in the browser chosen. A Debug
// launch in one of Chromium's is VS Code's own JavaScript debugger starting it
// on the page, once the script writes where the page is to
// .build/web/server.json: the console in the Debug Console, a breakpoint in the
// relay. Any other browser the script opens itself, with no session.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead.

import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { Application, gtkProgram, pathOf, webSite, winUIProgram } from "./applications";
import { Browser, isChromium, webScript } from "./browsers";
import { lldbDapFinding } from "./toolchain";
import { androidScript } from "./devices";
import { environment, Host } from "./hosts";
import { LaunchedApplication } from "./Tooling/protocol";

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

    /**
     * Has the stateui tool build `application` for `host` in `configuration` and answers the program its build
     * published - nothing where it failed or was cancelled, which the tool's error said.
     */
    build(folder: vscode.WorkspaceFolder, application: Application, host: Host, configuration: Configuration): Promise<string | undefined>;

    /** Starts a task that runs until it is stopped - a head followed by its log. */
    start(task: vscode.Task): Promise<void>;

    /**
     * Waits, while `task` runs, for it to write `file`; whether it did before
     * it ended.
     */
    ready(file: string, task: vscode.Task): Promise<boolean>;

    /**
     * The serial of the Android device a launch runs on - the one chosen while
     * it is attached, else asked for, as `checkout`'s devices.sh lists them -
     * or nothing, where none is picked.
     */
    device(checkout: string): Promise<string | undefined>;

    /**
     * The iPhone, iPad or simulator a UIKit launch runs on - the one chosen
     * while it is listed, else asked for - or nothing, where none is picked.
     */
    uiKitDevice(): Promise<string | undefined>;

    /**
     * Has the stateui tool build `application` in `configuration` and start it on `device` - held for a debugger
     * where `debug` - following its output; once it started, what started and the token a debug session carries,
     * whose end stops the run - nothing where it failed or was cancelled, which the tool's error said.
     */
    uiKitRun(folder: vscode.WorkspaceFolder, application: Application, configuration: Configuration, device: string, debug: boolean):
        Promise<{ launched: LaunchedApplication; token: string } | undefined>;

    /**
     * The browser a Web launch opens the page in - the one chosen while it is installed, else asked for, as
     * `checkout`'s browsers.sh lists them - or nothing, where none is picked.
     */
    browser(checkout: string): Promise<Browser | undefined>;
}

/** What a machine that runs no host is told, wherever a host is asked for. */
export const noHost = "no StateUI host runs on this machine yet - AppKit, UIKit and Android are built and run on macOS, WinUI on Windows, GTK on Linux, Web on macOS and Linux.";

/** A script of the StateUI checkout's .scripts/WinUI, the checkout at `checkout`. */
export function winUIScript(checkout: string, name: string): string {
    return path.join(checkout, ".scripts", "WinUI", name);
}

/** A script of the StateUI checkout's .scripts/GTK, the checkout at `checkout`. */
export function gtkScript(checkout: string, name: string): string {
    return path.join(checkout, ".scripts", "GTK", name);
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

        // A page needs no lldb-dap: its debugger is the browser's.
        if (host === "web") {
            return this.web(root, application, configuration, name);
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

        if (host === "winui") {
            return this.winUI(root, application, configuration, name);
        }

        if (host === "gtk") {
            return this.gtk(root, application, configuration, name);
        }

        // AppKit: built by the stateui tool, lldb-dap launching the bundle's program it published.
        const program = await this.choices.build(root, application, "appkit", configuration);
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
        const checkout = application.checkout;
        const script = checkout && androidScript(checkout, "run-app.sh");
        if (!checkout || !script || !fs.existsSync(script)) {
            void vscode.window.showErrorMessage(
                `StateUI: an Android head runs through a StateUI checkout's .scripts/Android/run-app.sh, and ${application.name}'s Package.swift names none by path.`);
            return undefined;
        }

        const serial = await this.choices.device(checkout);
        if (!serial) {
            return undefined;
        }

        const debug = configuration === "debug";
        const facts = path.join(application.directory, ".build", "android", "debugger.json");
        fs.rmSync(facts, { force: true });
        const task = new vscode.Task(
            { type: "stateui", launch: true, application: application.name, configuration, device: serial }, root,
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
        const running = await this.choices.uiKitRun(root, application, configuration, device, debug);
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
     * A WinUI head, built by run-app.ps1 -BuildOnly in a task - which stops a running copy first, its executable
     * written again - and launched by lldb-dap.
     */
    private async winUI(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const script = application.checkout && winUIScript(application.checkout, "run-app.ps1");
        if (!script || !fs.existsSync(script)) {
            void vscode.window.showErrorMessage(
                `StateUI: a WinUI head is built by a StateUI checkout's .scripts/WinUI/run-app.ps1, and ${application.name}'s Package.swift names none by path.`);
            return undefined;
        }

        const task = new vscode.Task(
            { type: "stateui", application: application.name, configuration, device: "windows" }, root,
            `Build ${application.name} (WinUI, ${configuration})`, "StateUI",
            new vscode.ProcessExecution("powershell",
                ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
                    "-App", application.directory, "-Configuration", configuration, "-BuildOnly"],
                { cwd: root.uri.fsPath }), []);
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
        if ((await this.choices.run(task)) !== 0) {
            void vscode.window.showErrorMessage(
                `StateUI: the WinUI build of ${application.name} failed - its output is in the terminal.`);
            return undefined;
        }

        return {
            type: "lldb-dap",
            request: "launch",
            name,
            program: winUIProgram(application, configuration),
            cwd: root.uri.fsPath,
            stopOnEntry: false,
        };
    }
    /**
     * A GTK head, built by run-app.sh --build-only in a task - which stops a running copy first, a GTK application
     * being one instance - and launched by lldb-dap.
     */
    private async gtk(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const script = application.checkout && gtkScript(application.checkout, "run-app.sh");
        if (!script || !fs.existsSync(script)) {
            void vscode.window.showErrorMessage(
                `StateUI: a GTK head is built by a StateUI checkout's .scripts/GTK/run-app.sh, and ${application.name}'s Package.swift names none by path.`);
            return undefined;
        }

        const task = new vscode.Task(
            { type: "stateui", application: application.name, configuration }, root,
            `Build ${application.name} (GTK, ${configuration})`, "StateUI",
            new vscode.ShellExecution("bash", [script, application.directory, configuration, "--build-only"],
                { cwd: root.uri.fsPath }), []);
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
        if ((await this.choices.run(task)) !== 0) {
            void vscode.window.showErrorMessage(
                `StateUI: the GTK build of ${application.name} failed - its output is in the terminal.`);
            return undefined;
        }

        return {
            type: "lldb-dap",
            request: "launch",
            name,
            program: gtkProgram(application, configuration),
            cwd: root.uri.fsPath,
            stopOnEntry: false,
        };
    }

    /**
     * A Web head, built, laid out and served by run-app.sh in a task that follows the server; a Debug build in one
     * of Chromium's browsers started on the page by VS Code's JavaScript debugger, any other opened by the script.
     */
    private async web(
        root: vscode.WorkspaceFolder,
        application: Application,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const checkout = application.checkout;
        const script = checkout && webScript(checkout, "run-app.sh");
        if (!checkout || !script || !fs.existsSync(script)) {
            void vscode.window.showErrorMessage(
                `StateUI: a Web head runs through a StateUI checkout's .scripts/Web/run-app.sh, and ${application.name}'s Package.swift names none by path.`);
            return undefined;
        }

        const browser = await this.choices.browser(checkout);
        if (!browser) {
            return undefined;
        }

        const debugged = configuration === "debug" && isChromium(browser);
        const facts = path.join(application.directory, ".build", "web", "server.json");
        fs.rmSync(facts, { force: true });
        const task = new vscode.Task(
            { type: "stateui", launch: true, application: application.name, configuration, device: "web" }, root,
            `Run ${application.name} (Web, ${configuration})`, "StateUI",
            new vscode.ShellExecution("bash",
                [script, application.directory, configuration, "--browser", debugged ? "none" : browser.id],
                { cwd: root.uri.fsPath }), []);
        task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
        await this.choices.start(task);
        if (!debugged) {
            return undefined;
        }

        if (!(await this.choices.ready(facts, task))) {
            void vscode.window.showErrorMessage(`StateUI: ${application.name}'s page was not served - the terminal says why.`);
            return undefined;
        }
        return webLaunch(name, JSON.parse(fs.readFileSync(facts, "utf8")).url, browser, webSite(application, configuration));
    }
}

/**
 * VS Code's JavaScript debugger starting `browser`, one of Chromium's, on the page at `url`, in a profile of its own:
 * the page's console in the Debug Console, and the relay's sources read from `site`.
 */
export function webLaunch(name: string, url: string, browser: Browser, site: string): vscode.DebugConfiguration {
    return { type: "chrome", request: "launch", name, url, runtimeExecutable: browser.executable, webRoot: site };
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

