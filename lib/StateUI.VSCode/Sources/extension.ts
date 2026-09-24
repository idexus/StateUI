// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension: a host and an application chosen once - and for Android a
// device - the editor working as that host, one Debug and one Release that run
// the application on it, and the suites run as it.

import { execFile } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { Application, findApplications, hasHead } from "./applications";
import { configurations, StateUIDebugConfigurationProvider } from "./debug";
import { androidScript, askForDevice, chosenDevice, deviceToRunOn } from "./devices";
import { applyEditorMode, cleanIndex, variablesInSettings } from "./editorMode";
import { availableHosts, availableMauiDebuggers, describe, Host, MauiDebugger, mauiDebuggers } from "./hosts";
import { readyWhen, runTask, startTask } from "./tasks";
import { findSuites, forDevice, runSuites } from "./tests";
import { carriedTemplate, checkoutProblem, inAppsCommand, isCheckout, nameProblem, pinnedRelease, releases, Starter, StarterSource, writeStarter } from "./newApplication";

/** What the extension answers to another extension - and to its own tests. */
export interface StateUIApi {
    host(): Host;
    selectHost(host: Host): Promise<void>;
    application(): string | undefined;
    selectApplication(name: string): Promise<void>;
    selectDebugger(chosen: MauiDebugger): Promise<void>;
}

const hostKey = "stateui.host";
const applicationKey = "stateui.application";
const debuggerKey = "stateui.debugger";

/** What gives an application each host's head. */
const heads: Record<Host, string> = {
    appkit: "an AppKit head (Platforms/AppKit/main.swift)",
    maui: "a MAUI head (Platforms/Maui/*.csproj)",
    android: "an Android head (Platforms/Android/build.gradle.kts)",
};

