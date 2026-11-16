// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The browsers a Web head runs in, as the stateui tool lists them (`devices/list`) - the browsers installed on this
// machine - and the one chosen, by its name.

import * as vscode from "vscode";
import { DeviceStore } from "./choices";
import { Destination } from "./Tooling/protocol";

/** A browser installed on this machine. */
export interface Browser {
    /** What the system knows it by: a bundle id on macOS, a desktop entry's file on Linux. */
    readonly id: string;
    readonly name: string;

    /** The program a debugger starts it as, where the tool found it. */
    readonly program?: string;

    /** Whether the system opens a web address in it. */
    readonly isDefault: boolean;
}

/** The browsers as the tool lists them, or nothing, said, where it could not. */
export type BrowserLister = () => Promise<Browser[] | undefined>;


/** A destination the tool listed, as a browser stands in the editor. */
export function browserOf(destination: Destination): Browser {
    return {
        id: destination.id, name: destination.name, isDefault: destination.booted,
        program: destination.programUri && vscode.Uri.parse(destination.programUri).fsPath,
    };
}

/**
 * Whether `browser` is one of Chromium's - Chrome, Edge, Brave, Vivaldi, Opera, Arc, Chromium itself - whose page
 * VS Code's own JavaScript debugger starts and follows.
 */
export function isChromium(browser: Pick<Browser, "id">): boolean {
    return /chrome|chromium|edge|brave|vivaldi|opera|thebrowser/i.test(browser.id);
}

/** The browser among `listed` the one chosen - its name, or its id - names; nothing where it is installed no more. */
export function browserAmong(listed: readonly Browser[], chosen: string | undefined): Browser | undefined {
    return chosen === undefined ? undefined : listed.find((each) => each.id === chosen) ?? listed.find((each) => each.name === chosen);
}

/** The browser a launch runs in: the one chosen, while it is installed, else asked for - or nothing, where none is picked. */
export async function browserToRunOn(store: DeviceStore, list: BrowserLister): Promise<Browser | undefined> {
    const listed = await list();
    const installed = listed && browserAmong(listed, store.device("web"));
    return installed ?? (listed ? askForBrowser(store, list, listed) : undefined);
}

/** Asks for a browser among those the tool lists, the system's own first, remembers it and answers it. */
export async function askForBrowser(store: DeviceStore, list: BrowserLister, listed?: Browser[]): Promise<Browser | undefined> {
    listed ??= await list();
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage("StateUI: no browser is installed on this machine - none opens a web address and a web page.");
        return undefined;
    }

    const current = browserAmong(listed, store.device("web"))?.id;
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

    await store.choose("web", picked.browser.name);
    return picked.browser;
}

/** Chooses the browser `wanted` names - its id or its name - as the tool lists it; answers its name, or nothing. */
export async function chooseListedBrowser(store: DeviceStore, wanted: string, list: BrowserLister): Promise<string | undefined> {
    const found = (await list())?.find((each) => each.id === wanted || each.name === wanted);
    if (found) {
        await store.choose("web", found.name);
    }
    return found?.name;
}
