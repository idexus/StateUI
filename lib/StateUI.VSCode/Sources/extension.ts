// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension: a host chosen in the status bar, the editor working as that
// host, and one Debug and one Release that run it.

import * as vscode from "vscode";
import { findApplications } from "./applications";
import { configurations, StateUIDebugConfigurationProvider } from "./debug";
import { applyEditorMode, cleanIndex, variablesInSettings } from "./editorMode";
import { describe, Host, hosts } from "./hosts";

/** What the extension answers to another extension - and to its own tests. */
export interface StateUIApi {
    host(): Host;
    selectHost(host: Host): Promise<void>;
}

const hostKey = "stateui.host";

export async function activate(context: vscode.ExtensionContext): Promise<StateUIApi> {
    const state = context.workspaceState;

    const applications = () => (vscode.workspace.workspaceFolders ?? []).flatMap((folder) => findApplications(folder.uri.fsPath));

    // The packages whose manifest reads a host's variable: the applications.
    const roots = (): string[] => applications().map((each) => each.directory);

    // AppKit where there is a head to run on this machine, MAUI otherwise.
    const host = (): Host =>
        state.get<Host>(hostKey)
        ?? (process.platform === "darwin" && applications().some((each) => each.hasAppKitHead) ? "appkit" : "maui");

    const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    item.command = "stateui.selectHost";
    context.subscriptions.push(item);

    const refresh = (): void => {
        const chosen = describe(host());
        item.text = `$(server-environment) StateUI: ${chosen.label}`;
        item.tooltip = `StateUI: Debug, StateUI: Release and the editor work as ${chosen.label} - ${chosen.detail}. Click to change.`;
        item.show();
    };

    const selectHost = async (chosen: Host): Promise<void> => {
        await state.update(hostKey, chosen);
        refresh();

        if (await applyEditorMode(chosen, roots())) {
            void vscode.window.setStatusBarMessage(`StateUI: the editor works as ${describe(chosen).label}`, 4000);
        }
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
                { placeHolder: "Which host do StateUI: Debug and the editor work as?" });
            if (picked) {
                await selectHost(picked.id);
            }
        }),
        vscode.commands.registerCommand("stateui.cleanIndex", async () => {
            await cleanIndex(roots());
            void vscode.window.setStatusBarMessage("StateUI: the index is being built again", 4000);
        }));

    const provider = new StateUIDebugConfigurationProvider({ host, state });
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

    return { host, selectHost };
}

export function deactivate(): void {}