export async function activate(context: vscode.ExtensionContext): Promise<StateUIApi> {
    const state = context.workspaceState;

    const applications = (): Application[] =>
        (vscode.workspace.workspaceFolders ?? []).flatMap((folder) => findApplications(folder.uri.fsPath));

    /** The applications that have a head for `host`. */
    const runnable = (host: Host): Application[] => applications().filter((each) => hasHead(each, host));

    // The packages whose manifest reads a host's variable: the applications.
    const roots = (): string[] => applications().map((each) => each.directory);

    // The one chosen, where this machine runs it; else AppKit where there is a
    // head to run on this machine, MAUI otherwise.
    const host = (): Host => {
        const stored = state.get<Host>(hostKey);
        if (availableHosts().some((each) => each.id === stored)) {
            return stored!;
        }
        return availableHosts().some((each) => each.id === "appkit") && applications().some((each) => each.hasAppKitHead) ? "appkit" : "maui";
    };

    /** How a MAUI head is debugged: the one chosen, where this machine offers it, else C#. */
    const mauiDebugger = (): MauiDebugger => {
        const stored = state.get<MauiDebugger>(debuggerKey);
        return availableMauiDebuggers().some((each) => each.id === stored) ? stored! : "csharp";
    };

    /** The chosen application, where it still has a head for the chosen host. */
    const chosen = (): Application | undefined =>
        runnable(host()).find((each) => each.name === state.get<string>(applicationKey));

    const hostItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    hostItem.command = "stateui.selectHost";
    const applicationItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 49);
    applicationItem.command = "stateui.selectApplication";
    const deviceItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 48);
    deviceItem.command = "stateui.selectAndroidDevice";
    context.subscriptions.push(hostItem, applicationItem, deviceItem);

    const refresh = (): void => {
        const described = describe(host());
        const debuggerLabel = mauiDebuggers.find((each) => each.id === mauiDebugger())?.label;
        hostItem.text = `$(server-environment) StateUI: ${described.label}${described.id === "maui" ? ` · ${debuggerLabel}` : ""}`;
        hostItem.tooltip = `StateUI: Debug, StateUI: Release, StateUI: Run Tests and the editor work as ${described.label} - ${described.detail}. Click to change.`;
        hostItem.show();

        const candidates = runnable(host());
        const application = chosen() ?? (candidates.length === 1 ? candidates[0] : undefined);
        applicationItem.text = `$(window) ${application?.name ?? "Select Application"}`;
        applicationItem.tooltip = `The application StateUI: Debug and StateUI: Release run on ${described.label}. Click to change.`;
        candidates.length > 0 ? applicationItem.show() : applicationItem.hide();

        const device = chosenDevice(state);
        deviceItem.text = `$(device-mobile) ${device?.name ?? "Select Android Device"}`;
        deviceItem.tooltip = `The Android device StateUI: Debug, StateUI: Release and StateUI: Run Tests run on${device ? ` - ${device.serial}` : ""}. Click to change.`;
        described.id === "android" ? deviceItem.show() : deviceItem.hide();
    };

    const selectHost = async (picked: Host): Promise<void> => {
        await state.update(hostKey, picked);
        refresh();

        if (await applyEditorMode(picked, roots())) {
            void vscode.window.setStatusBarMessage(`StateUI: the editor works as ${describe(picked).label}`, 4000);
        }
    };

    const selectDebugger = async (picked: MauiDebugger): Promise<void> => {
        await state.update(debuggerKey, picked);
        refresh();
    };

    const selectApplication = async (name: string): Promise<void> => {
        await state.update(applicationKey, name);
        refresh();
    };

    /** Asks for an application with a head for `forHost`, the chosen one offered first. */
    const askForApplication = async (forHost: Host): Promise<Application | undefined> => {
        const candidates = runnable(forHost);
        if (candidates.length === 0) {
            void vscode.window.showErrorMessage(`StateUI: no application here has ${heads[forHost]}.`);
            return undefined;
        }

        const current = state.get<string>(applicationKey);
        const ordered = [...candidates].sort((a, b) => Number(b.name === current) - Number(a.name === current));
        const picked = await vscode.window.showQuickPick(
            ordered.map((each) => ({
                label: each.name,
                description: each.name === current ? "current" : undefined,
                detail: vscode.workspace.asRelativePath(each.directory),
                application: each,
            })),
            { placeHolder: `Which application do StateUI: Debug and StateUI: Release run on ${describe(forHost).label}?`, ignoreFocusOut: true });

        if (picked) {
            await selectApplication(picked.application.name);
        }
        return picked?.application;
    };

    /** The Android device a launch or a suite runs on - asked for where none chosen is attached. */
    const androidDevice = async (root: string): Promise<string | undefined> => {
        const serial = await deviceToRunOn(root, state);
        refresh();
        return serial;
    };

    context.subscriptions.push(
        vscode.commands.registerCommand("stateui.selectHost", async () => {
            const picked = await vscode.window.showQuickPick(
                // Android is offered where an application has its head.
                availableHosts().filter((each) => each.id !== "android" || runnable("android").length > 0).map((each) => ({
                    label: each.label,
                    description: each.id === host() ? "current" : undefined,
                    detail: each.detail,
                    id: each.id,
                })),
                { placeHolder: "Which host do StateUI: Debug, StateUI: Run Tests and the editor work as?" });
            if (picked) {
                await selectHost(picked.id);
            }
        }),
        vscode.commands.registerCommand("stateui.selectApplication", () => askForApplication(host())),
        vscode.commands.registerCommand("stateui.selectAndroidDevice", async () => {
            const root = (vscode.workspace.workspaceFolders ?? []).map((folder) => folder.uri.fsPath)
                .find((directory) => fs.existsSync(androidScript(directory, "devices.sh")));
            if (!root) {
                void vscode.window.showErrorMessage("StateUI: Android devices are listed by a StateUI checkout's .scripts/Android/devices.sh, which no folder here has.");
                return;
            }
            await askForDevice(root, state);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectDebugger", async () => {
            const picked = await vscode.window.showQuickPick(
                availableMauiDebuggers().map((each) => ({
                    label: each.label,
                    description: each.id === mauiDebugger() ? "current" : undefined,
                    detail: each.detail,
                    id: each.id,
                })),
                { placeHolder: "How does StateUI: Debug debug a .NET MAUI head?" });
            if (picked) {
                await selectDebugger(picked.id);
            }
        }),
        vscode.commands.registerCommand("stateui.runTests", async () => {
            const folder = vscode.workspace.workspaceFolders?.[0];
            const suites = folder ? findSuites(folder.uri.fsPath, host()) : [];
            if (!folder || suites.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: no test suite here runs on ${describe(host()).label}.`);
                return;
            }

            const picked = await vscode.window.showQuickPick(
                suites.map((suite) => ({ label: suite.label, detail: suite.detail, picked: true, suite })),
                { canPickMany: true, placeHolder: `The suites to run as ${describe(host()).label}` });
            if (!picked || picked.length === 0) {
                return;
            }

            let chosenSuites = picked.map((each) => each.suite);
            if (chosenSuites.some((each) => each.onDevice)) {
                const serial = await androidDevice(folder.uri.fsPath);
                if (!serial) {
                    return;
                }
                chosenSuites = chosenSuites.map((each) => forDevice(each, serial));
            }

            const failed = await runSuites(folder, chosenSuites);
            if (failed.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: all ${picked.length} suites passed on ${describe(host()).label}.`);
            } else {
                void vscode.window.showErrorMessage(
                    `StateUI: ${failed.length} of ${picked.length} suites failed on ${describe(host()).label}: ${failed.join(", ")}. Their output is in the terminal.`);
            }
        }),
        vscode.commands.registerCommand("stateui.newApplicationInApps", async () => {
            const checkouts = (vscode.workspace.workspaceFolders ?? []).filter((folder) => isCheckout(folder.uri.fsPath));
            const folder = checkouts.length > 1
                ? (await vscode.window.showWorkspaceFolderPick({ placeHolder: "Which checkout's apps/ is the application made in?" }))
                : checkouts[0];
            if (!folder || !isCheckout(folder.uri.fsPath)) {
                void vscode.window.showErrorMessage("StateUI: this workspace is not a StateUI checkout, so it has no apps/ to make an application in.");
                return;
            }

            const apps = path.join(folder.uri.fsPath, "apps");
            const name = await vscode.window.showInputBox({
                title: "New Application in apps/",
                prompt: "The application's name: its directory, MAUI project, process and Swift module (<Name>UI).",
                placeHolder: "MyApp",
                ignoreFocusOut: true,
                validateInput: (value) => nameProblem(value) ?? (fs.existsSync(path.join(apps, value)) ? `apps/${value} already exists.` : undefined),
            });
            if (!name) {
                return;
            }

            const { command, args } = inAppsCommand(folder.uri.fsPath, name);
            const task = new vscode.Task({ type: "stateui", application: name }, folder, `New application ${name}`, "StateUI",
                new vscode.ShellExecution(command, args, { cwd: folder.uri.fsPath }), []);
            task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
            if ((await runTask(task)) !== 0) {
                void vscode.window.showErrorMessage(`StateUI: ${name} was not made - the terminal says why.`);
                return;
            }

            // Runnable at once: chosen, and indexed as the host the editor works as.
            await selectApplication(name);
            await applyEditorMode(host(), roots());
            void vscode.window.showInformationMessage(`StateUI: apps/${name} is made and chosen - StateUI: Debug runs it.`);
        }),
        vscode.commands.registerCommand("stateui.newApplication", () => newApplication(context.extensionPath)),
        vscode.commands.registerCommand("stateui.cleanIndex", async () => {
            await cleanIndex(roots());
            void vscode.window.setStatusBarMessage("StateUI: the index is being built again", 4000);
        }));

    // The C# sessions that lldb-dap attaches beside once they have started the
    // application: session name -> process name.
    const pendingSwift = new Map<string, string>();

    context.subscriptions.push(vscode.debug.onDidStartDebugSession(async (session) => {
        const processName = session.type === "maui" ? pendingSwift.get(session.name) : undefined;
        if (processName === undefined) {
            return;
        }
        pendingSwift.delete(session.name);

        // The C# session builds before it starts anything, so the process is
        // waited for rather than timed - found by its EXACT name, never by a
        // command line a build also carries.
        const status = vscode.window.setStatusBarMessage(`$(sync~spin) StateUI: waiting for ${processName} to attach Swift`);
        const deadline = Date.now() + 600_000;
        let running = false;
        while (!running && Date.now() < deadline && vscode.debug.activeDebugSession !== undefined) {
            running = await new Promise<boolean>((resolve) => execFile("pgrep", ["-x", processName], (error) => resolve(error === null)));
            if (!running) {
                await new Promise((resume) => setTimeout(resume, 1000));
            }
        }
        status.dispose();

        if (!running) {
            void vscode.window.showErrorMessage(`StateUI: ${processName} never started, so Swift was not attached.`);
            return;
        }

        await vscode.debug.startDebugging(session.workspaceFolder, {
            type: "lldb-dap", request: "attach", name: `${session.name} (Swift)`, stopOnEntry: false,
            attachCommands: [`process attach --name ${processName}`],
        }, { parentSession: session, lifecycleManagedByParent: true });
    }));

    const provider = new StateUIDebugConfigurationProvider({
        host,
        debugger: mauiDebugger,
        run: runTask,
        start: startTask,
        ready: (file, task) => readyWhen(file, task),
        device: (folder) => androidDevice(folder.uri.fsPath),
        attachSwiftWhenStarted: (sessionName, processName) => { pendingSwift.set(sessionName, processName); },
        application: async (_folder, forHost, named) => {
            const candidates = runnable(forHost);

            if (named !== undefined) {
                const found = candidates.find((each) => each.name === named);
                if (!found) {
                    void vscode.window.showErrorMessage(`StateUI: no application named ${named} runs on ${describe(forHost).label}.`);
                }
                return found;
            }

            // The chosen one - asked for only when there is none, or when the
            // one chosen has no head for this host.
            const remembered = candidates.find((each) => each.name === state.get<string>(applicationKey));
            if (remembered) {
                return remembered;
            }
            if (candidates.length === 1) {
                await selectApplication(candidates[0].name);
                return candidates[0];
            }
            return askForApplication(forHost);
        },
    });
    context.subscriptions.push(
        vscode.debug.registerDebugConfigurationProvider("stateui", provider),
        vscode.debug.registerDebugConfigurationProvider("stateui", { provideDebugConfigurations: configurations },
            vscode.DebugConfigurationProviderTriggerKind.Dynamic));

    // A settings file that sets a host variable decides the editor's mode over
    // anything chosen here, so it is said once, with the way out.
    const settled = variablesInSettings();
    if (settled.length > 0) {
        void vscode.window.showWarningMessage(
            `StateUI: swift.swiftEnvironmentVariables sets ${settled.join(", ")}, which decides the editor's host whatever is chosen in the status bar.`,
            "Remove it").then(async (answer) => {
                if (answer) {
                    const configuration = vscode.workspace.getConfiguration("swift");
                    const inspected = configuration.inspect<Record<string, string>>("swiftEnvironmentVariables");
                    const kept = Object.fromEntries(Object.entries(inspected?.workspaceValue ?? {}).filter(([key]) => !settled.includes(key)));
                    await configuration.update("swiftEnvironmentVariables",
                        Object.keys(kept).length > 0 ? kept : undefined, vscode.ConfigurationTarget.Workspace);
                }
            });
    }

    const updateCheckoutContext = (): void => {
        void vscode.commands.executeCommand("setContext", "stateui.hasCheckout",
            (vscode.workspace.workspaceFolders ?? []).some((folder) => isCheckout(folder.uri.fsPath)));
    };
    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(updateCheckoutContext));
    updateCheckoutContext();

    refresh();
    await applyEditorMode(host(), roots());

    return { host, selectHost, application: () => state.get<string>(applicationKey), selectApplication, selectDebugger };
}

