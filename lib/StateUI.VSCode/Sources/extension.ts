// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension: a host and an application chosen once - and for Android a
// device, for UIKit an iPhone, an iPad or a simulator, for the Web a browser - the editor working as that host, one Debug and
// one Release that run the application on it, and the suites run as it.

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as vscode from "vscode";
import { Application, findApplications, hasHead, keepsApps } from "./applications";
import { isCheckout } from "./checkouts";
import { configurations, noHost, StateUIDebugConfigurationProvider } from "./debug";
import { androidScript, askForDevice, chosenDevice, deviceToRunOn } from "./devices";
import { askForBrowser, Browser, browserToRunOn, chosenBrowser, webScript } from "./browsers";
import { applyEditorMode, cleanIndex, setHostEnvironment, variablesInSettings } from "./editorMode";
import { availableHosts, describe, Host } from "./hosts";
import { askForUIKitDevice, chooseListedUIKitDevice, chosenUIKitDevice, uiKitDeviceToRunOn } from "./uiKitDevices";
import { readyWhen, runTask, startTask } from "./tasks";
import { findSuites, forDevice, runSuites } from "./tests";
import { checkoutOf, makeApplication, nameProblem } from "./newApplication";
import { cloneRelease, groupNameProblem, listReleases, makeProjectGroup, releaseDirectory } from "./projectGroup";
import { editorCommandLine, hasExtensionSources, reinstallSteps } from "./reinstall";
import { Rebuild, rebuildSteps } from "./conformance";
import { checkToolchain, debuggerFinding, lldbDapFinding, report } from "./toolchain";
import { Architecture, deployCommand, deployDestination, winUIArchitectures } from "./deploy";

/** What the extension answers to another extension - and to its own tests. */
export interface StateUIApi {
    host(): Host | undefined;
    selectHost(host: Host): Promise<void>;
    application(): string | undefined;
    selectApplication(name: string): Promise<void>;
    /** Chooses the iPhone, iPad or simulator listed by `wanted` - its id or its name - and answers its name. */
    selectUIKitDevice(wanted: string): Promise<string | undefined>;
}

const hostKey = "stateui.host";
const applicationKey = "stateui.application";

/** What gives an application each host's head. */
const heads: Record<Host, string> = {
    appkit: "an AppKit head (Platforms/AppKit/main.swift)",
    uikit: "a UIKit head (Platforms/UIKit/main.swift)",
    android: "an Android head (Platforms/Android/build.gradle.kts)",
    winui: "a WinUI head (Platforms/WinUI/main.swift)",
    gtk: "a GTK head (Platforms/GTK/main.swift)",
    web: "a Web head (Platforms/Web/main.swift)",
};

