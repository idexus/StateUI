// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The browsers a Web head runs in: what .scripts/Web/browsers.sh lists - the
// browsers installed on this machine - and the one chosen for the workspace.

import { execFile } from "child_process";
import * as path from "path";
import * as vscode from "vscode";

/** A browser installed on this machine. */
export interface Browser {
    /** What the system knows it by: a bundle id on macOS, a desktop entry's file on Linux. */
    readonly id: string;
    readonly name: string;

    /** The program a debugger starts it as. */
    readonly executable: string;

    /** Whether the system opens a web address in it. */
    readonly isDefault: boolean;
}

/** The browser chosen for a workspace. */
export type ChosenBrowser = Pick<Browser, "id" | "name">;

const browserKey = "stateui.browser";

/** One of the scripts in `root`/.scripts/Web, which build, serve and open the Web host's page. */
export function webScript(root: string, script: "browsers.sh" | "run-app.sh" | "deploy.sh"): string {
    return path.join(root, ".scripts", "Web", script);
}

/** What `browsers.sh list` printed: one browser a line - id, name, executable and "default" - tab-separated. */
export function parseBrowsers(output: string): Browser[] {
    return output.split(/\r?\n/).flatMap((line): Browser[] => {
        const [id, name, executable, isDefault] = line.trim().split("\t");
        return id ? [{ id, name: name || id, executable: executable ?? "", isDefault: isDefault === "default" }] : [];
    });
}

/**
 * Whether `browser` is one of Chromium's - Chrome, Edge, Brave, Vivaldi, Opera, Arc, Chromium itself - whose page
 * VS Code's own JavaScript debugger starts and follows.
 */
export function isChromium(browser: Pick<Browser, "id">): boolean {
    return /chrome|chromium|edge|brave|vivaldi|opera|thebrowser/i.test(browser.id);
}

/** The browser chosen for the workspace, where one is. */
export function chosenBrowser(state: vscode.Memento): ChosenBrowser | undefined {
    return state.get<ChosenBrowser>(browserKey);
}

/** The browser a launch runs in: the one chosen, while it is installed, else asked for - or nothing, where none is picked. */
export async function browserToRunOn(root: string, state: vscode.Memento): Promise<Browser | undefined> {
    const listed = await listBrowsers(root);
    const chosen = chosenBrowser(state);
    const installed = listed?.find((each) => each.id === chosen?.id);
    return installed ?? (listed ? askForBrowser(root, state, listed) : undefined);
}

/** Asks for a browser among those `browsers.sh list` lists, the system's own first, remembers it and answers it. */
export async function askForBrowser(root: string, state: vscode.Memento, listed?: Browser[]): Promise<Browser | undefined> {
    listed ??= await listBrowsers(root);
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage("StateUI: no browser is installed on this machine - none opens a web address and a web page.");
        return undefined;
    }

    const current = chosenBrowser(state)?.id;
    const ordered = [...listed].sort((a, b) => Number(b.isDefault) - Number(a.isDefault));
    const picked = await vscode.window.showQuickPick(
        ordered.map((browser) => ({
            label: `$(globe) ${browser.name}`,
            description: [browser.isDefault ? "the system's own" : "", browser.id === current ? "current" : ""].filter(Boolean).join(" · "),
            detail: isChromium(browser) ? "StateUI: Debug follows the page in VS Code's debugger" : undefined,
            browser,
        })),
        { placeHolder: "Which browser do StateUI: Debug and StateUI: Release open the application in?", ignoreFocusOut: true });
    if (!picked) {
        return undefined;
    }

    await state.update(browserKey, { id: picked.browser.id, name: picked.browser.name } satisfies ChosenBrowser);
    return picked.browser;
}

/** What `browsers.sh list` lists, or nothing, said, where it failed. */
async function listBrowsers(root: string): Promise<Browser[] | undefined> {
    const { failed, stdout, output } = await new Promise<{ failed: boolean; stdout: string; output: string }>((resolve) =>
        execFile("bash", [webScript(root, "browsers.sh"), "list"], { cwd: root },
            (error, stdout, stderr) => resolve({ failed: error !== null, stdout, output: `${stdout}${stderr}` })));
    if (failed) {
        void vscode.window.showErrorMessage(`StateUI: the browsers could not be listed - ${output.trim()}`);
        return undefined;
    }
    return parseBrowsers(stdout);
}
