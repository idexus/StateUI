// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// ONE Debug and ONE Release, whatever the host.
//
// A `stateui` configuration is never debugged itself: it is resolved into the
// configuration a debugger takes - lldb-dap for Swift, VS Code's JavaScript
// debugger for a page. Resolved in the FIRST hook, so the new type's resolvers
// still run over it. On a machine that runs no host, nothing is resolved and
// the launch says so.
//
// The stateui tool readies every launch and says how a debugger reaches the
// application (`DebugDescriptor`); the editor only maps that to its debugger's
// configuration. Where a host's heads run, the tool says too (`server/info`):
//
// - on this machine itself (AppKit, WinUI, GTK): `application/prepare` builds
//   the head and readies it - a GTK head installed, a copy running stopped -
//   and lldb-dap starts its program, Debug and Release alike;
// - on a device (UIKit, Android): `application/run` builds, installs and
//   starts it on the one chosen, StateUI Run following its output; a Debug
//   launch has it readied for a debugger - held, or its lldb-server started -
//   and lldb-dap attaches as the `started` event says, the session's end
//   stopping the run. A Release launch has no session;
// - in a browser (the Web): the page served and opened in the browser chosen;
//   a Debug launch in one a debugger follows has it served alone, and VS
//   Code's JavaScript debugger starts that browser on it;
// - on another machine - a guest of a Mac for GTK and WinUI, a machine paired
//   with the project for a host it runs: built and started there by the tool;
//   a Debug launch on one paired is held there for LLDB, which lldb-dap reaches
//   through the tool's relay as the `started` event says, the session's end
//   stopping the run; where no debugger reaches it - a guest not paired - the
//   debug build runs without one, said. A Release launch has no session.
//
// The application is the one chosen with StateUI: Select Application; a launch
// naming its `application` runs that one instead.