export async function activate(context: vscode.ExtensionContext): Promise<StateUIApi> {
    const state = context.workspaceState;

    const applications = (): Application[] =>
        (vscode.workspace.workspaceFolders ?? []).flatMap((folder) => findApplications(folder.uri.fsPath));

    /** The applications that have a head for `host`. */
    const runnable = (host: Host): Application[] => applications().filter((each) => hasHead(each, host));

    // The packages whose manifest reads a host's variable: the applications.
    const roots = (): string[] => applications().map((each) => each.directory);

    // The one chosen, where this machine runs it; else the first this machine
    // runs that an application here has a head for; none where it runs none.
    const host = (): Host | undefined => {
        const available = availableHosts();
        const stored = state.get<Host>(hostKey);
        if (available.some((each) => each.id === stored)) {
            return stored;
        }
        return (available.find((each) => runnable(each.id).length > 0) ?? available[0])?.id;
    };
    setHostEnvironment(host());

    /** What the suites and the editor run as: the host chosen, or plain Swift. */
    const runningAs = (): string => {
        const chosenHost = host();
        return chosenHost ? describe(chosenHost).label : "plain Swift";
    };

    /** The chosen application, where it still has a head for the chosen host. */
    const chosen = (): Application | undefined => {
        const chosenHost = host();
        return chosenHost ? runnable(chosenHost).find((each) => each.name === state.get<string>(applicationKey)) : undefined;
    };

    const hostItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    hostItem.command = "stateui.selectHost";
    const applicationItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 49);
    applicationItem.command = "stateui.selectApplication";
    const deviceItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 48);
    deviceItem.command = "stateui.selectAndroidDevice";
    context.subscriptions.push(hostItem, applicationItem, deviceItem);

    // What StateUI: Check Toolchain found, component by component.
    const toolchain = vscode.window.createOutputChannel("StateUI Toolchain");
    context.subscriptions.push(toolchain);

    // What the scaffolder and git said while making an application or a project group.
    const scaffolder = vscode.window.createOutputChannel("StateUI Scaffolder");
    context.subscriptions.push(scaffolder);

    /** The repository a release is cloned from: the one the extension's manifest names. */
    const repository: string = context.extension.packageJSON.repository.url;

    /**
     * The local StateUI checkout: a folder open here that is one, else the one
     * `stateui.checkout` names, else asked for.
     */
    const localCheckout = async (): Promise<string | undefined> => {
        const open = (vscode.workspace.workspaceFolders ?? []).map((each) => each.uri.fsPath).find(isCheckout);
        if (open) {
            return open;
        }
        const configured = vscode.workspace.getConfiguration("stateui").get<string>("checkout", "").trim()
            .replace(/^~(?=$|[\\/])/, os.homedir());
        if (configured && isCheckout(configured)) {
            return configured;
        }
        if (configured) {
            void vscode.window.showWarningMessage(`StateUI: stateui.checkout names ${configured}, which is not a StateUI checkout.`);
        }
        const picked = (await vscode.window.showOpenDialog({
            canSelectFolders: true, canSelectFiles: false, canSelectMany: false,
            title: "Where is the StateUI checkout? (stateui.checkout in Settings saves this question)", openLabel: "Use This Checkout",
        }))?.[0]?.fsPath;
        if (picked && !isCheckout(picked)) {
            void vscode.window.showErrorMessage(`StateUI: ${picked} is not a StateUI checkout - it has no .scripts/new-app.sh and apps/HelloWorld.`);
            return undefined;
        }
        return picked;
    };

    /** Asks for the name of an application made in `apps`. */
    const askApplicationName = (apps: string, title: string): Thenable<string | undefined> => vscode.window.showInputBox({
        title,
        prompt: "The application's name: its directory, process and Swift module (<Name>UI).",
        placeHolder: "MyApp",
        ignoreFocusOut: true,
        validateInput: (value) => nameProblem(value) ?? (fs.existsSync(path.join(apps, value)) ? `apps/${value} already exists.` : undefined),
    });

    /** What went wrong, said with the scaffolder's output, which says why. */
    const reportFailure = (message: string): void => {
        scaffolder.show(true);
        void vscode.window.showErrorMessage(`StateUI: ${message} - the StateUI Scaffolder output says why.`);
    };

    const refresh = (): void => {
        const chosenHost = host();
        if (!chosenHost) {
            hostItem.text = "$(server-environment) StateUI: no host";
            hostItem.tooltip = `StateUI: ${noHost} StateUI: Run Tests and the editor work as plain Swift.`;
            hostItem.show();
            applicationItem.hide();
            deviceItem.hide();
            return;
        }

        const described = describe(chosenHost);
        hostItem.text = `$(server-environment) StateUI: ${described.label}`;
        hostItem.tooltip = `StateUI: Debug, StateUI: Release, StateUI: Run Tests and the editor work as ${described.label} - ${described.detail}. Click to change.`;
        hostItem.show();

        const candidates = runnable(chosenHost);
        const application = chosen() ?? (candidates.length === 1 ? candidates[0] : undefined);
        applicationItem.text = `$(window) ${application?.name ?? "Select Application"}`;
        applicationItem.tooltip = `The application StateUI: Debug and StateUI: Release run on ${described.label}. Click to change.`;
        candidates.length > 0 ? applicationItem.show() : applicationItem.hide();

        if (described.id === "web") {
            const browser = chosenBrowser(state);
            deviceItem.command = "stateui.selectBrowser";
            deviceItem.text = `$(globe) ${browser?.name ?? "Select Browser"}`;
            deviceItem.tooltip = "The browser StateUI: Debug and StateUI: Release open the application in - one of Chromium's under VS Code's debugger. Click to change.";
        } else if (described.id === "uikit") {
            const device = chosenUIKitDevice(state);
            deviceItem.command = "stateui.selectUIKitDevice";
            deviceItem.text = `$(device-mobile) ${device?.name ?? "Select UIKit Device"}`;
            deviceItem.tooltip = `The iPhone, iPad or simulator StateUI: Debug, StateUI: Release and StateUI: Run Tests run on${device ? ` - ${device.id}` : ""}. Click to change.`;
        } else {
            const device = chosenDevice(state);
            deviceItem.command = "stateui.selectAndroidDevice";
            deviceItem.text = `$(device-mobile) ${device?.name ?? "Select Android Device"}`;
            deviceItem.tooltip = `The Android device StateUI: Debug, StateUI: Release and StateUI: Run Tests run on${device ? ` - ${device.serial}` : ""}. Click to change.`;
        }
        ["android", "uikit", "web"].includes(described.id) ? deviceItem.show() : deviceItem.hide();
    };

    const selectHost = async (picked: Host): Promise<void> => {
        await state.update(hostKey, picked);
        refresh();

        if (await applyEditorMode(picked, roots())) {
            void vscode.window.setStatusBarMessage(`StateUI: the editor works as ${describe(picked).label}`, 4000);
        }
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

    /** The iPhone, iPad or simulator a UIKit launch or suite runs on - asked for where none chosen is listed. */
    const uiKitDevice = async (): Promise<string | undefined> => {
        const id = await uiKitDeviceToRunOn(state);
        refresh();
        return id;
    };

    /** The browser a Web launch opens the page in - asked for where none chosen is installed. */
    const browser = async (checkout: string): Promise<Browser | undefined> => {
        const found = await browserToRunOn(checkout, state);
        refresh();
        return found;
    };

    /** The chosen host's marks made again in the checkout - `rebuild` says which families - and the documents rendered. */
    const rebuildConformance = async (rebuild: Rebuild): Promise<void> => {
        const folder = (vscode.workspace.workspaceFolders ?? []).find((each) => isCheckout(each.uri.fsPath));
        const chosen = host();
        if (!folder || !chosen) {
            void vscode.window.showErrorMessage(`StateUI: the marks are made in a StateUI checkout, as the host chosen - ${folder ? noHost : "no folder here is one"}.`);
            return;
        }
        if (chosen === "web") {
            void vscode.window.showInformationMessage("StateUI: the Web host has no conformance driver yet, so it makes no marks.");
            return;
        }
        if (chosen === "android" && rebuild === "changed") {
            void vscode.window.showInformationMessage("StateUI: Android's device reads no repository, so its marks are made again whole - Conformance - Rebuild all.");
            return;
        }
        const device = chosen === "uikit" ? await uiKitDevice() : chosen === "android" ? await androidDevice(folder.uri.fsPath) : undefined;
        const steps = rebuildSteps(folder.uri.fsPath, chosen, rebuild, device);
        if (!steps) {
            return;
        }
        for (const step of steps) {
            const task = new vscode.Task({ type: "stateui", suite: `conformance ${rebuild}` }, folder,
                `Conformance - Rebuild ${rebuild}: ${path.basename(step.args.find((each) => each.includes(path.sep)) ?? step.command)}`, "StateUI",
                new vscode.ShellExecution(step.command, [...step.args], { cwd: step.cwd, env: step.env }), []);
            task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
            if ((await runTask(task)) !== 0) {
                void vscode.window.showErrorMessage(`StateUI: ${describe(chosen).label}'s marks were not made again - the terminal says why.`);
                return;
            }
        }
        void vscode.window.showInformationMessage(`StateUI: ${describe(chosen).label}'s marks are made again, and the documents rendered from them.`);
    };

    context.subscriptions.push(
        vscode.commands.registerCommand("stateui.conformanceRebuildAll", () => rebuildConformance("all")),
        vscode.commands.registerCommand("stateui.conformanceRebuildChanged", () => rebuildConformance("changed")),
        vscode.commands.registerCommand("stateui.selectHost", async () => {
            if (availableHosts().length === 0) {
                void vscode.window.showInformationMessage(`StateUI: ${noHost}`);
                return;
            }
            const picked = await vscode.window.showQuickPick(
                // Android, UIKit and the Web are offered where an application has their head.
                availableHosts().filter((each) => !["android", "uikit", "web"].includes(each.id) || runnable(each.id).length > 0).map((each) => ({
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
        vscode.commands.registerCommand("stateui.selectApplication", async () => {
            const chosenHost = host();
            if (!chosenHost) {
                void vscode.window.showInformationMessage(`StateUI: ${noHost}`);
                return undefined;
            }
            return askForApplication(chosenHost);
        }),
        vscode.commands.registerCommand("stateui.selectAndroidDevice", async () => {
            const checkout = [chosen()?.checkout, ...applications().map((each) => each.checkout)]
                .find((each): each is string => each !== undefined && fs.existsSync(androidScript(each, "devices.sh")));
            if (!checkout) {
                void vscode.window.showErrorMessage("StateUI: Android devices are listed by a StateUI checkout's .scripts/Android/devices.sh, and no application here names one.");
                return;
            }
            await askForDevice(checkout, state);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectUIKitDevice", async () => {
            await askForUIKitDevice(state);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectBrowser", async () => {
            const checkout = [chosen()?.checkout, ...applications().map((each) => each.checkout)]
                .find((each): each is string => each !== undefined && fs.existsSync(webScript(each, "browsers.sh")));
            if (!checkout) {
                void vscode.window.showErrorMessage("StateUI: browsers are listed by a StateUI checkout's .scripts/Web/browsers.sh, and no application here names one.");
                return;
            }
            await askForBrowser(checkout, state);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.runTests", async () => {
            const folder = vscode.workspace.workspaceFolders?.[0];
            const suites = folder ? findSuites(folder.uri.fsPath, host()) : [];
            if (!folder || suites.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: no test suite here runs as ${runningAs()}.`);
                return;
            }

            const picked = await vscode.window.showQuickPick(
                suites.map((suite) => ({ label: suite.label, detail: suite.detail, picked: true, suite })),
                { canPickMany: true, placeHolder: `The suites to run as ${runningAs()}` });
            if (!picked || picked.length === 0) {
                return;
            }

            let chosenSuites = picked.map((each) => each.suite);
            if (chosenSuites.some((each) => each.onDevice)) {
                const serial = host() === "uikit" ? await uiKitDevice() : await androidDevice(folder.uri.fsPath);
                if (!serial) {
                    return;
                }
                chosenSuites = chosenSuites.map((each) => forDevice(each, serial));
            }

            const failed = await runSuites(folder, chosenSuites);
            if (failed.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: all ${picked.length} suites passed as ${runningAs()}.`);
            } else {
                void vscode.window.showErrorMessage(
                    `StateUI: ${failed.length} of ${picked.length} suites failed as ${runningAs()}: ${failed.join(", ")}. Their output is in the terminal.`);
            }
        }),
        vscode.commands.registerCommand("stateui.newApplicationInApps", async (given?: { folder?: string; name?: string }) => {
            const keeping = (vscode.workspace.workspaceFolders ?? []).filter((each) => keepsApps(each.uri.fsPath));
            const folder = given?.folder ?? (keeping.length > 1
                ? (await vscode.window.showWorkspaceFolderPick({ placeHolder: "Which folder's apps/ is the application made in?" }))?.uri.fsPath
                : keeping[0]?.uri.fsPath);
            if (!folder || !keepsApps(folder)) {
                void vscode.window.showErrorMessage("StateUI: no folder here keeps applications in apps/ - a StateUI checkout or a project group does.");
                return undefined;
            }

            // The checkout its applications build with; in a group whose apps/ holds none yet, the local one.
            const checkout = checkoutOf(folder) ?? await localCheckout();
            if (!checkout) {
                return undefined;
            }
            const apps = path.join(folder, "apps");
            const name = given?.name ?? await askApplicationName(apps, "New Application in apps/");
            if (!name) {
                return undefined;
            }

            const made = await makeApplication(checkout, apps, name);
            scaffolder.appendLine(made.output);
            if (!made.made) {
                reportFailure(`${name} was not made`);
                return undefined;
            }

            // Runnable at once: chosen, and indexed as the host the editor works as.
            await selectApplication(name);
            await applyEditorMode(host(), roots());
            void vscode.window.showInformationMessage(`StateUI: apps/${name} is made and chosen - StateUI: Debug runs it.`);
            return path.join(apps, name);
        }),
        vscode.commands.registerCommand("stateui.newProjectGroup", async (given?: {
            location?: string; name?: string; release?: string; checkout?: string; application?: string;
        }) => {
            const location = given?.location ?? (await vscode.window.showOpenDialog({
                canSelectFolders: true, canSelectFiles: false, canSelectMany: false,
                title: "New Project Group: where is it made?", openLabel: "Make the Group Here",
            }))?.[0]?.fsPath;
            if (!location) {
                return undefined;
            }
            const taken = (value: string): string | undefined =>
                groupNameProblem(value) ?? (fs.existsSync(path.join(location, value)) ? `${path.join(location, value)} already exists.` : undefined);
            const name = given?.name ?? await vscode.window.showInputBox({
                title: "New Project Group",
                prompt: `The group's folder, made in ${location}: apps/, and what git and the editor need beside it.`,
                placeHolder: "MyApps",
                ignoreFocusOut: true,
                validateInput: taken,
            });
            if (!name) {
                return undefined;
            }
            if (taken(name)) {
                void vscode.window.showErrorMessage(`StateUI: ${taken(name)}`);
                return undefined;
            }
            const group = path.join(location, name);

            // Where its StateUI comes from: a release cloned into the group, or the local checkout.
            const minimum = vscode.workspace.getConfiguration("stateui").get<string>("minimumRelease", "0.5.0");
            let release = given?.release;
            let checkout = given?.checkout;
            if (!release && !checkout) {
                const source = await vscode.window.showQuickPick([
                    { label: "A release from GitHub", detail: `A release, ${minimum} or newer, cloned into the group's StateUI/.`, release: true },
                    { label: "The local checkout", detail: "The StateUI checkout open here, else the one stateui.checkout names, else asked for.", release: false },
                ], { title: "New Project Group", placeHolder: "Which StateUI do the group's applications build with?", ignoreFocusOut: true });
                if (!source) {
                    return undefined;
                }
                if (source.release) {
                    const listed = await vscode.window.withProgress(
                        { location: vscode.ProgressLocation.Notification, title: `StateUI: reading the releases of ${repository}` },
                        () => listReleases(repository, minimum));
                    if (listed.problem) {
                        scaffolder.appendLine(listed.problem);
                        reportFailure(`the releases of ${repository} were not read`);
                        return undefined;
                    }
                    if (listed.releases.length === 0) {
                        void vscode.window.showWarningMessage(
                            `StateUI: no release ${minimum} or newer is published yet - an older one builds differently from this extension. The local checkout builds with it.`);
                        return undefined;
                    }
                    release = await vscode.window.showQuickPick(listed.releases, {
                        title: "New Project Group", placeHolder: `The release the group's applications build with - ${minimum} or newer`, ignoreFocusOut: true,
                    });
                    if (!release) {
                        return undefined;
                    }
                } else {
                    checkout = await localCheckout();
                    if (!checkout) {
                        return undefined;
                    }
                }
            }
            if (checkout && !isCheckout(checkout)) {
                void vscode.window.showErrorMessage(`StateUI: ${checkout} is not a StateUI checkout - it has no .scripts/new-app.sh and apps/HelloWorld.`);
                return undefined;
            }

            const library = release ? releaseDirectory(group) : checkout;
            const application = given?.application ?? await askApplicationName(path.join(group, "apps"), "New Project Group: its first application");
            if (!library || !application) {
                return undefined;
            }

            const made = await vscode.window.withProgress(
                { location: vscode.ProgressLocation.Notification, title: `StateUI: making ${name}` },
                async (progress) => {
                    makeProjectGroup(group, repository);
                    if (release) {
                        progress.report({ message: `cloning StateUI ${release}` });
                        const cloned = await cloneRelease(repository, release, group);
                        scaffolder.appendLine(cloned.output);
                        if (!cloned.cloned) {
                            reportFailure(`StateUI ${release} was not cloned into ${group}`);
                            return false;
                        }
                    }
                    progress.report({ message: `making apps/${application}` });
                    const scaffolded = await makeApplication(library, path.join(group, "apps"), application);
                    scaffolder.appendLine(scaffolded.output);
                    if (!scaffolded.made) {
                        reportFailure(`${application} was not made in ${group}`);
                    }
                    return scaffolded.made;
                });
            if (!made) {
                return undefined;
            }

            void vscode.window.showInformationMessage(
                `StateUI: ${group} is made, building with ${release ? `StateUI ${release}` : checkout}, and holds apps/${application}.`,
                "Open", "Open in New Window").then(async (answer) => {
                    if (answer) {
                        await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(group), { forceNewWindow: answer === "Open in New Window" });
                    }
                });
            return group;
        }),
        vscode.commands.registerCommand("stateui.reinstallExtension", async () => {
            const folder = (vscode.workspace.workspaceFolders ?? []).find((each) => hasExtensionSources(each.uri.fsPath));
            if (!folder) {
                void vscode.window.showErrorMessage("StateUI: the extension is built from a StateUI checkout's lib/StateUI.VSCode, which no folder here has.");
                return;
            }
            for (const step of reinstallSteps(folder.uri.fsPath, editorCommandLine(vscode.env.appRoot))) {
                const task = new vscode.Task({ type: "stateui", step: path.basename(step.command) }, folder,
                    `Reinstall the extension: ${path.basename(step.command)} ${step.args[0]}`, "StateUI",
                    new vscode.ShellExecution({ value: step.command, quoting: vscode.ShellQuoting.Strong },
                        step.args.map((each) => ({ value: each, quoting: vscode.ShellQuoting.Strong })), { cwd: step.cwd }), []);
                task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
                if ((await runTask(task)) !== 0) {
                    void vscode.window.showErrorMessage(`StateUI: the extension was not reinstalled - the terminal says why.`);
                    return;
                }
            }
            const answer = await vscode.window.showInformationMessage(
                "StateUI: the extension is built and installed - reload the window to run it.", "Reload Window");
            if (answer) {
                await vscode.commands.executeCommand("workbench.action.reloadWindow");
            }
        }),
        vscode.commands.registerCommand("stateui.checkToolchain", async () => {
            const findings = await vscode.window.withProgress(
                { location: vscode.ProgressLocation.Notification, title: "StateUI: checking the toolchain" },
                () => checkToolchain());
            const types = vscode.extensions.all.flatMap((each) =>
                ((each.packageJSON?.contributes?.debuggers ?? []) as { type?: string }[]).map((debug) => debug.type ?? ""));
            const starts = await lldbDapFinding(vscode.workspace.getConfiguration("lldb-dap").get<string>("executable-path"));
            const all = [...findings, debuggerFinding(types), ...(starts ? [starts] : [])];
            const served = availableHosts().map((each) => each.label).join(", ");
            toolchain.clear();
            toolchain.appendLine(`What ${served || "StateUI"} needs on this machine (${process.platform}, ${process.arch}):`);
            report(all).forEach((line) => toolchain.appendLine(line));
            toolchain.show(true);
            const missing = all.filter((each) => each.found === undefined).length;
            if (missing === 0) {
                void vscode.window.showInformationMessage(`StateUI: everything ${served || "StateUI"} needs is here.`);
            } else {
                void vscode.window.showWarningMessage(
                    `StateUI: ${missing} of ${all.length} components are missing - the output says what to install.`);
            }
        }),
        // The answers can come as an argument - the application's folder, the architecture - as the suite gives them.
        vscode.commands.registerCommand("stateui.deploy", async (asked?: { application?: string; architecture?: Architecture }) => {
            const forHost = host();
            if (!forHost) {
                void vscode.window.showErrorMessage(`StateUI: ${noHost}`);
                return undefined;
            }
            const application = asked?.application
                ? findApplications(path.dirname(path.dirname(asked.application))).find((each) => each.directory === asked.application)
                : chosen() ?? await askForApplication(forHost);
            if (!application) {
                return undefined;
            }
            const offered = forHost === "winui" ? winUIArchitectures() : [];
            const architecture = asked?.architecture ?? (offered.length > 1
                ? (await vscode.window.showQuickPick(
                    offered.map((each, index) => ({ label: each, description: index === 0 ? "this machine's own" : "run by Windows' emulation" })),
                    { title: `StateUI: Deploy ${application.name} for which architecture?`, ignoreFocusOut: true }))?.label as Architecture | undefined
                : offered[0]);
            if (forHost === "winui" && !architecture) {
                return undefined;
            }
            const device = forHost === "android" && application.checkout ? await androidDevice(application.checkout)
                : forHost === "uikit" ? await uiKitDevice() : undefined;
            if ((forHost === "android" || forHost === "uikit") && !device) {
                return undefined;
            }

            const destination = deployDestination(application, forHost, architecture);
            const step = deployCommand(application, forHost, destination, architecture, device);
            if (!step || !fs.existsSync(step.script)) {
                void vscode.window.showErrorMessage(
                    `StateUI: ${application.name} is deployed by a StateUI checkout's .scripts/${describe(forHost).label}/${path.basename(step?.script ?? "deploy")}, which ${step ? "it does not have" : "its Package.swift names none of by path"}.`);
                return undefined;
            }
            const task = new vscode.Task(
                { type: "stateui", application: application.name, configuration: "release", device: architecture ?? device ?? forHost },
                vscode.TaskScope.Workspace, `Deploy ${application.name} (${describe(forHost).label}${architecture ? `, ${architecture}` : ""})`,
                "StateUI", new vscode.ProcessExecution(step.command, step.args, { cwd: path.dirname(path.dirname(application.directory)) }), []);
            task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated };
            if ((await runTask(task)) !== 0) {
                void vscode.window.showErrorMessage(`StateUI: ${application.name} was not deployed - the terminal says why.`);
                return undefined;
            }
            void vscode.window.showInformationMessage(`StateUI: ${application.name} is deployed in ${destination}.`, "Reveal")
                .then((answer) => answer && vscode.commands.executeCommand("revealFileInOS", vscode.Uri.file(destination)));
            return destination;
        }),
        vscode.commands.registerCommand("stateui.cleanIndex", async () => {
            await cleanIndex(roots());
            void vscode.window.setStatusBarMessage("StateUI: the index is being built again", 4000);
        }));

    const provider = new StateUIDebugConfigurationProvider({
        host,
        run: runTask,
        start: startTask,
        ready: (file, task) => readyWhen(file, task),
        device: androidDevice,
        uiKitDevice,
        browser,
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

    // A checkout's own commands show in a checkout alone; New Application in apps/ in a checkout or a project group.
    const updateFolderContexts = (): void => {
        const folders = (vscode.workspace.workspaceFolders ?? []).map((folder) => folder.uri.fsPath);
        void vscode.commands.executeCommand("setContext", "stateui.hasCheckout", folders.some(isCheckout));
        void vscode.commands.executeCommand("setContext", "stateui.hasApps", folders.some(keepsApps));
    };
    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(updateFolderContexts));
    updateFolderContexts();

    refresh();
    await applyEditorMode(host(), roots());

    const selectUIKitDevice = async (wanted: string): Promise<string | undefined> => {
        const name = await chooseListedUIKitDevice(state, wanted);
        refresh();
        return name;
    };

    return { host, selectHost, application: () => state.get<string>(applicationKey), selectApplication, selectUIKitDevice };
}

export function deactivate(): void {}
