// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The machines a head is built and run on where this one does not run its host itself - the guests of this Mac of the
// host's system (Parallels virtual machines), and the machines paired with the project that run the host as their own
// programs - as the stateui tool lists them (`devices/list`), and the one chosen for each host, by its name. The tool
// starts or resumes a guest when a build needs it, and reaches a machine paired through its service.

import * as vscode from "vscode";
import { DeviceStore } from "./choices";
import { describe, Host } from "./hosts";
import { Architecture, Destination, Place } from "./Tooling/protocol";

/**
 * A machine as the tool lists it: its name, whether it is a guest of this Mac or a machine paired, its system, its
 * state - a guest's running, suspended or stopped, a machine paired's address - whether a debugger reaches an
 * application run there, and the architectures a head is built for there, its own first.
 */
export interface Machine {
    readonly name: string;
    readonly kind: "guest" | "remote";
    readonly system: string;
    readonly state: string;
    readonly debugger: boolean;
    readonly architectures: readonly Architecture[];
}

/** The machines a head of `host` is worked on, as the tool lists them, or nothing, said, where it could not. */
export type MachineLister = (host: Host) => Promise<Machine[] | undefined>;

/** A destination the tool listed as a machine stands in the editor; nothing for one of another kind. */
export function machineOf(destination: Destination): Machine | undefined {
    if (destination.kind !== "guest" && destination.kind !== "remote") {
        return undefined;
    }
    return {
        name: destination.name, kind: destination.kind, system: destination.version,
        state: destination.connection ?? (destination.booted ? "running" : "stopped"), debugger: destination.debugger,
        architectures: [...(destination.architecture ? [destination.architecture] : []), ...destination.emulated],
    };
}

/** The system whose guests build `host`'s heads. */
function systemOf(host: Host): string {
    return host === "winui" ? "Windows" : "Linux";
}

/** What a machine says beside its name in a list. */
function described(machine: Machine, current: string | undefined): string {
    const state = machine.kind === "remote" ? `paired at ${machine.state}`
        : machine.state === "running" ? "running" : `${machine.state} - started when it builds`;
    return [machine.system, state, ...(machine.name === current ? ["current"] : [])].filter((each) => each).join(" · ");
}

/** The machine a launch of `host` is built and run on: the one chosen, while it is listed, else asked for. */
export async function machineToRunOn(store: DeviceStore, host: Host, place: Place, list: MachineLister): Promise<Machine | undefined> {
    const listed = await list(host);
    const chosen = listed?.find((each) => each.name === store.device(host));
    return chosen ?? (listed ? askForMachine(store, host, place, list, listed) : undefined);
}

/** Asks for a machine among those the tool lists for `host`, worked at `place`, remembers it, and answers it. */
export async function askForMachine(
    store: DeviceStore, host: Host, place: Place, list: MachineLister, listed?: Machine[],
): Promise<Machine | undefined> {
    listed ??= await list(host);
    if (!listed) {
        return undefined;
    }
    const label = describe(host).label;
    if (listed.length === 0) {
        const pair = "`stateui remote add <name> <address:port> --code <code>` pairs the project with a machine whose service runs them";
        void vscode.window.showErrorMessage(place === "guest"
            ? `StateUI: no ${systemOf(host)} guest of Parallels Desktop stands on this Mac, nor a machine paired runs ${label} heads - make a guest (\`stateui doctor --host ${host} --device <guest>\` says what it needs), or ${pair}.`
            : `StateUI: no machine paired with this project runs ${label} heads - ${pair}.`);
        return undefined;
    }

    const current = store.device(host);
    type Item = vscode.QuickPickItem & { machine: Machine };
    const items = listed.map((machine): Item => ({
        label: `$(${machine.kind === "guest" ? "vm" : "remote"}) ${machine.name}`, description: described(machine, current), machine,
    }));
    const machine = (await vscode.window.showQuickPick(items, {
        placeHolder: `Which machine do StateUI: Debug, StateUI: Release and StateUI: Package build ${label} heads on?`,
        ignoreFocusOut: true,
    }))?.machine;
    if (!machine) {
        return undefined;
    }
    await store.choose(host, machine.name);
    return machine;
}
