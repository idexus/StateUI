// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Android devices a head runs on, as the stateui tool lists them (`devices/list`), and the one chosen for the
// workspace. An emulator not running is named by its virtual device; the tool boots it when a run or a suite needs it.

import * as vscode from "vscode";
import { Destination } from "./Tooling/protocol";

/** A place an Android head can run: a device attached and ready - a running emulator among them - or a virtual device. */
export type AndroidDevice = AttachedDevice | { readonly kind: "avd"; readonly name: string };

/** A device attached and ready, named by its model - a running emulator by its virtual device. */
export interface AttachedDevice {
    readonly kind: "device";
    readonly serial: string;
    readonly name: string;
}

/** The device chosen for a workspace: what the tool knows it by - a serial, or a virtual device's name - and its name. */
export type ChosenDevice = Omit<AttachedDevice, "kind">;

/** The devices and virtual devices as the tool lists them, or nothing, said, where it could not. */
export type AndroidLister = () => Promise<AndroidDevice[] | undefined>;

const deviceKey = "stateui.androidDevice";

/** A destination the tool listed, as an Android device stands in the editor. */
export function androidDeviceOf(destination: Destination): AndroidDevice {
    return destination.kind === "emulator" && !destination.booted
        ? { kind: "avd", name: destination.name }
        : { kind: "device", serial: destination.id, name: destination.name };
}

/** The device chosen for the workspace, where one is. */
export function chosenDevice(state: vscode.Memento): ChosenDevice | undefined {
    return state.get<ChosenDevice>(deviceKey);
}

/**
 * What the tool knows the device `chosen` by among `listed`: its serial while it runs - an emulator started since it
 * was chosen too, by its virtual device's name - else the virtual device's name, which the tool boots; nothing where
 * it is listed no more.
 */
export function deviceAmong(listed: AndroidDevice[], chosen: ChosenDevice | undefined): string | undefined {
    if (!chosen) {
        return undefined;
    }
    const running = listed.find((each): each is AttachedDevice =>
        each.kind === "device" && (each.serial === chosen.serial || each.name === chosen.name));
    return running?.serial ?? listed.find((each) => each.kind === "avd" && each.name === chosen.name)?.name;
}

/**
 * The device a launch or a suite runs on: the one chosen, while it is listed, else asked for - or nothing, where none
 * is picked.
 */
export async function deviceToRunOn(state: vscode.Memento, list: AndroidLister): Promise<string | undefined> {
    const listed = await list();
    const found = listed && deviceAmong(listed, chosenDevice(state));
    if (found) {
        return found;
    }
    return listed ? askForDevice(state, list, listed) : undefined;
}

/** Asks for a device among those the tool lists, remembers it, and answers what the tool knows it by. */
export async function askForDevice(state: vscode.Memento, list: AndroidLister, listed?: AndroidDevice[]): Promise<string | undefined> {
    listed ??= await list();
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            "StateUI: no Android device is attached and no emulator is set up - attach a device with USB debugging on, or make an emulator in Android Studio's Device Manager.");
        return undefined;
    }

    const current = chosenDevice(state)?.serial;
    const attached = listed.filter((each): each is AttachedDevice => each.kind === "device");
    const emulators = listed.filter((each) => each.kind === "avd");
    type Item = vscode.QuickPickItem & { device?: AndroidDevice };
    const items: Item[] = [
        ...attached.map((device): Item => ({
            label: `$(device-mobile) ${device.name}`, description: device.serial === current ? `${device.serial} · current` : device.serial, device,
        })),
        ...(emulators.length > 0 ? [{ label: "Emulators not running", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...emulators.map((device): Item => ({ label: `$(vm) ${device.name}`, description: "started when it runs", device })),
    ];

    const device = (await vscode.window.showQuickPick(items,
        { placeHolder: "Which Android device do StateUI: Debug, StateUI: Release and StateUI: Run Tests run on?", ignoreFocusOut: true }))?.device;
    if (!device) {
        return undefined;
    }
    const known = device.kind === "device" ? device.serial : device.name;
    await state.update(deviceKey, { serial: known, name: device.name } satisfies ChosenDevice);
    return known;
}

/** Chooses the device `wanted` names - its serial or its name - as the tool lists it; answers its name, or nothing. */
export async function chooseListedDevice(state: vscode.Memento, wanted: string, list: AndroidLister): Promise<string | undefined> {
    const found = (await list())?.find((each) => (each.kind === "device" && each.serial === wanted) || each.name === wanted);
    if (!found) {
        return undefined;
    }
    await state.update(deviceKey, { serial: found.kind === "device" ? found.serial : found.name, name: found.name } satisfies ChosenDevice);
    return found.name;
}
