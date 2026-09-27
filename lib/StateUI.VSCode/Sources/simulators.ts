// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The iOS simulators a UIKit head runs on: what `xcrun simctl list` lists on the runtimes the heads install on, and
// the one chosen for the workspace. .scripts/UIKit/run-app.sh boots the one it is handed.

import { execFile } from "child_process";
import * as path from "path";
import * as vscode from "vscode";

/** A simulator a UIKit head can run on. */
export interface Simulator {
    readonly udid: string;
    readonly name: string;

    /** Its runtime, as its version: `27.0`. */
    readonly runtime: string;

    readonly booted: boolean;
}

/** The simulator chosen for a workspace. */
export type ChosenSimulator = Pick<Simulator, "udid" | "name">;

const simulatorKey = "stateui.simulator";

/** The oldest iOS a head installs on - the deployment target .scripts/UIKit/tools.sh builds for. */
export const oldestRuntime = 26;

/** One of the scripts in `root`/.scripts/UIKit, which build and run the UIKit host. */
export function uiKitScript(root: string, script: "run-app.sh" | "test-uikit.sh"): string {
    return path.join(root, ".scripts", "UIKit", script);
}

/**
 * What `xcrun simctl list devices available -j` printed as `json`: the iPhones and iPads of the iOS runtimes a head
 * installs on, the newest runtime first, each runtime's in the order listed.
 */
export function parseSimulators(json: string): Simulator[] {
    let listed: { devices?: Record<string, { udid: string; name: string; state: string }[]> };
    try {
        listed = JSON.parse(json);
    } catch {
        return [];
    }

    const runtimes = Object.entries(listed.devices ?? {}).flatMap(([runtime, devices]) => {
        const version = runtime.match(/\.iOS-(\d+)-(\d+)$/);
        return version && Number(version[1]) >= oldestRuntime ? [{ version: `${version[1]}.${version[2]}`, devices }] : [];
    });
    const newestFirst = runtimes.sort((a, b) =>
        b.version.localeCompare(a.version, undefined, { numeric: true }));
    return newestFirst.flatMap(({ version, devices }) => devices.map((device) => ({
        udid: device.udid, name: device.name, runtime: version, booted: device.state === "Booted",
    })));
}

/** The simulator chosen for the workspace, where one is. */
export function chosenSimulator(state: vscode.Memento): ChosenSimulator | undefined {
    return state.get<ChosenSimulator>(simulatorKey);
}

/** Chooses `simulator` for the workspace. */
export async function chooseSimulator(state: vscode.Memento, simulator: ChosenSimulator): Promise<void> {
    await state.update(simulatorKey, { udid: simulator.udid, name: simulator.name } satisfies ChosenSimulator);
}

/**
 * The UDID of the simulator a launch or a suite runs on: the one chosen, while it is still available, else asked
 * for - or nothing, where none is picked.
 */
export async function simulatorToRunOn(state: vscode.Memento): Promise<string | undefined> {
    const listed = await listSimulators();
    const chosen = chosenSimulator(state);

    if (chosen && listed?.some((each) => each.udid === chosen.udid)) {
        return chosen.udid;
    }
    return listed ? askForSimulator(state, listed) : undefined;
}

/** Asks for a simulator among those available, remembers it, and answers its UDID. */
export async function askForSimulator(state: vscode.Memento, listed?: Simulator[]): Promise<string | undefined> {
    listed ??= await listSimulators();
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            `StateUI: no simulator of iOS ${oldestRuntime} or later is available - add one in Xcode's Devices and Simulators.`);
        return undefined;
    }

    const current = chosenSimulator(state)?.udid;
    type Item = vscode.QuickPickItem & { simulator?: Simulator };
    const items: Item[] = listed.map((simulator): Item => ({
        label: `$(${simulator.name.startsWith("iPad") ? "device-tablet" : "device-mobile"}) ${simulator.name}`,
        description: [`iOS ${simulator.runtime}`, simulator.booted ? "booted" : undefined, simulator.udid === current ? "current" : undefined]
            .filter(Boolean).join(" · "),
        simulator,
    }));

    const simulator = (await vscode.window.showQuickPick(items,
        { placeHolder: "Which simulator do StateUI: Debug, StateUI: Release and StateUI: Run Tests run on?", ignoreFocusOut: true }))?.simulator;
    if (!simulator) {
        return undefined;
    }

    await chooseSimulator(state, simulator);
    return simulator.udid;
}

/** The simulators available, or nothing, said, where simctl failed. */
async function listSimulators(): Promise<Simulator[] | undefined> {
    const { failed, stdout, output } = await new Promise<{ failed: boolean; stdout: string; output: string }>((resolve) =>
        execFile("xcrun", ["simctl", "list", "devices", "available", "-j"], { maxBuffer: 16 * 1024 * 1024 },
            (error, out, err) => resolve({ failed: error !== null, stdout: out, output: `${out}${err}` })));
    if (failed) {
        void vscode.window.showErrorMessage(`StateUI: the simulators could not be listed - ${output.trim()}`);
        return undefined;
    }
    return parseSimulators(stdout);
}
