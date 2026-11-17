// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The guests of this Mac a GTK or WinUI head is built and run in - Parallels virtual machines of the host's system, as
// the stateui tool lists them (`devices/list`) - and the one chosen for each host, by its name. The tool starts or
// resumes the guest when a build needs it.

import * as vscode from "vscode";
import { DeviceStore } from "./choices";
import { describe, Host } from "./hosts";
import { Architecture, Destination } from "./Tooling/protocol";

/**
 * A guest as the tool lists it: its name, its system, its state - running, suspended, stopped - whether a debugger
 * reaches an application run in it, and the architectures a head is built for there, its own first.
 */
export interface Guest {
    readonly name: string;
    readonly system: string;
    readonly state: string;
    readonly debugger: boolean;
    readonly architectures: readonly Architecture[];
}

/** The guests of `host`'s system as the tool lists them, or nothing, said, where it could not. */
export type GuestLister = (host: Host) => Promise<Guest[] | undefined>;

/** A destination the tool listed, as a guest stands in the editor. */
export function guestOf(destination: Destination): Guest {
    return {
        name: destination.name, system: destination.version, state: destination.connection ?? (destination.booted ? "running" : "stopped"),
        debugger: destination.debugger, architectures: [...(destination.architecture ? [destination.architecture] : []), ...destination.emulated],
    };
}

/** The system whose guests build `host`'s heads. */
function systemOf(host: Host): string {
    return host === "winui" ? "Windows" : "Linux";
}

/** The guest a launch of `host` is built and run in: the one chosen, while it is listed, else asked for. */
export async function guestToRunIn(store: DeviceStore, host: Host, list: GuestLister): Promise<Guest | undefined> {
    const listed = await list(host);
    const chosen = listed?.find((each) => each.name === store.device(host));
    return chosen ?? (listed ? askForGuest(store, host, list, listed) : undefined);
}

/** Asks for a guest of `host`'s system among those the tool lists, remembers it, and answers it. */
export async function askForGuest(store: DeviceStore, host: Host, list: GuestLister, listed?: Guest[]): Promise<Guest | undefined> {
    listed ??= await list(host);
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            `StateUI: no ${systemOf(host)} guest of Parallels Desktop stands on this Mac - make one, then \`stateui doctor --host ${host} --device <guest>\` says what it needs.`);
        return undefined;
    }

    const current = store.device(host);
    type Item = vscode.QuickPickItem & { guest: Guest };
    const items = listed.map((guest): Item => ({
        label: `$(vm) ${guest.name}`,
        description: [guest.system, guest.state === "running" ? "running" : `${guest.state} - started when it builds`,
            ...(guest.name === current ? ["current"] : [])].join(" · "),
        guest,
    }));
    const guest = (await vscode.window.showQuickPick(items, {
        placeHolder: `Which ${systemOf(host)} guest do StateUI: Debug, StateUI: Release and StateUI: Package build ${describe(host).label} heads in?`,
        ignoreFocusOut: true,
    }))?.guest;
    if (!guest) {
        return undefined;
    }
    await store.choose(host, guest.name);
    return guest;
}
