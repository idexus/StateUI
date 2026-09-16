// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension: a host and an application chosen once, the editor working as
// that host, one Debug and one Release that run the application on it, and
// the suites run as it.

import * as vscode from "vscode";
import { Application, findApplications } from "./applications";
import { configurations, StateUIDebugConfigurationProvider } from "./debug";
import { applyEditorMode, cleanIndex, variablesInSettings } from "./editorMode";
import { describe, Host, hosts } from "./hosts";
import { findSuites, runSuites } from "./tests";

/** What the extension answers to another extension - and to its own tests. */
export interface StateUIApi {
    host(): Host;
    selectHost(host: Host): Promise<void>;
    application(): string | undefined;
    selectApplication(name: string): Promise<void>;
}

const hostKey = "stateui.host";
const applicationKey = "stateui.application";

export async function activate(context: vscode.ExtensionContext): Promise<StateUIApi> {
    const state = context.workspaceState;

    const applications = (): Application[] =>
        (vscode.workspace.workspaceFolders ?? []).flatMap((folder) => findApplications(folder.uri.fsPath));

    /** The applications that have a head for `host`. */
    const runnable = (host: Host): Application[] =>
        applications().filter((each) => (host === "appkit" ? each.hasAppKitHead : each.mauiProject !== undefined));

    // The packages whose manifest reads a host's variable: the applications.
    const roots = (): string[] => applications().map((each) => each.directory);

    // AppKit where there is a head to run on this machine, MAUI otherwise.
    const host = (): Host =>
        state.get<Host>(hostKey)
        ?? (process.platform === "darwin" && applications().some((each) => each.hasAppKitHead) ? "appkit" : "maui");

    /** The chosen application, where it still has a head for the chosen host. */
    const chosen = (): Application | undefined =>
        runnable(host()).find((each) => each.name === state.get<string>(applicationKey));

    const hostItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    hostItem.command = "stateui.selectHost";
    const applicationItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 49);
    applicationItem.command = "stateui.selectApplication";
    context.subscriptions.push(hostItem, applicationItem);

    const refresh = (): void => {
        const described = describe(host());
        hostItem.text = `$(server-environment) StateUI: ${described.label}`;
        hostItem.tooltip = `StateUI: Debug, StateUI: Release, StateUI: Run Tests and the editor work as ${described.label} - ${described.detail}. Click to change.`;
        hostItem.show();

        const candidates = runnable(host());
        const application = chosen() ?? (candidates.length === 1 ? candidates[0] : undefined);
        applicationItem.text = `$(window) ${application?.name ?? "Select Application"}`;
        applicationItem.tooltip = `The application StateUI: Debug and StateUI: Release run on ${described.label}. Click to change.`;
        candidates.length > 0 ? applicationItem.show() : applicationItem.hide();
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
            const head = forHost === "appkit" ? "an AppKit head (Platforms/AppKit/main.swift)" : "a MAUI head (Platforms/Maui/*.csproj)";
            void vscode.window.showErrorMessage(`StateUI: no application here has ${head}.`);
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

    context.subscriptions.push(
        vscode.commands.registerCommand("stateui.selectHost", async () => {
            const picked = await vscode.window.showQuickPick(
                hosts.map((each) => ({
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

            const failed = await runSuites(folder, picked.map((each) => each.suite));
            if (failed.length === 0) {
                void vscode.window.showInformationMessage(`StateUI: all ${picked.length} suites passed on ${describe(host()).label}.`);
            } else {
                void vscode.window.showErrorMessage(
                    `StateUI: ${failed.length} of ${picked.length} suites failed on ${describe(host()).label}: ${failed.join(", ")}. Their output is in the terminal.`);
            }
        }),
        vscode.commands.registerCommand("stateui.cleanIndex", async () => {
            await cleanIndex(roots());
            void vscode.window.setStatusBarMessage("StateUI: the index is being built again", 4000);
        }));

    const provider = new StateUIDebugConfigurationProvider({
        host,
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

    refresh();
    await applyEditorMode(host(), roots());

    return { host, selectHost, application: () => state.get<string>(applicationKey), selectApplication };
}

export function deactivate(): void {}