import * as vscode from "vscode";
import { Application, pathOf } from "./applications";
import { Browser } from "./browsers";
import { Machine } from "./machines";
import { lldbDapFinding } from "./toolchain";
import { Host } from "./hosts";
import { DebugDescriptor, LaunchedApplication, Place, PreparedApplication } from "./Tooling/protocol";

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
     * Has the stateui tool build `application` for `host` in `configuration` and ready it for a debugger to start on
     * this machine - its build and how the debugger starts it - nothing where it failed or was cancelled, which the
     * tool's error said.
     */
    prepare(
        folder: vscode.WorkspaceFolder, application: Application, host: Host, configuration: Configuration,
    ): Promise<PreparedApplication | undefined>;

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
     * The machine a launch of `host` is built and run on, where this machine works it on another - a guest, a machine
     * paired: the one chosen while it is listed, else asked for - or nothing, where none is picked.
     */
    machine(host: Host): Promise<Machine | undefined>;

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

        // A page's debugger is the browser's; another machine's is the tool's to give.
        const place = this.choices.place(host);
        if (place === "browser") {
            return this.inBrowser(root, application, host, configuration, name);
        }
        if (place === "guest" || place === "remote") {
            return this.onMachine(root, application, host, configuration, name);
        }

        // A debugger that cannot start stops the launch before the build, saying why: else the build ends and nothing runs.
        const debuggerStarts = await lldbDapFinding(vscode.workspace.getConfiguration("lldb-dap").get<string>("executable-path"));
        if (debuggerStarts && debuggerStarts.found === undefined) {
            void vscode.window.showErrorMessage(`StateUI: the debugger does not start - ${debuggerStarts.advice}`);
            return undefined;
        }

        if (place === "device") {
            return this.onDevice(root, application, host, configuration, name);
        }
        const prepared = await this.choices.prepare(root, application, host, configuration);
        return prepared && debugConfiguration(name, prepared.debugger);
    }

    /**
     * A head built and started by the stateui tool on the device chosen, which follows its output; a Debug build
     * readied for a debugger, which lldb-dap reaches as the tool says, the session's end stopping the run - a Release
     * build has no session.
     */
    private async onDevice(
        root: vscode.WorkspaceFolder,
        application: Application,
        host: Host,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const device = host === "uikit" ? await this.choices.uiKitDevice() : await this.choices.device();
        if (!device) {
            return undefined;
        }
        const debug = configuration === "debug";
        const running = await this.choices.runHead(root, application, host, configuration, device, debug);
        if (!running || !debug) {
            return undefined;
        }
        const { launched, token } = running;
        if (!launched.debugger) {
            void vscode.window.showErrorMessage(`StateUI: ${application.name} started, but the tool said no way for a debugger to reach it.`);
            return undefined;
        }
        return { ...debugConfiguration(name, launched.debugger), stateuiRun: token };
    }

    /**
     * A head built and started by the stateui tool on the machine chosen, which follows its output; a Debug build on a
     * machine a debugger reaches is held for LLDB, which lldb-dap reaches as the tool says, the session's end stopping
     * the run - elsewhere it runs without one, said. A Release build has no session.
     */
    private async onMachine(
        root: vscode.WorkspaceFolder,
        application: Application,
        host: Host,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const machine = await this.choices.machine(host);
        if (!machine) {
            return undefined;
        }
        const debug = configuration === "debug" && machine.debugger;
        if (configuration === "debug" && !machine.debugger) {
            void vscode.window.showInformationMessage(
                `StateUI: no debugger reaches ${machine.name} - pair it (\`stateui guest pair\`); ${application.name}'s debug build runs there without one.`);
        }
        const running = await this.choices.runHead(root, application, host, configuration, machine.name, debug);
        if (!running || !debug || !running.launched.debugger) {
            return undefined;
        }
        return { ...debugConfiguration(name, running.launched.debugger), stateuiRun: running.token };
    }

    /**
     * A page, built and served by the stateui tool, which opens it in the browser chosen; a Debug launch in a browser
     * a debugger follows has it served alone, and VS Code's JavaScript debugger starts that browser on it as the tool
     * says, the session's end stopping the run.
     */
    private async inBrowser(
        root: vscode.WorkspaceFolder,
        application: Application,
        host: Host,
        configuration: Configuration,
        name: string,
    ): Promise<vscode.DebugConfiguration | undefined> {
        const browser = await this.choices.browser();
        if (!browser) {
            return undefined;
        }
        const debug = configuration === "debug" && browser.debugger;
        const running = await this.choices.runHead(root, application, host, configuration, browser.id, debug);
        if (!running || !running.launched.debugger) {
            return undefined;
        }
        return { ...debugConfiguration(name, running.launched.debugger), stateuiRun: running.token };
    }
}

/** Where a run goes: an application's head on a device - its page, whichever browser opens it. */
export function runPlace(directory: string, host: Host, device: string): string {
    return JSON.stringify([directory, host, host === "web" ? "" : device]);
}

/**
 * The configuration of VS Code's debugger that reaches an application as the stateui tool said: lldb-dap starting
 * its program or attaching to its process with the tool's commands, or VS Code's JavaScript debugger starting a
 * browser on its page.
 */
export function debugConfiguration(name: string, way: DebugDescriptor): vscode.DebugConfiguration {
    if (way.kind === "browser") {
        return {
            type: "chrome", request: "launch", name, url: way.url,
            runtimeExecutable: way.programUri && pathOf(way.programUri), webRoot: way.sourceUri && pathOf(way.sourceUri),
        };
    }
    const commands = {
        ...(way.initCommands.length > 0 ? { initCommands: way.initCommands } : {}),
        ...(way.terminateCommands.length > 0 ? { terminateCommands: way.terminateCommands } : {}),
    };
    if (way.request === "launch") {
        return {
            type: "lldb-dap", request: "launch", name, program: way.programUri && pathOf(way.programUri),
            cwd: way.workingUri && pathOf(way.workingUri), stopOnEntry: false, ...commands,
        };
    }
    return {
        type: "lldb-dap", request: "attach", name, stopOnEntry: false, ...commands,
        ...(way.attachCommands.length > 0 ? { attachCommands: way.attachCommands } : { pid: way.process }),
    };
}
