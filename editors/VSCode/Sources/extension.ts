// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension: a host and an application chosen once - and for Android a
// device, for UIKit an iPhone, an iPad or a simulator, for the Web a browser, for GTK and WinUI on a Mac a guest - the
// editor working as that host, one Debug and one Release that run the application on it, and the suites run as it.

import { randomUUID } from "crypto";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as vscode from "vscode";
import { Application, applicationsOf, hasHead, pathOf, readApplications } from "./applications";
import { isCheckout } from "./checkouts";
import { Configuration, runPlace, configurations, noHost, StateUIDebugConfigurationProvider } from "./debug";
import { chosenApplication, chosenHost, DeviceStore, offeredHosts } from "./choices";
import { AndroidLister, androidDeviceOf, askForDevice, chooseListedDevice, deviceToRunOn } from "./devices";
import { askForBrowser, Browser, BrowserLister, browserOf, browserToRunOn, chooseListedBrowser } from "./browsers";
import { applyEditorMode, cleanIndex, IndexAcquirer, IndexConflictError, IndexDescriber } from "./editorMode";
import { askForGuest, Guest, GuestLister, guestOf, guestToRunIn } from "./guests";
import { availableHosts, describe, Host, HostDescription, placeOf } from "./hosts";
import {
    askForUIKitDevice, chooseListedUIKitDevice, uiKitDeviceOf, UIKitLister, uiKitDeviceToRunOn, uiKitSimulatorToTestOn,
} from "./uiKitDevices";
import { TestSuites } from "./tests";
import { writeEditorFiles } from "./projectGroup";
import { editorCommandLine, hasExtensionSources } from "./reinstall";
import { conformanceRequest, failedPhases, Rebuild } from "./conformance";
import { debuggerFinding, Finding, lldbDapFinding, report } from "./toolchain";
import { pathToFileUri } from "./Tooling/client";
import { Architecture as ToolArchitecture, HostPlace, LaunchedApplication, NameKind, Settings } from "./Tooling/protocol";
import { runOperation, sayProblem, toolingClients, withTool } from "./Tooling/presentation";
import { ToolRequestError } from "./Tooling/client";
import { Architecture, packageDestination, toolArchitecture, windowsArchitecture } from "./packaging";

/** What the extension answers to another extension - and to its own tests. */
export interface StateUIApi {
    host(): Host | undefined;
    selectHost(host: Host): Promise<void>;
    application(): string | undefined;
    selectApplication(name: string): Promise<void>;
    /** Chooses the iPhone, iPad or simulator listed by `wanted` - its id or its name - and answers its name. */
    selectUIKitDevice(wanted: string): Promise<string | undefined>;
    /** Chooses the Android device listed by `wanted` - its serial or its name - and answers its name. */
    selectAndroidDevice(wanted: string): Promise<string | undefined>;
    /** Chooses the browser listed by `wanted` - its id or its name - and answers its name. */
    selectBrowser(wanted: string): Promise<string | undefined>;
    /** The applications the stateui tool found in the workspace's folders. */
    applications(): readonly Application[];
}