/**
 * StateUI: New Application from Template - where, what it is called, and
 * what StateUI it is built against; then the application is written and
 * offered to open.
 */
async function newApplication(extensionPath: string): Promise<void> {
    const title = "New Application from Template";
    const workspace = vscode.workspace.workspaceFolders?.[0]?.uri;

    const parent = (await vscode.window.showOpenDialog({
        title: `${title}: the directory the application's own directory is made in`,
        canSelectFiles: false, canSelectFolders: true, canSelectMany: false, openLabel: "Create Here",
        defaultUri: workspace ? vscode.Uri.file(path.dirname(workspace.fsPath)) : undefined,
    }))?.[0]?.fsPath;
    if (!parent) {
        return;
    }

    const name = await vscode.window.showInputBox({
        title,
        prompt: `The application's name: its directory in ${parent}, MAUI project, process and Swift module (<Name>UI).`,
        placeHolder: "MyApp",
        ignoreFocusOut: true,
        validateInput: (value) => nameProblem(value) ?? (fs.existsSync(path.join(parent, value)) ? `${path.join(parent, value)} already exists.` : undefined),
    });
    if (!name) {
        return;
    }

    const carried = carriedTemplate(extensionPath);
    const workspaceCheckouts = (vscode.workspace.workspaceFolders ?? [])
        .map((folder) => folder.uri.fsPath)
        .filter((directory) => checkoutProblem(directory) === undefined);
    type Choice = { label: string; description?: string; detail?: string; source: "checkout" | "another" | "release"; checkout?: string };
    const choice = await vscode.window.showQuickPick<Choice>([
        ...workspaceCheckouts.map((checkout): Choice => ({
            label: "$(repo) This StateUI checkout", detail: `${checkout} - both halves by path, as they are on disk`, source: "checkout", checkout,
        })),
        { label: "$(folder-opened) A StateUI checkout…", detail: "Both halves from a checkout on disk, by path", source: "another" },
        { label: "$(package) A release", detail: "StateUI.Maui from NuGet, and the Swift half by the repository's tag of the same version", source: "release" },
    ], { title, placeHolder: `What StateUI is ${name} built against?`, ignoreFocusOut: true });
    if (!choice) {
        return;
    }

    let source: StarterSource;
    let templateRoot: string;
    if (choice.source === "release") {
        let found: string[];
        try {
            found = await vscode.window.withProgress(
                { location: vscode.ProgressLocation.Notification, title: "StateUI: reading NuGet's versions and the repository's tags" },
                () => releases());
        } catch (error) {
            void vscode.window.showErrorMessage(`StateUI: the releases could not be read - ${error instanceof Error ? error.message : String(error)}`);
            return;
        }
        if (found.length === 0) {
            void vscode.window.showErrorMessage("StateUI: no release has both StateUI.Maui on NuGet and its tag in the repository yet. Build against a checkout instead.");
            return;
        }

        const written = pinnedRelease(carried);
        const version = await vscode.window.showQuickPick(
            found.map((each) => ({
                label: each,
                description: each === written ? "the release this template is written for" : undefined,
            })),
            { title, placeHolder: "Which release?", ignoreFocusOut: true });
        if (!version) {
            return;
        }
        source = { kind: "release", version: version.label };
        templateRoot = carried;
    } else {
        let checkout = choice.checkout;
        if (choice.source === "another") {
            checkout = (await vscode.window.showOpenDialog({
                title: `${title}: the StateUI checkout`, canSelectFiles: false, canSelectFolders: true, canSelectMany: false, openLabel: "Build Against It",
            }))?.[0]?.fsPath;
        }
        if (!checkout) {
            return;
        }
        const problem = checkoutProblem(checkout);
        if (problem) {
            void vscode.window.showErrorMessage(`StateUI: ${problem}`);
            return;
        }
        source = { kind: "checkout", checkout };
        // The checkout's own template, so the application matches the library it is built against.
        templateRoot = checkout;
    }

    // The AppKit host is a package of the checkout's, so only a checkout offers it.
    let appKit = false;
    if (source.kind === "checkout" && process.platform === "darwin") {
        const heads = await vscode.window.showQuickPick(
            [{ label: "MAUI and AppKit", detail: "A .NET MAUI head, and a native macOS head in Platforms/AppKit", appKit: true },
             { label: "MAUI", detail: "A .NET MAUI head for Android, iOS, Mac Catalyst, Windows and Linux", appKit: false }],
            { title, placeHolder: `Which heads does ${name} have?`, ignoreFocusOut: true });
        if (!heads) {
            return;
        }
        appKit = heads.appKit;
    }

    const starter: Starter = { name, parent, source, appKit };
    let made: string;
    try {
        made = writeStarter(starter, templateRoot);
    } catch (error) {
        void vscode.window.showErrorMessage(`StateUI: ${name} was not made - ${error instanceof Error ? error.message : String(error)}`);
        return;
    }

    const open = await vscode.window.showInformationMessage(`StateUI: ${made} is made.`, "Open", "Open in New Window");
    if (open) {
        await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(made), { forceNewWindow: open === "Open in New Window" });
    }
}

export function deactivate(): void {}
