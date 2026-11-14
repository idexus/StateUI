// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a UIKit head runs: the iPhones and iPads paired with this Mac, and the iOS simulators, as the stateui tool
// lists them (`devices/list`), and the one chosen for the workspace. The tool boots a simulator, and signs for a
// device.

import * as path from "path";
import * as vscode from "vscode";
import { Destination } from "./Tooling/protocol";
import { appleFloor } from "./toolchain";

/** An iPhone or an iPad a UIKit head can run on, a real one or a simulator. */
export interface UIKitDevice {
    /** A device's identifier, as devicectl gives it; a simulator's UDID. */
    readonly id: string;
    readonly name: string;
    readonly kind: "device" | "simulator";

    /** Its iOS, as its version: `27.0`. */
    readonly os: string;

    /** How it is reached - `USB`, `Wi-Fi` - or, for a simulator, whether it is booted. */
    readonly state: string;
}

/** The device chosen for a workspace. */
export type ChosenUIKitDevice = Pick<UIKitDevice, "id" | "name">;

const chosenKey = "stateui.uiKitDevice";

/** The UIKit script in `root`/.scripts/UIKit that still records the host's marks. */
export function uiKitScript(root: string, script: "test-uikit.sh"): string {
    return path.join(root, ".scripts", "UIKit", script);
}

/** The devices paired and the simulators available as the tool lists them, or nothing, said, where it could not. */
export type UIKitLister = () => Promise<UIKitDevice[] | undefined>;

/** A destination the tool listed, as a UIKit device stands in the editor. */
export function uiKitDeviceOf(destination: Destination): UIKitDevice {
    return {
        id: destination.id, name: destination.name, kind: destination.kind, os: destination.version,
        state: destination.kind === "device" ? destination.connection ?? "" : destination.booted ? "booted" : "",
    };
}

/** The device chosen for the workspace, where one is. */
export function chosenUIKitDevice(state: vscode.Memento): ChosenUIKitDevice | undefined {
    return state.get<ChosenUIKitDevice>(chosenKey);
}

/** Chooses `device` for the workspace. */
export async function chooseUIKitDevice(state: vscode.Memento, device: ChosenUIKitDevice): Promise<void> {
    await state.update(chosenKey, { id: device.id, name: device.name } satisfies ChosenUIKitDevice);
}

/**
 * The device a launch or a suite runs on: the one chosen, while it is still listed, else asked for - or nothing,
 * where none is picked.
 */
export async function uiKitDeviceToRunOn(state: vscode.Memento, list: UIKitLister): Promise<string | undefined> {
    const listed = await list();
    const chosen = chosenUIKitDevice(state);

    if (chosen && listed?.some((each) => each.id === chosen.id)) {
        return chosen.id;
    }
    return listed ? askForUIKitDevice(state, list, listed) : undefined;
}

/**
 * Chooses the device `wanted` names - its id, or its name - as it is listed, so what the status bar says is its
 * name; answers that name, or nothing where none is listed so.
 */
export async function chooseListedUIKitDevice(state: vscode.Memento, wanted: string, list: UIKitLister): Promise<string | undefined> {
    const found = (await list())?.find((each) => each.id === wanted || each.name === wanted);
    if (found) {
        await chooseUIKitDevice(state, found);
    }
    return found?.name;
}

const suitesKey = "stateui.uiKitSuiteSimulator";

/**
 * The simulator a suite runs on - the host's suite runs on none but a simulator: the device chosen where it is one,
 * else the simulator chosen for suites, each while it is listed; nothing where one is to be asked for.
 */
export function simulatorForSuites(
    listed: UIKitDevice[], chosen?: ChosenUIKitDevice, forSuites?: ChosenUIKitDevice,
): string | undefined {
    const simulators = new Set(listed.filter((each) => each.kind === "simulator").map((each) => each.id));
    return [chosen, forSuites].find((each) => each !== undefined && simulators.has(each.id))?.id;
}

/**
 * The simulator a suite runs on (`simulatorForSuites`), else asked for among the simulators alone and remembered for
 * suites: the iPhone or iPad a launch runs on stays as it is.
 */
export async function uiKitSimulatorToTestOn(state: vscode.Memento, list: UIKitLister): Promise<string | undefined> {
    const listed = await list();
    if (!listed) {
        return undefined;
    }
    const found = simulatorForSuites(listed, chosenUIKitDevice(state), state.get<ChosenUIKitDevice>(suitesKey));
    if (found) {
        return found;
    }
    const simulators = listed.filter((each) => each.kind === "simulator");
    if (simulators.length === 0) {
        void vscode.window.showErrorMessage(
            `StateUI: the host's suite runs on a simulator, and none of iOS ${appleFloor} or later is available - add one in Xcode's Devices and Simulators.`);
        return undefined;
    }
    const simulator = (await vscode.window.showQuickPick(simulators.map((each) => entry(each)),
        { placeHolder: "Which simulator do StateUI's suites run on? Launches keep the iPhone or iPad chosen for them.", ignoreFocusOut: true }))?.device;
    if (!simulator) {
        return undefined;
    }
    await state.update(suitesKey, { id: simulator.id, name: simulator.name } satisfies ChosenUIKitDevice);
    return simulator.id;
}

/** How `device` stands in a list to pick from - `current` where it is the one chosen. */
function entry(device: UIKitDevice, current?: string): vscode.QuickPickItem & { device: UIKitDevice } {
    return {
        label: `$(${device.name.startsWith("iPad") ? "device-tablet" : "device-mobile"}) ${device.name}`,
        description: [`iOS ${device.os}`, device.state || undefined, device.id === current ? "current" : undefined]
            .filter(Boolean).join(" · "),
        device,
    };
}

/** Asks for a device among the iPhones and iPads paired and the simulators, remembers it, and answers its id. */
export async function askForUIKitDevice(state: vscode.Memento, list: UIKitLister, listed?: UIKitDevice[]): Promise<string | undefined> {
    listed ??= await list();
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            `StateUI: no iPhone or iPad of iOS ${appleFloor} or later is paired, and no simulator of it is available - connect a device, or add a simulator in Xcode's Devices and Simulators.`);
        return undefined;
    }

    const current = chosenUIKitDevice(state)?.id;
    type Item = vscode.QuickPickItem & { device?: UIKitDevice };
    const devices = listed.filter((each) => each.kind === "device");
    const simulators = listed.filter((each) => each.kind === "simulator");
    const items: Item[] = [
        ...(devices.length > 0 ? [{ label: "Devices", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...devices.map((each) => entry(each, current)),
        ...(simulators.length > 0 ? [{ label: "Simulators", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...simulators.map((each) => entry(each, current)),
    ];

    const device = (await vscode.window.showQuickPick(items,
        { placeHolder: "Which iPhone or iPad do StateUI: Debug, StateUI: Release and StateUI: Run Tests run on?", ignoreFocusOut: true }))?.device;
    if (!device) {
        return undefined;
    }

    await chooseUIKitDevice(state, device);
    return device.id;
}