// What the window keeps of its own: the host and devices of a window holding no application, and which application
// of several folders it works on (choices.ts); the rest stands in the projects' `.stateui/`, through the tool.
const hostKey = "stateui.host";
const devicesKey = "stateui.devices";
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

    // The stateui tool, one connection per folder.
    const tool = toolingClients(context);

    // What a host's code is indexed with, and every index taken away - the tool's facts, through the first folder.
    const describeIndex: IndexDescriber = async (forHost) => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        return folder === undefined ? undefined : withTool(tool, folder, "the index could not be described",
            (client) => client.request("index/describe", forHost ? { host: forHost } : {}));
    };
    // This window's lease of the packages it indexes, held by the first folder's connection while the window lives.
    const acquireIndex: IndexAcquirer = async (forHost, folders) => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        return folder === undefined ? undefined : withTool(tool, folder, "the packages' index could not be leased",
            (client) => client.request("index/acquire", { ...(forHost ? { host: forHost } : {}), rootUris: folders.map(pathToFileUri) }));
    };
    const cleanIndexes = (folders: readonly string[]) => withTool(tool, folders[0] ?? ".", "the index was not cleaned",
        (client) => client.request("index/clean", { rootUris: folders.map(pathToFileUri) }));

    // What the tool's builds and packages said: SwiftPM's words, the bundle's assembly.
    const buildOutput = vscode.window.createOutputChannel("StateUI Build");
    context.subscriptions.push(buildOutput);

    // What the tool found in each folder: its applications - each a folder holding its stateui.json - and the
    // workspace - the folder of a stateui-workspace.json - holding them. Read on activation, and again when a folder,
    // either file, a manifest or a head comes or goes.
    let found: { readonly applications: Application[]; readonly workspace?: string }[] = [];
    let unread = false;
    const discover = async (): Promise<void> => {
        const folders = (vscode.workspace.workspaceFolders ?? []).map((each) => each.uri.fsPath);
        found = await Promise.all(folders.map(async (folder) => {
            try {
                const project = await readApplications(await tool.for(folder));
                unread = false;
                return { applications: project ? applicationsOf(project) : [], workspace: project?.workspaceUri && pathOf(project.workspaceUri) };
            } catch (error) {
                // Said once until a folder is read again: a missing tool would say it on every change.
                if (!unread) {
                    unread = true;
                    sayProblem(`no application of ${folder} was read`, error);
                }
                return { applications: [] };
            }
        }));
        await readPlaces(folders[0]);
        await readChoices();
    };
    const applications = (): Application[] => found.flatMap((each) => each.applications);

    // The hosts this machine builds and where their heads run, as the tool says them (`server/info`) - read once.
    let places: HostPlace[] = [];
    const readPlaces = async (folder: string | undefined): Promise<void> => {
        if (places.length > 0) {
            return;
        }
        const info = await withTool(tool, folder ?? os.homedir(), "this machine's hosts were not read",
            (client) => client.request("server/info", {}));
        places = info?.hosts ?? [];
    };
    /** Where `forHost`'s heads run from this machine; nothing where it builds none. */
    const place = (forHost: Host) => placeOf(forHost, places);
    /** Whether this machine works `forHost`'s heads in a guest of its own. */
    const inGuest = (forHost: Host): boolean => place(forHost) === "guest";

    // What was chosen, as the tool keeps it: each workspace's application to start, by its folder, and the chosen
    // application's host and devices - read with the applications, and again when a settings file changes.
    let startups = new Map<string, string>();
    let settings: Settings | undefined;
    const readChoices = async (): Promise<void> => {
        const read = new Map<string, string>();
        for (const workspace of new Set(found.flatMap((each) => each.workspace ? [each.workspace] : []))) {
            const said = await withTool(tool, workspace, "what was chosen was not read",
                (client) => client.request("settings/get", { projectUri: pathToFileUri(workspace) }));
            if (said?.startup) {
                read.set(workspace, said.startup);
            }
        }
        startups = read;
        const application = chosen();
        // The application worked on is its workspace's to start - the first it lists where none was chosen yet.
        const workspace = application?.workspace;
        if (application && workspace && !startups.has(workspace) && await withTool(tool, workspace, `${application.name} was not chosen to start`,
            (client) => client.run("settings/set", { projectUri: pathToFileUri(workspace), startup: application.name }))) {
            startups.set(workspace, application.name);
        }
        settings = application && await withTool(tool, application.directory, `what was chosen for ${application.name} was not read`,
            (client) => client.request("settings/get", { projectUri: pathToFileUri(application.directory) }));
    };

    /** The applications that have a head for `host`. */
    const runnable = (host: Host): Application[] => applications().filter((each) => hasHead(each, host));

    // The packages whose manifest reads a host's variable: the applications.
    const roots = (): string[] => applications().map((each) => each.directory);

    /** The application the window works on (`chosenApplication`). */
    const chosen = (): Application | undefined => chosenApplication(applications(), startups, state.get<string>(applicationKey));

    /** The hosts the window can work as: this machine's, the chosen application's heads alone (`offeredHosts`). */
    const offered = (): HostDescription[] => offeredHosts(availableHosts(places), chosen());

    /** The host the window works as, one it offers (`chosenHost`); none where it offers none. */
    const host = (): Host | undefined => chosenHost(offered(), settings?.host, state.get<Host>(hostKey));

    /** Why the window works as no host: the chosen application runs on none here, or no application is here. */
    const whyNoHost = (): string => {
        const application = chosen();
        return availableHosts(places).length === 0 ? noHost
            : application ? `${application.name} has no head this machine runs.` : "no application is here.";
    };

    // The devices: the chosen application's, written through the tool; a window holding none keeps its own.
    const devices: DeviceStore = {
        device: (forHost) => chosen() ? settings?.devices[forHost] : state.get<Record<string, string>>(devicesKey)?.[forHost],
        choose: async (forHost, device) => {
            const application = chosen();
            if (!application) {
                await state.update(devicesKey, { ...state.get<Record<string, string>>(devicesKey), [forHost]: device });
                return;
            }
            settings = await withTool(tool, application.directory, `${device} was not chosen for ${application.name}`,
                (client) => client.run("settings/set", { projectUri: pathToFileUri(application.directory), devices: { [forHost]: device } }))
                ?? settings;
        },
    };

    /** What the suites and the editor run as: the host chosen, or plain Swift. */
    const runningAs = (): string => {
        const chosenHost = host();
        return chosenHost ? describe(chosenHost).label : "plain Swift";
    };


    // The application, then the host it runs as, then its device, left to right.
    const applicationItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    applicationItem.command = "stateui.selectApplication";
    const hostItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 49);
    hostItem.command = "stateui.selectHost";
    const deviceItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 48);
    deviceItem.command = "stateui.selectAndroidDevice";
    context.subscriptions.push(hostItem, applicationItem, deviceItem);

    // What StateUI: Check Toolchain found, component by component.
    const toolchain = vscode.window.createOutputChannel("StateUI Toolchain");
    context.subscriptions.push(toolchain);

    // What the stateui tool and git said while making an application or a project group.
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
            void vscode.window.showErrorMessage(`StateUI: ${picked} is not a StateUI checkout - it has no Package.swift, lib/StateUI.Head and apps/HelloWorld.`);
            return undefined;
        }
        return picked;
    };

    /**
     * Asks for the name of a `kind` made in `parent`, each answer checked by the tool (`name/check`) through the
     * connection of `folder`, a folder that stands.
     */
    const askName = (kind: NameKind, parent: string, folder: string, title: string, prompt: string): Thenable<string | undefined> =>
        vscode.window.showInputBox({
            title, prompt, placeHolder: kind === "application" ? "MyApp" : "MyApps", ignoreFocusOut: true,
            validateInput: async (value) => {
                try {
                    const client = await tool.for(folder);
                    return (await client.request("name/check", { kind, name: value, parentUri: pathToFileUri(parent) })).problem;
                } catch {
                    return undefined;
                }
            },
        });
    const applicationPrompt = "The application's name: its folder, process and Swift module (<Name>UI).";

    const refresh = (): void => {
        const application = chosen();
        applicationItem.text = `$(window) ${application?.name ?? "Select Application"}`;
        applicationItem.tooltip = `The application StateUI: Debug and StateUI: Release run, and whose host the window works as. Click to change.`;
        applications().length > 0 ? applicationItem.show() : applicationItem.hide();

        const workingAs = host();
        if (!workingAs) {
            hostItem.text = "$(server-environment) StateUI: no host";
            hostItem.tooltip = `StateUI: ${whyNoHost()} StateUI: Run Tests and the editor work as plain Swift.`;
            hostItem.show();
            deviceItem.hide();
            return;
        }

        const described = describe(workingAs);
        hostItem.text = `$(server-environment) StateUI: ${described.label}`;
        hostItem.tooltip = `StateUI: Debug, StateUI: Release, StateUI: Run Tests and the editor work as ${described.label} - ${described.detail}. Click to change.`;
        hostItem.show();

        const device = devices.device(described.id);
        if (described.id === "web") {
            deviceItem.command = "stateui.selectBrowser";
            deviceItem.text = `$(globe) ${device ?? "Select Browser"}`;
            deviceItem.tooltip = "The browser StateUI: Debug and StateUI: Release open the application in - one of Chromium's under VS Code's debugger. Click to change.";
        } else if (inGuest(described.id)) {
            deviceItem.command = "stateui.selectGuest";
            deviceItem.text = `$(vm) ${device ?? "Select Guest"}`;
            deviceItem.tooltip = `The Parallels guest StateUI: Debug, StateUI: Release and StateUI: Package build and run ${described.label} heads in. Click to change.`;
        } else if (described.id === "uikit") {
            deviceItem.command = "stateui.selectUIKitDevice";
            deviceItem.text = `$(device-mobile) ${device ?? "Select UIKit Device"}`;
            deviceItem.tooltip = "The iPhone, iPad or simulator StateUI: Debug, StateUI: Release and StateUI: Run Tests run on. Click to change.";
        } else {
            deviceItem.command = "stateui.selectAndroidDevice";
            deviceItem.text = `$(device-mobile) ${device ?? "Select Android Device"}`;
            deviceItem.tooltip = "The Android device StateUI: Debug, StateUI: Release and StateUI: Run Tests run on. Click to change.";
        }
        // A host whose heads run elsewhere than on this machine itself shows where: a device, a browser, a guest.
        place(described.id) !== undefined && place(described.id) !== "machine" ? deviceItem.show() : deviceItem.hide();
    };

    /** The editor made to work as `forHost` - false where another window indexes a package as another host, said. */
    const workAs = async (forHost: Host | undefined): Promise<boolean> => {
        try {
            return await applyEditorMode(forHost, roots(), describeIndex, acquireIndex);
        } catch (error) {
            if (!(error instanceof IndexConflictError)) {
                throw error;
            }
            void vscode.window.showWarningMessage(`StateUI: ${error.message}, so this window's index stays as it was.`);
            return false;
        }
    };

    // The host chosen: the chosen application's - one it has a head for - through the tool, and the window's own.
    const chooseHost = async (picked: Host | undefined): Promise<void> => {
        await state.update(hostKey, picked);
        const application = chosen();
        if (application && picked && application.hosts.includes(picked)) {
            settings = await withTool(tool, application.directory, `${describe(picked).label} was not chosen for ${application.name}`,
                (client) => client.run("settings/set", { projectUri: pathToFileUri(application.directory), host: picked })) ?? settings;
        }
    };

    // A host another window indexes a package as is refused, the host chosen before kept.
    const selectHost = async (picked: Host): Promise<void> => {
        const previous = host();
        await chooseHost(picked);
        refresh();
        testSuites.changed();

        try {
            if (await applyEditorMode(picked, roots(), describeIndex, acquireIndex)) {
                void vscode.window.setStatusBarMessage(`StateUI: the editor works as ${describe(picked).label}`, 4000);
            }
        } catch (error) {
            if (!(error instanceof IndexConflictError)) {
                throw error;
            }
            await chooseHost(previous);
            refresh();
            testSuites.changed();
            void vscode.window.showErrorMessage(`StateUI: ${error.message}: this window stays ${runningAs()}.`);
        }
    };

    // The application chosen: its workspace's to start, through the tool, and the window's own; the window then works
    // as its host.
    const selectApplication = async (name: string): Promise<void> => {
        const before = host();
        await state.update(applicationKey, name);
        const workspace = applications().find((each) => each.name === name)?.workspace;
        if (workspace) {
            await withTool(tool, workspace, `${name} was not chosen to start`,
                (client) => client.run("settings/set", { projectUri: pathToFileUri(workspace), startup: name }));
        }
        await readChoices();
        refresh();
        testSuites.changed();
        if (host() !== before) {
            await workAs(host());
        }
    };

    /** Asks for an application - one with a head for `forHost`, where one is given - the chosen one offered first. */
    const askForApplication = async (forHost?: Host): Promise<Application | undefined> => {
        const candidates = forHost ? runnable(forHost) : applications();
        if (candidates.length === 0) {
            void vscode.window.showErrorMessage(forHost ? `StateUI: no application here has ${heads[forHost]}.` : "StateUI: no application is here.");
            return undefined;
        }

        const current = chosen()?.name;
        const ordered = [...candidates].sort((a, b) => Number(b.name === current) - Number(a.name === current));
        const picked = await vscode.window.showQuickPick(
            ordered.map((each) => ({
                label: each.name,
                description: each.name === current ? "current" : undefined,
                detail: vscode.workspace.asRelativePath(each.directory),
                application: each,
            })),
            { placeHolder: forHost ? `Which application do StateUI: Debug and StateUI: Release run on ${describe(forHost).label}?`
                : "Which application do StateUI: Debug and StateUI: Release run - the window working as its host?", ignoreFocusOut: true });

        if (picked) {
            await selectApplication(picked.application.name);
        }
        return picked?.application;
    };

    /** The Android devices, emulators and virtual devices the tool lists, through any folder's connection. */
    const listAndroid: AndroidLister = async () => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!folder) {
            void vscode.window.showErrorMessage("StateUI: the Android devices are listed for a folder, and none is open.");
            return undefined;
        }
        const listed = await withTool(tool, folder, "the Android devices could not be listed",
            (client) => client.request("devices/list", { host: "android" }));
        return listed?.destinations.map(androidDeviceOf);
    };

    /** The Android device a launch or a suite runs on - asked for where none chosen is listed. */
    const androidDevice = async (): Promise<string | undefined> => {
        const serial = await deviceToRunOn(devices, listAndroid);
        refresh();
        return serial;
    };

    /** The iPhones, iPads and simulators the tool lists, through any folder's connection: the list names no project. */
    const listUIKit: UIKitLister = async () => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!folder) {
            void vscode.window.showErrorMessage("StateUI: the iPhones, iPads and simulators are listed for a folder, and none is open.");
            return undefined;
        }
        const listed = await withTool(tool, folder, "the iPhones, iPads and simulators could not be listed",
            (client) => client.request("devices/list", { host: "uikit" }));
        return listed?.destinations.map(uiKitDeviceOf);
    };

    /** The iPhone, iPad or simulator a UIKit launch or suite runs on - asked for where none chosen is listed. */
    const uiKitDevice = async (): Promise<string | undefined> => {
        const id = await uiKitDeviceToRunOn(devices, listUIKit);
        refresh();
        return id;
    };

    /** The simulator a UIKit suite runs on - the host's suite runs on no device - leaving a launch's device as it is. */
    const uiKitSimulator = async (): Promise<string | undefined> => {
        const id = await uiKitSimulatorToTestOn(devices, state, listUIKit);
        refresh();
        return id;
    };

    /** The guests of this Mac of `forHost`'s system the tool lists, through any folder's connection. */
    const listGuests: GuestLister = async (forHost) => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!folder) {
            void vscode.window.showErrorMessage("StateUI: the guests are listed for a folder, and none is open.");
            return undefined;
        }
        const listed = await withTool(tool, folder, "the guests could not be listed",
            (client) => client.request("devices/list", { host: forHost }));
        return listed?.destinations.filter((each) => each.kind === "guest").map(guestOf);
    };

    /** The guest a launch of a host worked in one is built and run in - asked for where none chosen is listed. */
    const guest = async (forHost: Host): Promise<Guest | undefined> => {
        const found = await guestToRunIn(devices, forHost, listGuests);
        refresh();
        return found;
    };

    /** The architectures this machine builds `forHost`'s heads for, its own first, as the tool lists the machine. */
    const machineArchitectures = async (forHost: Host): Promise<ToolArchitecture[]> => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? os.homedir();
        const listed = await withTool(tool, folder, "this machine's architectures were not read",
            (client) => client.request("devices/list", { host: forHost }));
        const machine = listed?.destinations.find((each) => each.kind === "machine");
        return machine ? [...(machine.architecture ? [machine.architecture] : []), ...machine.emulated] : [];
    };

    // The suites in the Testing view, found and run by the tool as the chosen host.
    const testSuites = new TestSuites({
        tool, host, device: async (forHost) => forHost === "uikit" ? uiKitSimulator()
            : inGuest(forHost) ? (await guest(forHost))?.name : androidDevice(),
    });
    context.subscriptions.push(testSuites);

    /** The browsers the tool lists, through any folder's connection: the list names no project. */
    const listBrowsers: BrowserLister = async () => {
        const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!folder) {
            void vscode.window.showErrorMessage("StateUI: the browsers are listed for a folder, and none is open.");
            return undefined;
        }
        const listed = await withTool(tool, folder, "the browsers could not be listed",
            (client) => client.request("devices/list", { host: "web" }));
        return listed?.destinations.map(browserOf);
    };

    /** The browser a Web launch opens the page in - asked for where none chosen is installed. */
    const browser = async (): Promise<Browser | undefined> => {
        const found = await browserToRunOn(devices, listBrowsers);
        refresh();
        return found;
    };

    /** The chosen host's marks made again in the checkout - `rebuild` says which families - and the documents rendered. */
    const rebuildConformance = async (rebuild: Rebuild): Promise<void> => {
        const folder = (vscode.workspace.workspaceFolders ?? []).find((each) => isCheckout(each.uri.fsPath));
        const chosen = host();
        if (!folder || !chosen) {
            void vscode.window.showErrorMessage(`StateUI: the marks are made in a StateUI checkout, as the host chosen - ${folder ? whyNoHost() : "no folder here is one"}.`);
            return;
        }
        if (inGuest(chosen)) {
            void vscode.window.showErrorMessage(`StateUI: ${describe(chosen).label}'s marks are made on its own system - a Mac does not make them in its guest.`);
            return;
        }
        const device = chosen === "uikit" ? await uiKitSimulator() : chosen === "android" ? await androidDevice() : undefined;
        const request = conformanceRequest(chosen, rebuild, device);
        if (!request) {
            return;
        }
        buildOutput.clear();
        buildOutput.show(true);
        const ran = await withTool(tool, folder.uri.fsPath, `${describe(chosen).label}'s marks were not made again`, (client) =>
            runOperation(client, "repository/conformance", request, `StateUI: Conformance - Rebuild ${rebuild}: ${describe(chosen).label}`, buildOutput));
        if (!ran) {
            return;
        }
        const failed = failedPhases(ran);
        if (failed.length === 0) {
            void vscode.window.showInformationMessage(
                `StateUI: ${describe(chosen).label}'s marks are made again, and the documents rendered from them - ${ran.phases.map((each) => each.name).join(", ")}.`);
        } else {
            void vscode.window.showErrorMessage(`StateUI: ${describe(chosen).label}'s marks were not made again - ${failed.join(", ")} failed; StateUI Build says why.`);
        }
    };

    context.subscriptions.push(
        vscode.commands.registerCommand("stateui.conformanceRebuildAll", () => rebuildConformance("all")),
        vscode.commands.registerCommand("stateui.conformanceRebuildChanged", () => rebuildConformance("changed")),
        vscode.commands.registerCommand("stateui.selectHost", async () => {
            const application = chosen();
            if (!application || offered().length === 0) {
                void vscode.window.showInformationMessage(`StateUI: ${whyNoHost()}`);
                return;
            }
            const picked = await vscode.window.showQuickPick(
                offered().map((each) => ({
                    label: each.label,
                    description: each.id === host() ? "current" : undefined,
                    detail: each.detail,
                    id: each.id,
                })),
                { placeHolder: `Which of ${application.name}'s hosts do StateUI: Debug, StateUI: Run Tests and the editor work as?` });
            if (picked) {
                await selectHost(picked.id);
            }
        }),
        vscode.commands.registerCommand("stateui.selectApplication", async () => askForApplication()),
        vscode.commands.registerCommand("stateui.selectAndroidDevice", async () => {
            await askForDevice(devices, listAndroid);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectUIKitDevice", async () => {
            await askForUIKitDevice(devices, listUIKit);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectBrowser", async () => {
            await askForBrowser(devices, listBrowsers);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.selectGuest", async () => {
            const forHost = host();
            if (!forHost || !inGuest(forHost)) {
                void vscode.window.showErrorMessage("StateUI: a guest is chosen for GTK or WinUI on a Mac - select one of them as the host first.");
                return;
            }
            await askForGuest(devices, forHost, listGuests);
            refresh();
        }),
        vscode.commands.registerCommand("stateui.runTests", async () => {
            const suites = vscode.workspace.workspaceFolders ? (await testSuites.discover(), testSuites.suites()) : [];
            if (suites.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: no test suite here runs as ${runningAs()}.`);
                return;
            }

            const picked = await vscode.window.showQuickPick(
                suites.map(({ item, suite }) => ({ label: suite.id, detail: suite.detail, picked: true, item })),
                { canPickMany: true, placeHolder: `The suites to run as ${runningAs()}` });
            if (!picked || picked.length === 0) {
                return;
            }

            const cancelling = new vscode.CancellationTokenSource();
            const failed = await testSuites.run(new vscode.TestRunRequest(picked.map((each) => each.item)), cancelling.token);
            cancelling.dispose();
            if (failed.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: all ${picked.length} suites passed as ${runningAs()}.`);
            } else {
                void vscode.window.showErrorMessage(
                    `StateUI: ${failed.length} of ${picked.length} suites failed as ${runningAs()}: ${failed.join(", ")}. Their output is in Test Results.`);
            }
        }),
        // A new application in a workspace, beside its applications - or at its root where it lists none yet - building
        // with the library its stateui-workspace.json names.
        vscode.commands.registerCommand("stateui.newApplicationInApps", async (given?: { folder?: string; name?: string }) => {
            const folder = given?.folder ?? await (async () => {
                const workspaces = [...new Set(found.map((each) => each.workspace).filter((each): each is string => each !== undefined))];
                return workspaces.length > 1
                    ? (await vscode.window.showQuickPick(workspaces, { placeHolder: "Which workspace is the application made in?" }))
                    : workspaces[0];
            })();
            if (!folder) {
                void vscode.window.showErrorMessage("StateUI: no folder here is a workspace - a stateui-workspace.json lists its applications.");
                return undefined;
            }
            const project = await withTool(tool, folder, "the workspace was not read", async (client) => readApplications(client, folder));
            if (!project?.workspaceUri) {
                if (project) {
                    void vscode.window.showErrorMessage(`StateUI: ${folder} is no workspace - a stateui-workspace.json lists its applications.`);
                }
                return undefined;
            }
            const workspace = pathOf(project.workspaceUri);
            const beside = [...new Set(applicationsOf(project).map((each) => path.dirname(each.directory)))];
            const parent = beside.length === 1 ? beside[0] : workspace;
            const name = given?.name ?? await askName("application", parent, workspace, "New Application", applicationPrompt);
            if (!name) {
                return undefined;
            }

            const made = await withTool(tool, workspace, `${name} was not made`, (client) => runOperation(client, "project/create",
                { name, parentUri: pathToFileUri(parent) }, `StateUI: making ${name}`, scaffolder));
            if (!made) {
                return undefined;
            }

            // Runnable at once: found, chosen, and indexed as the host the editor works as.
            const directory = pathOf(made.createdUris[0]);
            await discover();
            await selectApplication(name);
            updateFolderContexts();
            await workAs(host());
            void vscode.window.showInformationMessage(
                `StateUI: ${vscode.workspace.asRelativePath(directory)} is made and chosen - StateUI: Debug runs it.`);
            return directory;
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
            const name = given?.name ?? await askName("workspace", location, location, "New Project Group",
                `The group's folder, made in ${location}: its stateui-workspace.json, the StateUI it builds with, and its applications.`);
            if (!name) {
                return undefined;
            }
            const group = path.join(location, name);

            // Where its StateUI comes from: a release cloned into the group, or the local checkout.
            const minimum = vscode.workspace.getConfiguration("stateui").get<string>("minimumRelease", "0.8.6");
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
                    const listed = await withTool(tool, location, `the releases of ${repository} were not read`, (client) =>
                        vscode.window.withProgress(
                            { location: vscode.ProgressLocation.Notification, title: `StateUI: reading the releases of ${repository}` },
                            () => client.request("releases/list", { minimum, repository })));
                    if (!listed) {
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
            const application = given?.application
                ?? await askName("application", group, location, "New Project Group: its first application", applicationPrompt);
            if (!application) {
                return undefined;
            }

            const made = await withTool(tool, location, `${name} was not made`, (client) => runOperation(client, "workspace/create", {
                name, parentUri: pathToFileUri(location), application,
                ...(release ? { release, repository } : { checkoutUri: pathToFileUri(checkout!) }),
            }, `StateUI: making ${name}`, scaffolder));
            if (!made) {
                return undefined;
            }
            const workspace = pathOf(made.workspaceUri);
            writeEditorFiles(workspace);

            void vscode.window.showInformationMessage(
                `StateUI: ${workspace} is made, building with ${release ? `StateUI ${release}` : checkout}, and holds ${application}.`,
                "Open", "Open in New Window").then(async (answer) => {
                    if (answer) {
                        await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(workspace), { forceNewWindow: answer === "Open in New Window" });
                    }
                });
            return workspace;
        }),
        vscode.commands.registerCommand("stateui.reinstallExtension", async () => {
            const folder = (vscode.workspace.workspaceFolders ?? []).find((each) => hasExtensionSources(each.uri.fsPath));
            if (!folder) {
                void vscode.window.showErrorMessage("StateUI: the extension is built from a StateUI checkout's editors/VSCode, which no folder here has.");
                return;
            }
            const editor = editorCommandLine(vscode.env.appRoot);
            if (!path.isAbsolute(editor)) {
                void vscode.window.showErrorMessage(`StateUI: the extension was not reinstalled - this editor's command line, ${editor}, is not beside it.`);
                return;
            }
            buildOutput.clear();
            buildOutput.show(true);
            const installed = await withTool(tool, folder.uri.fsPath, "the extension was not reinstalled", async (client) => {
                const made = await runOperation(client, "repository/integrationPackage", { editor: "vscode" },
                    "StateUI: packaging the extension", buildOutput);
                return runOperation(client, "repository/integrationInstall", { editorExtension: made, editorExecutableUri: pathToFileUri(editor) },
                    `StateUI: installing ${made.extensionId} ${made.version}`, buildOutput);
            });
            if (!installed) {
                return;
            }
            const answer = await vscode.window.showInformationMessage(
                `StateUI: ${installed.extensionId} ${installed.version} is built and installed - reload the window to run it.`, "Reload Window");
            if (answer) {
                await vscode.commands.executeCommand("workbench.action.reloadWindow");
            }
        }),
        // The findings, as the command's answer too - for the suite.
        vscode.commands.registerCommand("stateui.checkToolchain", async (): Promise<Finding[] | undefined> => {
            const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? os.homedir();
            // A host built in a guest: the guest chosen checked after this machine, for the chosen application.
            const forHost = host();
            const guested = forHost && inGuest(forHost) ? devices.device(forHost) : undefined;
            const application = chosen();
            const checked = await withTool(tool, folder, "the toolchain was not checked", (client) => vscode.window.withProgress(
                { location: vscode.ProgressLocation.Notification, title: "StateUI: checking the toolchain" },
                () => client.request("toolchain/check", forHost && guested
                    ? { host: forHost, device: guested, projectUri: application && pathToFileUri(application.directory) } : {})));
            if (!checked) {
                return undefined;
            }
            const findings = checked.findings;
            const types = vscode.extensions.all.flatMap((each) =>
                ((each.packageJSON?.contributes?.debuggers ?? []) as { type?: string }[]).map((debug) => debug.type ?? ""));
            const starts = await lldbDapFinding(vscode.workspace.getConfiguration("lldb-dap").get<string>("executable-path"));
            const all = [...findings, debuggerFinding(types), ...(starts ? [starts] : [])];
            const served = availableHosts(places).map((each) => each.label).join(", ");
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
            return all;
        }),
        // The answers can come as an argument - the application's folder, the architecture - as the suite gives them.
        vscode.commands.registerCommand("stateui.deploy", async (asked?: { application?: string; architecture?: Architecture }) => {
            const forHost = host();
            if (!forHost) {
                void vscode.window.showErrorMessage(`StateUI: ${whyNoHost()}`);
                return undefined;
            }
            const application = asked?.application
                ? await withTool(tool, asked.application, `${asked.application} was not read`, async (client) => {
                    const project = await readApplications(client, asked.application);
                    return project && applicationsOf(project).find((each) => each.directory === asked.application);
                })
                : chosen() ?? await askForApplication(forHost);
            if (!application) {
                return undefined;
            }
            // A guest's head is built there: the guest first, its architectures with it.
            const guested = inGuest(forHost) ? await guest(forHost) : undefined;
            if (inGuest(forHost) && !guested) {
                return undefined;
            }
            const offered = forHost === "winui"
                ? (guested?.architectures ?? await machineArchitectures(forHost)).flatMap((each) => windowsArchitecture(each) ?? [])
                : [];
            const architecture = asked?.architecture ?? (offered.length > 1
                ? (await vscode.window.showQuickPick(
                    offered.map((each, index) => ({ label: each, description: index === 0 ? (guested ? "the guest's own" : "this machine's own") : "run by Windows' emulation" })),
                    { title: `StateUI: Package ${application.name} for which architecture?`, ignoreFocusOut: true }))?.label as Architecture | undefined
                : offered[0]);
            if (forHost === "winui" && !architecture) {
                return undefined;
            }
            const device = forHost === "android" ? await androidDevice() : forHost === "uikit" ? await uiKitDevice() : guested?.name;
            if ((forHost === "android" || forHost === "uikit") && !device) {
                return undefined;
            }

            const destination = packageDestination(application, forHost, architecture);
            const laid = await withTool(tool, application.directory, `${application.name} was not packaged`, (client) =>
                runOperation(client, "application/package", {
                    projectUri: pathToFileUri(application.directory), host: forHost, outputUri: pathToFileUri(destination),
                    device: forHost === "uikit" || inGuest(forHost) ? device : undefined, architecture: architecture && toolArchitecture(architecture),
                }, `StateUI: packaging ${application.name}`, buildOutput));
            if (!laid) {
                return undefined;
            }
            void vscode.window.showInformationMessage(`StateUI: ${application.name} is packaged in ${destination}.`, "Reveal")
                .then((answer) => answer && vscode.commands.executeCommand("revealFileInOS", vscode.Uri.file(destination)));
            return destination;
        }),
        vscode.commands.registerCommand("stateui.cleanIndex", async () => {
            try {
                await cleanIndex(roots(), cleanIndexes);
            } catch (error) {
                if (!(error instanceof IndexConflictError)) {
                    throw error;
                }
                void vscode.window.showWarningMessage(`StateUI: the index stays - ${error.message}.`);
                return;
            }
            void vscode.window.setStatusBarMessage("StateUI: the index is being built again", 4000);
        }));

    // A UIKit, Android or Web run's output; each run a debug session's end stops, by the token its configuration
    // carries; and each run going, by its place - a second run in one place replaces the first.
    const runOutput = vscode.window.createOutputChannel("StateUI Run");
    const runs = new Map<string, () => void>();
    const going = new Map<string, { stop: () => void; ended: Promise<void> }>();
    context.subscriptions.push(runOutput, vscode.debug.onDidTerminateDebugSession((session) => {
        const token: unknown = session.configuration.stateuiRun;
        if (typeof token === "string") {
            runs.get(token)?.();
            runs.delete(token);
        }
    }));

    /**
     * A UIKit, Android or Web head built and started on `device` by the tool, followed in a notification that stops it
     * and in StateUI Run, a run going in its place stopped first; answers, once it started, what started and the token
     * whose debug session's end stops it.
     */
    const runHead = async (folder: vscode.WorkspaceFolder, application: Application, forHost: Host, configuration: Configuration,
        device: string, debug: boolean) => {
        const place = runPlace(application.directory, forHost, device);
        const replaced = going.get(place);
        replaced?.stop();
        await replaced?.ended;
        return withTool(tool, folder.uri.fsPath, `${application.name} did not start`, (client) =>
            new Promise<{ launched: LaunchedApplication; token: string } | undefined>((resolve, reject) => {
                const stopping = new AbortController();
                const token = randomUUID();
                let started = false;
                let end = (): void => {};
                const run = { stop: () => stopping.abort(), ended: new Promise<void>((ended) => { end = ended; }) };
                going.set(place, run);
                const finished = (): void => {
                    runs.delete(token);
                    if (going.get(place) === run) {
                        going.delete(place);
                    }
                    end();
                };
                runOutput.clear();
                runOutput.show(true);
                void vscode.window.withProgress(
                    { location: vscode.ProgressLocation.Notification, title: `StateUI: ${application.name} (${describe(forHost).label}, ${configuration})`, cancellable: true },
                    (progress, cancel) => {
                        cancel.onCancellationRequested(() => stopping.abort());
                        return client.run("application/run", {
                            build: { projectUri: pathToFileUri(application.directory), host: forHost, configuration, device }, debugger: debug,
                        }, {
                            signal: stopping.signal,
                            onEvent: ({ event }) => {
                                if (event.kind === "progress") {
                                    progress.report({ message: event.message ?? event.stage });
                                } else if (event.kind === "output") {
                                    runOutput.append(event.encoding === "utf8" ? event.data : Buffer.from(event.data, "base64").toString("utf8"));
                                } else if (event.kind === "started") {
                                    started = true;
                                    runs.set(token, () => stopping.abort());
                                    const { url, held, build } = event.application;
                                    const where = url ? `served at ${url}` : `running on ${build.destination?.name ?? "its device"}`;
                                    progress.report({ message: `${where}${held ? ", waiting for the debugger" : ""} - Cancel stops it` });
                                    resolve({ launched: event.application, token });
                                }
                            },
                        }).then(() => {
                            finished();
                            if (!started) {
                                resolve(undefined);
                            }
                        }, (error: unknown) => {
                            finished();
                            if (!started) {
                                reject(error);
                            } else if (!(error instanceof ToolRequestError && error.state === "cancelled")) {
                                sayProblem(`${application.name} stopped`, error);
                            }
                        });
                    });
            }));
    };

    const provider = new StateUIDebugConfigurationProvider({
        host,
        build: async (folder, application, forHost, configuration) => {
            const built = await withTool(tool, folder.uri.fsPath, `${application.name} was not built`, async (client) => {
                const made = await runOperation(client, "application/build", { projectUri: pathToFileUri(application.directory), host: forHost, configuration },
                    `StateUI: building ${application.name}`, buildOutput);
                // A GTK head is installed for the user, its desktop entry naming the program just built.
                if (forHost === "gtk") {
                    await client.run("application/install", { artifactUri: made.folderUri });
                }
                return made;
            });
            return built && pathOf(built.programUri);
        },
        place,
        device: androidDevice,
        uiKitDevice,
        guest,
        runHead,
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
            const remembered = candidates.find((each) => each === chosen());
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

    // A checkout's own commands show in a checkout alone; New Application in a workspace.
    const updateFolderContexts = (): void => {
        const folders = (vscode.workspace.workspaceFolders ?? []).map((folder) => folder.uri.fsPath);
        void vscode.commands.executeCommand("setContext", "stateui.hasCheckout", folders.some(isCheckout));
        void vscode.commands.executeCommand("setContext", "stateui.hasWorkspace", found.some((each) => each.workspace !== undefined));
    };

    // The applications read again, a moment after what makes one comes, goes or changes - never for what a build
    // writes in .build, which SwiftPM would make the reading wait behind.
    let pending: NodeJS.Timeout | undefined;
    const rediscover = (): void => {
        clearTimeout(pending);
        pending = setTimeout(async () => {
            const before = roots().join("\n");
            await discover();
            refresh();
            updateFolderContexts();
            testSuites.changed();
            if (roots().join("\n") !== before) {
                await workAs(host());
            }
        }, 500);
    };
    const watched = (uri: vscode.Uri): void => {
        if (!uri.fsPath.split(/[\\/]/).some((part) => part === ".build" || part === "node_modules")) {
            rediscover();
        }
    };
    for (const pattern of ["**/stateui-workspace.json", "**/stateui.json", "**/Package.swift", "**/Platforms/*/main.swift", "**/Platforms/Android/build.gradle.kts"]) {
        const watcher = vscode.workspace.createFileSystemWatcher(pattern);
        context.subscriptions.push(watcher, watcher.onDidCreate(watched), watcher.onDidDelete(watched), watcher.onDidChange(watched));
    }
    // What was chosen, read again as `stateui settings` or another window changes it; the window then works as the
    // host chosen.
    const rechoose = async (): Promise<void> => {
        const before = host();
        await readChoices();
        refresh();
        testSuites.changed();
        if (host() !== before) {
            await workAs(host());
        }
    };
    for (const pattern of ["**/.stateui/workspace-settings.json", "**/.stateui/settings.json"]) {
        const watcher = vscode.workspace.createFileSystemWatcher(pattern);
        const changed = (): void => void rechoose();
        context.subscriptions.push(watcher, watcher.onDidCreate(changed), watcher.onDidDelete(changed), watcher.onDidChange(changed));
    }
    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(rediscover), { dispose: () => clearTimeout(pending) });

    await discover();
    updateFolderContexts();
    refresh();
    // A window opening on a package another window indexes as another host works as that host.
    try {
        await applyEditorMode(host(), roots(), describeIndex, acquireIndex);
    } catch (error) {
        if (!(error instanceof IndexConflictError)) {
            throw error;
        }
        const held = error.conflict.host;
        if (held && offered().some((each) => each.id === held)) {
            await chooseHost(held);
            refresh();
            testSuites.changed();
            await workAs(held);
            void vscode.window.showInformationMessage(`StateUI: ${error.message}, so this window works as ${describe(held).label} too.`);
        } else {
            void vscode.window.showWarningMessage(`StateUI: ${error.message}, so this window's index stays as it was.`);
        }
    }

    const selectUIKitDevice = async (wanted: string): Promise<string | undefined> => {
        const name = await chooseListedUIKitDevice(devices, wanted, listUIKit);
        refresh();
        return name;
    };

    const selectAndroidDevice = async (wanted: string): Promise<string | undefined> => {
        const name = await chooseListedDevice(devices, wanted, listAndroid);
        refresh();
        return name;
    };

    const selectBrowser = async (wanted: string): Promise<string | undefined> => {
        const name = await chooseListedBrowser(devices, wanted, listBrowsers);
        refresh();
        return name;
    };

    return {
        host, selectHost, application: () => chosen()?.name, selectApplication, selectUIKitDevice, selectAndroidDevice,
        selectBrowser, applications,
    };
}

export function deactivate(): void {}
