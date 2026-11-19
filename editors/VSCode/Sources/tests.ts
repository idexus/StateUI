// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The suites a workspace holds, in the editor's Testing view, run AS THE CHOSEN HOST: the stateui tool finds them
// (`tests/discover`) and runs each (`tests/run`), its output in the run's and its verdict on its item.
// Design: docs/design/tooling/tests.md

import * as vscode from "vscode";
import { Host } from "./hosts";
import { pathToFileUri, ToolRequestError } from "./Tooling/client";
import { ToolingClients } from "./Tooling/clients";
import { problemOf, sayProblem } from "./Tooling/presentation";
import { TestSuiteDescription } from "./Tooling/protocol";

/** What the suites are found and run with. */
export interface TestSuitesContext {
    readonly tool: ToolingClients;
    /** The host the editor works as, none for plain Swift. */
    readonly host: () => Host | undefined;
    /** The device, simulator, emulator or guest a suite of `host` that runs on one runs on - asked for where none is chosen. */
    readonly device: (host: Host) => Promise<string | undefined>;
}

/** One suite as found: the folder it was found in, and the host it was found for. */
interface Found {
    readonly folder: string;
    readonly host?: Host;
    readonly suite: TestSuiteDescription;
}

/** The workspace's suites as a test controller's items, found again when the host or the folders change. */
export class TestSuites implements vscode.Disposable {
    readonly controller = vscode.tests.createTestController("stateui", "StateUI");
    private readonly found = new Map<string, Found>();
    private resolved = false;

    constructor(private readonly context: TestSuitesContext) {
        this.controller.resolveHandler = async (item) => {
            if (!item) {
                await this.discover();
            }
        };
        this.controller.refreshHandler = async () => {
            await this.discover();
        };
        this.controller.createRunProfile("Run", vscode.TestRunProfileKind.Run, async (request, token) => {
            await this.run(request, token);
        }, true);
    }

    /** Finds the suites again where the Testing view has shown them: the host or the folders changed. */
    changed(): void {
        if (this.resolved) {
            void this.discover();
        }
    }

    /** Finds every folder's suites for the chosen host, and makes them the controller's items, in their order. */
    async discover(): Promise<vscode.TestItem[]> {
        this.resolved = true;
        const host = this.context.host();
        const folders = (vscode.workspace.workspaceFolders ?? []).map((each) => each.uri.fsPath);
        const listed = await Promise.all(folders.map(async (folder) => {
            try {
                const client = await this.context.tool.for(folder);
                return (await client.request("tests/discover", host ? { host } : {})).suites.map((suite) => ({ folder, host, suite }));
            } catch (error) {
                sayProblem(`the tests of ${folder} were not found`, error);
                return [];
            }
        }));

        this.found.clear();
        const items = listed.flat().map((each) => {
            const id = `${pathToFileUri(each.folder)}#${each.suite.id}`;
            this.found.set(id, each);
            const item = this.controller.createTestItem(id, each.suite.id);
            item.description = each.suite.detail;
            item.sortText = String(this.found.size).padStart(4, "0");
            return item;
        });
        this.controller.items.replace(items);
        return items;
    }

    /** The suites found, in their order. */
    suites(): { readonly item: vscode.TestItem; readonly suite: TestSuiteDescription }[] {
        const items: vscode.TestItem[] = [];
        this.controller.items.forEach((item) => items.push(item));
        return items.flatMap((item) => {
            const found = this.found.get(item.id);
            return found ? [{ item, suite: found.suite }] : [];
        }).sort((a, b) => (a.item.sortText ?? "").localeCompare(b.item.sortText ?? ""));
    }

    /**
     * Runs the suites `request` names - every one where it names none - one after another, each through the tool,
     * and answers the names of those that failed. A failure does not stop the ones after it: the point of running them
     * all is to see all of them. A device is asked for once, when the first suite that runs on one comes.
     */
    async run(request: vscode.TestRunRequest, token: vscode.CancellationToken): Promise<string[]> {
        const excluded = new Set((request.exclude ?? []).map((each) => each.id));
        const items = (request.include ?? this.suites().map((each) => each.item)).filter((each) => !excluded.has(each.id));
        const run = this.controller.createTestRun(request);
        const failed: string[] = [];
        let device: string | undefined;

        for (const item of items) {
            const found = this.found.get(item.id);
            if (!found || token.isCancellationRequested) {
                run.skipped(item);
                continue;
            }
            const { folder, host, suite } = found;
            if (suite.onDevice && device === undefined && suite.host) {
                device = await this.context.device(suite.host);
            }
            if (suite.onDevice && device === undefined) {
                run.skipped(item);
                continue;
            }

            run.started(item);
            const began = Date.now();
            const stopping = new AbortController();
            const cancelled = token.onCancellationRequested(() => stopping.abort());
            try {
                const client = await this.context.tool.for(folder);
                const result = await client.run("tests/run", {
                    suite: suite.id, folderUri: pathToFileUri(folder), ...(host ? { host } : {}), ...(suite.onDevice ? { device } : {}),
                }, {
                    signal: stopping.signal,
                    onEvent: ({ event }) => {
                        if (event.kind === "output") {
                            const text = event.encoding === "utf8" ? event.data : Buffer.from(event.data, "base64").toString("utf8");
                            run.appendOutput(text.replace(/\r?\n/g, "\r\n"), undefined, item);
                        } else if (event.kind === "progress") {
                            run.appendOutput(`${event.message ?? event.stage}\r\n`, undefined, item);
                        }
                    },
                });
                const phases = result.phases.filter((each) => !each.passed).map((each) => each.name);
                if (phases.length === 0) {
                    run.passed(item, Date.now() - began);
                } else {
                    failed.push(suite.id);
                    run.failed(item, new vscode.TestMessage(`${phases.join(", ")} failed - the output says why`), Date.now() - began);
                }
            } catch (error) {
                if (error instanceof ToolRequestError && error.state === "cancelled") {
                    run.skipped(item);
                } else {
                    failed.push(suite.id);
                    run.errored(item, new vscode.TestMessage(problemOf(error)), Date.now() - began);
                }
            } finally {
                cancelled.dispose();
            }
        }

        run.end();
        return failed;
    }

    dispose(): void {
        this.controller.dispose();
    }
}
