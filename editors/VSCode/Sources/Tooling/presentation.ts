// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The stateui tool in the editor: its connections, what the tool says on standard error in the StateUI Tool output,
// an operation followed in a cancellable notification, and why the tool did not answer - a missing one with the way
// to the setting that names it.

import * as vscode from "vscode";
import { incompatibleAPICode, ToolingClient, ToolRequestError } from "./client";
import { ToolingClients } from "./clients";
import { locateTool, ToolNotFound } from "./locate";
import { apiVersions, MutationName, ParamsOf, ResultOf } from "./protocol";

/** The extension's connections, shut down with it, and the output the tool's own words go to. */
export function toolingClients(context: vscode.ExtensionContext): ToolingClients {
    const log = vscode.window.createOutputChannel("StateUI Tool");
    const clients = new ToolingClients(async (folder) => ToolingClient.start({
        executable: locateTool(vscode.workspace.getConfiguration("stateui").get<string>("cliPath")),
        folder, clientVersion: context.extension.packageJSON.version, log: (line) => log.appendLine(line),
    }));
    context.subscriptions.push(log, { dispose: () => void clients.dispose() });
    return clients;
}

/** Why the tool gave no answer, as the editor says it. */
export function problemOf(error: unknown): string {
    if (error instanceof ToolRequestError && error.code === incompatibleAPICode) {
        const spoken = apiVersions.map((each) => `${each.major}.${each.minMinor}`).join(", ");
        return `${error.message} This extension speaks API ${spoken}: install the stateui of the extension's release.`;
    }
    return error instanceof Error ? error.message : String(error);
}

/**
 * `body` given the connection of `folder`; where it fails, `failure` said with why, and undefined - nothing said of
 * an operation the user cancelled.
 */
export async function withTool<T>(clients: ToolingClients, folder: string, failure: string,
    body: (client: ToolingClient) => PromiseLike<T>): Promise<T | undefined> {
    try {
        return await body(await clients.for(folder));
    } catch (error) {
        if (!(error instanceof ToolRequestError && error.state === "cancelled")) {
            sayProblem(failure, error);
        }
        return undefined;
    }
}

/** Says `failure` with why the tool gave no answer - a missing tool with the way to the setting that names it. */
export function sayProblem(failure: string, error: unknown): void {
    const settings = error instanceof ToolNotFound ? ["Open Settings"] : [];
    void vscode.window.showErrorMessage(`StateUI: ${failure} - ${problemOf(error)}`, ...settings).then(async (answer) => {
        if (answer) {
            await vscode.commands.executeCommand("workbench.action.openSettings", "stateui.cliPath");
        }
    });
}

/** Operation `method` followed in a notification titled `title` that cancels it, its output written to `output`. */
export function runOperation<K extends MutationName>(client: ToolingClient, method: K, params: ParamsOf<K>, title: string,
    output: vscode.OutputChannel): Thenable<ResultOf<K>> {
    return vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title, cancellable: true },
        (progress, token) => {
            const cancelled = new AbortController();
            token.onCancellationRequested(() => cancelled.abort());
            return client.run(method, params, {
                signal: cancelled.signal,
                onEvent: ({ event }) => {
                    if (event.kind === "progress") {
                        progress.report({ message: event.message ?? event.stage });
                    } else if (event.kind === "output") {
                        output.append(event.encoding === "utf8" ? event.data : Buffer.from(event.data, "base64").toString("utf8"));
                    } else if (event.kind === "outputGap") {
                        output.appendLine(`[${event.stream} from ${event.fromCursor} to ${event.toCursor} was not kept]`);
                    }
                },
            });
        });
}
